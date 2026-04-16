// SPDX-License-Identifier: PMPL-1.0-or-later
// Screen Reader Announcer
//
// Dispatches messages to ARIA live regions. All functions are no-ops
// when screen reader support is disabled in AccessibilitySettings.
// Three channels with different politeness levels:
//   status()          polite (zone changes, objectives, inventory)
//   alert()           assertive (alert level changes, pause)
//   terminalOutput()  polite log (terminal command output)

// Announce via the polite "status" region
let status = (message: string): unit => {
  if AccessibilitySettings.isScreenReaderEnabled() {
    DomA11y.announce("a11y-status", message)
  }
}

// Announce via the assertive "alert" region
let alert = (message: string): unit => {
  if AccessibilitySettings.isScreenReaderEnabled() {
    DomA11y.announce("a11y-alert", message)
  }
}

// Announce terminal output via the log region
let terminalOutput = (text: string): unit => {
  if AccessibilitySettings.isScreenReaderEnabled() {
    DomA11y.announce("a11y-terminal", text)
  }
}
