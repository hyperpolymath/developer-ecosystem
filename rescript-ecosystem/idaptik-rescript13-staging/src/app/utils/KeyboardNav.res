// SPDX-License-Identifier: PMPL-1.0-or-later
// KeyboardNav — shared keyboard event handler utilities for IDApTIK screens.
// Eliminates duplicated %raw addEventListener/removeEventListener blocks.

/// Register a keydown handler on window. Returns an opaque handler token
/// that must be passed to removeKeydownHandler for cleanup.
let addKeydownHandler: (({..}) => unit) => {..} = %raw(`
  function(fn) {
    var h = function(e) { fn(e); };
    window.addEventListener('keydown', h);
    return h;
  }
`)

/// Remove a previously registered keydown handler (pass the token from addKeydownHandler).
let removeKeydownHandler: ({..}) => unit = %raw(`
  function(handler) {
    window.removeEventListener('keydown', handler);
  }
`)

/// Extract the key name from a keyboard event object.
let eventKey: ({..}) => string = %raw(`function(e) { return e.key; }`)

/// Call preventDefault() on a keyboard event object.
let preventDefault: ({..}) => unit = %raw(`function(e) { e.preventDefault(); }`)
