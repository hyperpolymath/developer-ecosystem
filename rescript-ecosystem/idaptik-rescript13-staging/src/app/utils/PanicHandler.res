// SPDX-License-Identifier: PMPL-1.0-or-later
// PanicHandler.res - Exception handling utilities
//
// Global exception handler for unrecoverable errors

let handleException = (exn: exn): promise<unit> => {
  Console.error("Unhandled exception:")
  Console.error(exn)
  Promise.resolve()
}

let handleError = (message: string): unit => {
  Console.error(`[ERROR] ${message}`)
}

let reportProvenError = (err: ProvenError.provenError, ~severity: option<string>=?): unit => {
  let _ = severity
  Console.error(ProvenError.toString(err))
}
