// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Structured logging for ReScript applications.
 */

/** Log levels */
type level =
  | Debug
  | Info
  | Warn
  | Error

/** Convert level to string */
let levelToString = (level: level): string => {
  switch level {
  | Debug => "debug"
  | Info => "info"
  | Warn => "warn"
  | Error => "error"
  }
}

/** Convert level to numeric priority */
let levelToPriority = (level: level): int => {
  switch level {
  | Debug => 0
  | Info => 1
  | Warn => 2
  | Error => 3
  }
}

/** Logger configuration */
type config = {
  minLevel: level,
  json: bool,
  timestamps: bool,
  context: Dict.t<string>,
}

let defaultConfig: config = {
  minLevel: Info,
  json: true,
  timestamps: true,
  context: Dict.make(),
}

/** A logger instance */
type t = {
  config: config,
  log: (level, string, option<Dict.t<JSON.t>>) => unit,
}

/** Create a new logger */
let make = (~config: config=defaultConfig): t => {
  let log = (level: level, message: string, extra: option<Dict.t<JSON.t>>) => {
    if levelToPriority(level) >= levelToPriority(config.minLevel) {
      if config.json {
        let entry = Dict.make()
        entry->Dict.set("level", JSON.Encode.string(levelToString(level)))
        entry->Dict.set("message", JSON.Encode.string(message))

        if config.timestamps {
          entry->Dict.set("timestamp", JSON.Encode.string(Date.make()->Date.toISOString))
        }

        // Add context
        config.context->Dict.forEachWithKey((value, key) => {
          entry->Dict.set(key, JSON.Encode.string(value))
        })

        // Add extra fields
        switch extra {
        | Some(fields) =>
          fields->Dict.forEachWithKey((value, key) => {
            entry->Dict.set(key, value)
          })
        | None => ()
        }

        Console.log(JSON.stringify(JSON.Encode.object(entry)))
      } else {
        let timestamp = config.timestamps ? `[${Date.make()->Date.toISOString}] ` : ""
        let levelStr = `[${levelToString(level)->String.toUpperCase}]`
        Console.log(`${timestamp}${levelStr} ${message}`)

        switch extra {
        | Some(fields) if fields->Dict.keysToArray->Array.length > 0 =>
          Console.log(JSON.stringify(JSON.Encode.object(fields)))
        | _ => ()
        }
      }
    }
  }

  {config, log}
}

/** Log at debug level */
let debug = (logger: t, message: string, ~extra: Dict.t<JSON.t>=Dict.make()): unit => {
  logger.log(Debug, message, Some(extra))
}

/** Log at info level */
let info = (logger: t, message: string, ~extra: Dict.t<JSON.t>=Dict.make()): unit => {
  logger.log(Info, message, Some(extra))
}

/** Log at warn level */
let warn = (logger: t, message: string, ~extra: Dict.t<JSON.t>=Dict.make()): unit => {
  logger.log(Warn, message, Some(extra))
}

/** Log at error level */
let error = (logger: t, message: string, ~extra: Dict.t<JSON.t>=Dict.make()): unit => {
  logger.log(Error, message, Some(extra))
}

/** Create a child logger with additional context */
let child = (logger: t, context: Dict.t<string>): t => {
  let newContext = Dict.make()
  logger.config.context->Dict.forEachWithKey((v, k) => newContext->Dict.set(k, v))
  context->Dict.forEachWithKey((v, k) => newContext->Dict.set(k, v))

  make(~config={...logger.config, context: newContext})
}

/** Global default logger */
let defaultLogger = make()
