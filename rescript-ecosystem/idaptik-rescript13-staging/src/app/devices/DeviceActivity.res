// SPDX-License-Identifier: PMPL-1.0-or-later
// Device Activity Module
// Tracks last activity time for devices on routers

let getCurrentTime: unit => float = %raw(`function() { return Date.now(); }`)

let lastActivity: dict<float> = Dict.make()
let activityTimeoutMs = 30000.0 // 30 seconds

let recordActivity = (ip: string): unit => {
  Dict.set(lastActivity, ip, getCurrentTime())
}

let isActive = (ip: string): bool => {
  switch Dict.get(lastActivity, ip) {
  | Some(time) => getCurrentTime() -. time < activityTimeoutMs
  | None => false
  }
}
