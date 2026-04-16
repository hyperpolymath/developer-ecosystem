// SPDX-License-Identifier: PMPL-1.0-or-later
// ProvenError - Error types for proven-safe modules

type provenError = {
  operation: string,
  message: string,
  errorType: string,
}

let notANumber = (~operation: string, ~message: string): provenError => {
  {operation, message, errorType: "NaN"}
}

let infinity = (~operation: string, ~message: string): provenError => {
  {operation, message, errorType: "Infinity"}
}

let parseFailure = (~operation: string, ~message: string): provenError => {
  {operation, message, errorType: "ParseFailure"}
}

let divisionByZero = (~operation: string, ~message: string): provenError => {
  {operation, message, errorType: "DivisionByZero"}
}

let invalidArgument = (~operation: string, ~message: string): provenError => {
  {operation, message, errorType: "InvalidArgument"}
}

let toString = (err: provenError): string => {
  `[${err.errorType}] ${err.operation}: ${err.message}`
}
