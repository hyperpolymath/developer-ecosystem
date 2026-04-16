// SPDX-License-Identifier: PMPL-1.0-or-later
// System Logs Module
// Tracks log entries for server devices

let getCurrentTime: unit => float = %raw(`function() { return Date.now(); }`)

type logLevel = [#Info | #Warning | #Error]
type logEntry = {
  timestamp: string,
  message: string,
  level: logLevel,
}

let logs: dict<array<logEntry>> = Dict.make()
let maxLogs = 50

let formatTime = (): string => {
  let _date = %raw(`new Date()`)
  let hours = %raw(`_date.getHours().toString().padStart(2, '0')`)
  let minutes = %raw(`_date.getMinutes().toString().padStart(2, '0')`)
  `${hours}:${minutes}`
}

let addLog = (ip: string, message: string, level: logLevel): unit => {
  let entry = {
    timestamp: formatTime(),
    message,
    level,
  }

  let currentLogs = switch Dict.get(logs, ip) {
  | Some(l) => l
  | None => []
  }

  let newLogs = Array.concat(currentLogs, [entry])
  // Keep only last 50 entries
  let trimmedLogs = if Array.length(newLogs) > maxLogs {
    Array.slice(newLogs, ~start=Array.length(newLogs) - maxLogs, ~end=Array.length(newLogs))
  } else {
    newLogs
  }

  Dict.set(logs, ip, trimmedLogs)
}

let getLogs = (ip: string, limit: int): array<logEntry> => {
  switch Dict.get(logs, ip) {
  | Some(l) =>
    let len = Array.length(l)
    if len <= limit {
      l
    } else {
      Array.slice(l, ~start=len - limit, ~end=len)
    }
  | None => []
  }
}

// Initialize with some default logs
let initializeLogs = (ip: string): unit => {
  addLog(ip, "System initialized", #Info)
  addLog(ip, "Network services started", #Info)
  addLog(ip, "Security monitor active", #Info)
}
