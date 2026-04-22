@@ocaml.doc("
Type-safe JSON decoding inspired by Elm's Json.Decode.
Decoders are composable and provide helpful error messages with path information.
")

// ============================================================================
// Error types
// ============================================================================

type rec decodeError =
  | Field(string, decodeError)
  | Index(int, decodeError)
  | OneOf(array<decodeError>)
  | Failure(string, Js.Json.t)

let rec errorToString = (error: decodeError): string => {
  errorToStringHelper(error, [])
}

and errorToStringHelper = (error: decodeError, path: array<string>): string => {
  switch error {
  | Field(name, inner) =>
    errorToStringHelper(inner, Belt.Array.concat(path, [`."${name}"`]))
  | Index(idx, inner) =>
    errorToStringHelper(inner, Belt.Array.concat(path, [`[${Belt.Int.toString(idx)}]`]))
  | OneOf(errors) =>
    let prefix = Belt.Array.length(path) > 0 ? `at ${Js.Array2.joinWith(path, "")}: ` : ""
    let errorStrs = Belt.Array.map(errors, e => errorToStringHelper(e, []))
    `${prefix}none of the following decoders succeeded:\n${Js.Array2.joinWith(errorStrs, "\n")}`
  | Failure(message, _value) =>
    let prefix = Belt.Array.length(path) > 0 ? `at ${Js.Array2.joinWith(path, "")}: ` : ""
    `${prefix}${message}`
  }
}

// ============================================================================
// Decoder type
// ============================================================================

type decoder<'a> = Js.Json.t => result<'a, decodeError>

// ============================================================================
// Primitives
// ============================================================================

let string: decoder<string> = json => {
  switch Js.Json.classify(json) {
  | Js.Json.JSONString(s) => Ok(s)
  | _ => Error(Failure("expected a string", json))
  }
}

let int: decoder<int> = json => {
  switch Js.Json.classify(json) {
  | Js.Json.JSONNumber(n) if Js.Math.floor_float(n) == n => Ok(Belt.Float.toInt(n))
  | _ => Error(Failure("expected an integer", json))
  }
}

let float: decoder<float> = json => {
  switch Js.Json.classify(json) {
  | Js.Json.JSONNumber(n) => Ok(n)
  | _ => Error(Failure("expected a number", json))
  }
}

let bool: decoder<bool> = json => {
  switch Js.Json.classify(json) {
  | Js.Json.JSONTrue => Ok(true)
  | Js.Json.JSONFalse => Ok(false)
  | _ => Error(Failure("expected a boolean", json))
  }
}

let null = (value: 'a): decoder<'a> => {
  json => {
    switch Js.Json.classify(json) {
    | Js.Json.JSONNull => Ok(value)
    | _ => Error(Failure("expected null", json))
    }
  }
}

// ============================================================================
// Objects
// ============================================================================

let field = (name: string, decoder: decoder<'a>): decoder<'a> => {
  json => {
    switch Js.Json.classify(json) {
    | Js.Json.JSONObject(dict) =>
      switch Js.Dict.get(dict, name) {
      | Some(value) =>
        switch decoder(value) {
        | Ok(v) => Ok(v)
        | Error(e) => Error(Field(name, e))
        }
      | None => Error(Field(name, Failure(`missing field "${name}"`, json)))
      }
    | _ => Error(Failure("expected an object", json))
    }
  }
}

let optionalField = (name: string, decoder: decoder<'a>): decoder<option<'a>> => {
  json => {
    switch Js.Json.classify(json) {
    | Js.Json.JSONObject(dict) =>
      switch Js.Dict.get(dict, name) {
      | Some(value) =>
        switch Js.Json.classify(value) {
        | Js.Json.JSONNull => Ok(None)
        | _ =>
          switch decoder(value) {
          | Ok(v) => Ok(Some(v))
          | Error(e) => Error(Field(name, e))
          }
        }
      | None => Ok(None)
      }
    | _ => Error(Failure("expected an object", json))
    }
  }
}

let at = (path: array<string>, decoder: decoder<'a>): decoder<'a> => {
  Belt.Array.reduceReverse(path, decoder, (acc, name) => field(name, acc))
}

// ============================================================================
// Arrays
// ============================================================================

let array = (decoder: decoder<'a>): decoder<array<'a>> => {
  json => {
    switch Js.Json.classify(json) {
    | Js.Json.JSONArray(arr) =>
      let rec loop = (idx: int, results: array<'a>): result<array<'a>, decodeError> => {
        if idx >= Belt.Array.length(arr) {
          Ok(results)
        } else {
          switch decoder(Belt.Array.getExn(arr, idx)) {
          | Ok(v) => loop(idx + 1, Belt.Array.concat(results, [v]))
          | Error(e) => Error(Index(idx, e))
          }
        }
      }
      loop(0, [])
    | _ => Error(Failure("expected an array", json))
    }
  }
}

let index = (idx: int, decoder: decoder<'a>): decoder<'a> => {
  json => {
    switch Js.Json.classify(json) {
    | Js.Json.JSONArray(arr) =>
      switch Belt.Array.get(arr, idx) {
      | Some(value) =>
        switch decoder(value) {
        | Ok(v) => Ok(v)
        | Error(e) => Error(Index(idx, e))
        }
      | None => Error(Index(idx, Failure(`index ${Belt.Int.toString(idx)} out of bounds`, json)))
      }
    | _ => Error(Failure("expected an array", json))
    }
  }
}

// ============================================================================
// Combinators
// ============================================================================

let map = (f: 'a => 'b, decoder: decoder<'a>): decoder<'b> => {
  json => {
    switch decoder(json) {
    | Ok(a) => Ok(f(a))
    | Error(e) => Error(e)
    }
  }
}

let map2 = (
  f: ('a, 'b) => 'c,
  decoderA: decoder<'a>,
  decoderB: decoder<'b>,
): decoder<'c> => {
  json => {
    switch (decoderA(json), decoderB(json)) {
    | (Ok(a), Ok(b)) => Ok(f(a, b))
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  }
}

let map3 = (
  f: ('a, 'b, 'c) => 'd,
  decoderA: decoder<'a>,
  decoderB: decoder<'b>,
  decoderC: decoder<'c>,
): decoder<'d> => {
  json => {
    switch (decoderA(json), decoderB(json), decoderC(json)) {
    | (Ok(a), Ok(b), Ok(c)) => Ok(f(a, b, c))
    | (Error(e), _, _) => Error(e)
    | (_, Error(e), _) => Error(e)
    | (_, _, Error(e)) => Error(e)
    }
  }
}

let map4 = (
  f: ('a, 'b, 'c, 'd) => 'e,
  decoderA: decoder<'a>,
  decoderB: decoder<'b>,
  decoderC: decoder<'c>,
  decoderD: decoder<'d>,
): decoder<'e> => {
  json => {
    switch (decoderA(json), decoderB(json), decoderC(json), decoderD(json)) {
    | (Ok(a), Ok(b), Ok(c), Ok(d)) => Ok(f(a, b, c, d))
    | (Error(e), _, _, _) => Error(e)
    | (_, Error(e), _, _) => Error(e)
    | (_, _, Error(e), _) => Error(e)
    | (_, _, _, Error(e)) => Error(e)
    }
  }
}

let map5 = (
  f: ('a, 'b, 'c, 'd, 'e) => 'f,
  decoderA: decoder<'a>,
  decoderB: decoder<'b>,
  decoderC: decoder<'c>,
  decoderD: decoder<'d>,
  decoderE: decoder<'e>,
): decoder<'f> => {
  json => {
    switch (
      decoderA(json),
      decoderB(json),
      decoderC(json),
      decoderD(json),
      decoderE(json),
    ) {
    | (Ok(a), Ok(b), Ok(c), Ok(d), Ok(e)) => Ok(f(a, b, c, d, e))
    | (Error(e), _, _, _, _) => Error(e)
    | (_, Error(e), _, _, _) => Error(e)
    | (_, _, Error(e), _, _) => Error(e)
    | (_, _, _, Error(e), _) => Error(e)
    | (_, _, _, _, Error(e)) => Error(e)
    }
  }
}

let map6 = (
  f: ('a, 'b, 'c, 'd, 'e, 'f) => 'g,
  decoderA: decoder<'a>,
  decoderB: decoder<'b>,
  decoderC: decoder<'c>,
  decoderD: decoder<'d>,
  decoderE: decoder<'e>,
  decoderF: decoder<'f>,
): decoder<'g> => {
  json => {
    switch (
      decoderA(json),
      decoderB(json),
      decoderC(json),
      decoderD(json),
      decoderE(json),
      decoderF(json),
    ) {
    | (Ok(a), Ok(b), Ok(c), Ok(d), Ok(e), Ok(f_)) => Ok(f(a, b, c, d, e, f_))
    | (Error(e), _, _, _, _, _) => Error(e)
    | (_, Error(e), _, _, _, _) => Error(e)
    | (_, _, Error(e), _, _, _) => Error(e)
    | (_, _, _, Error(e), _, _) => Error(e)
    | (_, _, _, _, Error(e), _) => Error(e)
    | (_, _, _, _, _, Error(e)) => Error(e)
    }
  }
}

let andThen = (f: 'a => decoder<'b>, decoder: decoder<'a>): decoder<'b> => {
  json => {
    switch decoder(json) {
    | Ok(a) => f(a)(json)
    | Error(e) => Error(e)
    }
  }
}

// ============================================================================
// Alternatives
// ============================================================================

let oneOf = (decoders: array<decoder<'a>>): decoder<'a> => {
  json => {
    let rec loop = (idx: int, errors: array<decodeError>): result<'a, decodeError> => {
      if idx >= Belt.Array.length(decoders) {
        Error(OneOf(errors))
      } else {
        switch (Belt.Array.getExn(decoders, idx))(json) {
        | Ok(v) => Ok(v)
        | Error(e) => loop(idx + 1, Belt.Array.concat(errors, [e]))
        }
      }
    }
    loop(0, [])
  }
}

let optional = (decoder: decoder<'a>): decoder<option<'a>> => {
  json => {
    switch Js.Json.classify(json) {
    | Js.Json.JSONNull => Ok(None)
    | _ =>
      switch decoder(json) {
      | Ok(v) => Ok(Some(v))
      | Error(e) => Error(e)
      }
    }
  }
}

let nullable = (decoder: decoder<'a>): decoder<option<'a>> => {
  oneOf([null(None), map(v => Some(v), decoder)])
}

// ============================================================================
// Special decoders
// ============================================================================

let succeed = (value: 'a): decoder<'a> => {
  _json => Ok(value)
}

let fail = (message: string): decoder<'a> => {
  json => Error(Failure(message, json))
}

let value: decoder<Js.Json.t> = json => Ok(json)

// ============================================================================
// Running decoders
// ============================================================================

let decodeValue = (decoder: decoder<'a>, json: Js.Json.t): result<'a, decodeError> => {
  decoder(json)
}

let decodeString = (decoder: decoder<'a>, str: string): result<'a, decodeError> => {
  try {
    let json = Js.Json.parseExn(str)
    decoder(json)
  } catch {
  | _ => Error(Failure("invalid JSON", Js.Json.null))
  }
}
