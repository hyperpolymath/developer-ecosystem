// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// BEAM connection management

open Types

type connectionOptions = {
  node: string,
  cookie: string,
  mode?: string, // "port" or "distribution"
  portProgram?: string,
}

type connectionState =
  | Disconnected
  | Connecting
  | Connected
  | Draining

type t = {
  mutable state: connectionState,
  options: connectionOptions,
  mutable process: option<'process>,
  mutable callId: int,
  pendingCalls: Dict.t<{resolve: erlangTerm => unit, reject: string => unit}>,
}

let make = (options: connectionOptions): t => {
  {
    state: Disconnected,
    options: options,
    process: None,
    callId: 0,
    pendingCalls: Dict.make(),
  }
}

let connect = async (options: connectionOptions): t => {
  let conn = make(options)
  conn.state = Connecting

  let mode = Option.getOr(options.mode, "port")

  if mode == "distribution" {
    Exn.raiseError("Distribution protocol not yet implemented")
  }

  // Port mode implementation
  let portProgram = Option.getOr(options.portProgram, "erl")
  let erlCode = `
    {ok, _} = net_kernel:connect_node('${options.node}'),
    Port = open_port({fd, 0, 1}, [binary, {packet, 4}]),
    loop(Port).
    loop(Port) ->
      receive
        {Port, {data, Data}} ->
          Term = binary_to_term(Data),
          handle_call(Port, Term),
          loop(Port);
        stop -> ok
      end.
    handle_call(Port, {call, Id, M, F, A}) ->
      Result = try apply(M, F, A) catch _:E -> {error, E} end,
      Port ! {self(), {command, term_to_binary({reply, Id, Result})}};
    handle_call(Port, {cast, M, F, A}) ->
      spawn(fun() -> apply(M, F, A) end).
  `

  conn.process = Some(
    %raw(`
      const command = new Deno.Command(portProgram, {
        args: ["-noshell", "-sname", "deno_client", "-setcookie", options.cookie, "-eval", erlCode],
        stdin: "piped",
        stdout: "piped",
        stderr: "inherit",
      });
      command.spawn()
    `),
  )

  conn.state = Connected
  conn
}

let call = async (conn: t, module: string, func: string, args: array<erlangTerm>): erlangTerm => {
  if conn.state != Connected {
    Exn.raiseError("Not connected")
  }

  let id = conn.callId
  conn.callId = conn.callId + 1

  let term = Tuple([Atom("call"), Integer(id), Atom(module), Atom(func), List(args)])
  let encoded = Etf.encode(term)

  await %raw(`
    new Promise((resolve, reject) => {
      conn.pendingCalls[id] = { resolve, reject };

      const packet = new Uint8Array(4 + encoded.length);
      new DataView(packet.buffer).setUint32(0, encoded.length, false);
      packet.set(encoded, 4);

      conn.process.stdin.getWriter().write(packet).catch(reject);
    })
  `)
}

let cast = async (conn: t, module: string, func: string, args: array<erlangTerm>): unit => {
  if conn.state != Connected {
    Exn.raiseError("Not connected")
  }

  let term = Tuple([Atom("cast"), Atom(module), Atom(func), List(args)])
  let encoded = Etf.encode(term)

  await %raw(`
    const packet = new Uint8Array(4 + encoded.length);
    new DataView(packet.buffer).setUint32(0, encoded.length, false);
    packet.set(encoded, 4);
    conn.process.stdin.getWriter().write(packet)
  `)
}

let close = async (conn: t): unit => {
  conn.state = Draining

  switch conn.process {
  | Some(proc) => %raw(`proc.kill("SIGTERM")`)
  | None => ()
  }

  conn.process = None
  conn.state = Disconnected

  // Reject all pending calls
  Dict.forEachWithKey(conn.pendingCalls, (_, pending) => {
    pending.reject("Connection closed")
  })
}

let isConnected = (conn: t): bool => conn.state == Connected
