// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// SafeDOMCore.res — High-assurance core for the rescript-dom-mounter package.
//
// This module implements formally-inspired DOM mounting with compile-time and
// runtime safety guarantees. It provides:
//
//   - MountTracer: An append-only audit log that records every validation,
//     mount attempt, success, and failure with timestamps. Useful for
//     debugging, Hypatia/PanLL dashboards, and Rokur audit trails.
//
//   - ProvenSelector: CSS selector validation that rejects empty, oversized,
//     and character-invalid selectors before any DOM query is attempted.
//
//   - ProvenHTML: HTML content validation that checks tag balance and enforces
//     a 1MB size limit. Includes XSS sanitisation (script removal, event
//     handler stripping, javascript: URL blocking, iframe removal).
//
//   - Mounting functions: mount, mountString, mountSafe, mountBatch for
//     various levels of pre-validation control.
//
//   - Lifecycle: unmount (clear element), remount (atomic swap with
//     validation-before-unmount), onDOMReady, mountWhenReady.
//
//   - CSP integration: mountWithNonce for Content-Security-Policy compliance.
//
// The Idris2 ABI layer (src/ABI/) provides dependent-type proofs that mirror
// these runtime checks at compile time. See SafeDOM.idr for the formal theorems.

// ------------------------------------------------------------------
// Public types
// ------------------------------------------------------------------

type validSelector =
  | ValidSelector(string)

type validHtml =
  | ValidHTML(string)

type mountResult =
  | Mounted(Dom.element)
  | MountPointNotFound(string)
  | InvalidSelector(string)
  | InvalidHTML(string)

type mountSpec = {
  selector: string,
  html: string,
}

// ------------------------------------------------------------------
// Runtime trace instrumentation
// ------------------------------------------------------------------

module MountTracer = {
  type entry = {
    event: string,
    detail: string,
    timestampMs: float,
  }

  let logRef: ref<array<entry>> = ref([])

  let nowMs = () => Js.Date.now()

  let appendEntry = entry => {
    logRef := Belt.Array.concat(logRef.contents, [entry])
    ()
  }

  let record = (event: string, detail: string) =>
    appendEntry({event, detail, timestampMs: nowMs()})

  let entries = () => logRef.contents

  let latest = () => {
    let current = logRef.contents
    if Belt.Array.length(current) === 0 {
      None
    } else {
      Some(Belt.Array.getUnsafe(current, Belt.Array.length(current) - 1))
    }
  }

  let clear = () => logRef := []

  let snapshot = () => logRef.contents
}

module SafeString = {
  let trim = s => %raw(`String.prototype.trim.call(s)`)
  let length = s => Js.String.length(s)
}

// ------------------------------------------------------------------
// Proven selector validation
// ------------------------------------------------------------------

module ProvenSelector = {
  type validated = validSelector

  let invalidSelectorRegex = Js.Re.fromStringWithFlags("[^\\w\\-#\\.\\[\\]():>~+= ]", ~flags="g")

  let recordOutcome = (selector: string, outcome: result<validated, string>) => {
    let detail =
      switch outcome {
      | Ok(_) => "selector valid"
      | Error(err) => err
      }
    MountTracer.record("selector-validation", selector ++ ";" ++ detail)
  }

  let validate = (selector: string): result<validated, string> => {
    let trimmed = SafeString.trim(selector)
    let len = SafeString.length(trimmed)
    let outcome =
      if len === 0 {
        Error("Selector cannot be empty")
      } else if len > 255 {
        Error("Selector exceeds maximum length (255 characters)")
      } else if Js.Re.test_(invalidSelectorRegex, trimmed) {
        Error("Selector contains invalid CSS characters")
      } else {
        Ok(ValidSelector(trimmed))
      }
    recordOutcome(trimmed, outcome)
    outcome
  }

  let toString = (ValidSelector(value)) => value
}

// ------------------------------------------------------------------
// Proven HTML validation
// ------------------------------------------------------------------

module ProvenHTML = {
  type validHtml = ValidHTML(string)
  type validated = validHtml

  let maxSize = 1_048_576

  let createRegex = pattern => Js.Re.fromStringWithFlags(pattern, ~flags="g")

  let rec countMatches = (re: Js.Re.t, text: string, acc: int): int =>
    switch Js.Re.exec_(re, text) {
    | None => acc
    | Some(_) => countMatches(re, text, acc + 1)
    }

  let recordOutcome = (html: string, outcome: result<validated, string>) => {
    let detail =
      switch outcome {
      | Ok(_) => "html valid"
      | Error(err) => err
      }
    let summary = "size=" ++ Belt.Int.toString(SafeString.length(html))
    MountTracer.record("html-validation", summary ++ ";" ++ detail)
  }

  // Sanitise HTML content to prevent XSS attacks.
  // Removes dangerous patterns that could execute arbitrary JavaScript:
  //   - <script> tags and their content (inline JS execution)
  //   - Event handler attributes (onerror, onload, onclick, etc.)
  //   - javascript: URLs (JS execution via href/src)
  //   - data: URLs in src/href (can execute JS via data:text/html)
  //   - <iframe> tags (clickjacking and cross-origin attack vector)
  //
  // This complements tag balance validation — balance proves structure,
  // sanitise proves safety. Both are needed for high-assurance mounting.
  //
  // NOTE: This is a defence-in-depth measure. Applications should also
  // sanitise user input at the point of entry, not just at mount time.
  let sanitise = (html: string): string => {
    html
    // Remove <script> tags and their content entirely — the primary
    // XSS vector. Uses [\s\S]*? for non-greedy cross-line matching.
    ->Js.String2.replaceByRe(%re("/<script[^>]*>[\s\S]*?<\/script>/gi"), "")
    // Remove event handler attributes (on*) with quoted values.
    // Matches onerror="...", onclick='...', onload="..." etc.
    ->Js.String2.replaceByRe(%re("/\s+on\w+\s*=\s*[\"'][^\"']*[\"']/gi"), "")
    // Remove event handler attributes with unquoted values.
    // Matches onerror=alert(1), onclick=doEvil() etc.
    ->Js.String2.replaceByRe(%re("/\s+on\w+\s*=\s*\S+/gi"), "")
    // Replace javascript: URLs with blocked: to neutralise href/src
    // payloads like <a href="javascript:alert(1)">.
    ->Js.String2.replaceByRe(%re("/javascript\s*:/gi"), "blocked:")
    // Remove data: URLs in src/href attributes. data:text/html can
    // execute JS in some browsers via <a href="data:text/html,<script>...">.
    ->Js.String2.replaceByRe(%re("/\s+(src|href)\s*=\s*[\"']data:[^\"']*[\"']/gi"), "")
    // Remove <iframe> tags with content (clickjacking vector).
    ->Js.String2.replaceByRe(%re("/<iframe[^>]*>[\s\S]*?<\/iframe>/gi"), "")
    // Remove self-closing <iframe> tags.
    ->Js.String2.replaceByRe(%re("/<iframe[^>]*\/>/gi"), "")
  }

  // Validate HTML content for well-formedness and safety.
  //
  // The validation pipeline is:
  //   1. Sanitise: strip dangerous XSS patterns (scripts, event handlers, etc.)
  //   2. Size check: reject content exceeding 1MB (DoS prevention)
  //   3. Tag balance: verify open tags match close tags (structural integrity)
  //
  // Returns Ok(ValidHTML(sanitised_content)) on success, or Error(reason) on
  // failure. The validated content has been sanitised, so downstream code
  // receives clean HTML even if the input contained XSS payloads.
  let validate = (html: string): result<validated, string> => {
    let sanitised = sanitise(html)
    let len = SafeString.length(sanitised)
    let outcome =
      if len > maxSize {
        Error("HTML content exceeds maximum size (1MB)")
      } else {
        let openTags = countMatches(createRegex("<[^\\/][^>]*>"), sanitised, 0)
        let closeTags = countMatches(createRegex("<\\/[^>]+>"), sanitised, 0)
        let selfClosing = countMatches(createRegex("<[^>]+\\/>"), sanitised, 0)
        if openTags - selfClosing !== closeTags {
          Error(
            "Unbalanced HTML tags: "
            ++ Belt.Int.toString(openTags - selfClosing)
            ++ " open, "
            ++ Belt.Int.toString(closeTags)
            ++ " close",
          )
        } else {
          Ok(ValidHTML(sanitised))
        }
      }
    recordOutcome(sanitised, outcome)
    outcome
  }

  let toString = (ValidHTML(value)) => value
}

// ------------------------------------------------------------------
// DOM mounting helpers
// ------------------------------------------------------------------

let findMountPoint = (selector: ProvenSelector.validated): option<Dom.element> => {
  let selectorStr = ProvenSelector.toString(selector)
  let element: Js.Nullable.t<Dom.element> = %raw(`document.querySelector(selectorStr)`)
  element->Js.Nullable.toOption
}

let mount = (
  selector: ProvenSelector.validated,
  html: ProvenHTML.validated,
): mountResult => {
  let selectorStr = ProvenSelector.toString(selector)
  let htmlStr = ProvenHTML.toString(html)
  MountTracer.record("mount-attempt", "selector=" ++ selectorStr)
  switch findMountPoint(selector) {
  | None =>
      MountTracer.record("mount-failure", "selector=" ++ selectorStr ++ ";reason=mount-point-missing")
      MountPointNotFound(selectorStr)
  | Some(element) => {
      %raw(`element.innerHTML = htmlStr`);
      let identity = switch %raw(`element.id`) {
        | "" => "anonymous"
        | id => id
        };
      MountTracer.record(
        "mount-success",
        "selector=" ++ selectorStr ++ ";element=" ++ identity,
      );
      Mounted(element)
    }
  }
}

let mountString = (selector: string, html: string): mountResult => {
  switch ProvenSelector.validate(selector) {
  | Error(e) => InvalidSelector(e)
  | Ok(validSelector) =>
      switch ProvenHTML.validate(html) {
      | Error(e) => InvalidHTML(e)
      | Ok(validHtml) => mount(validSelector, validHtml)
      }
  }
}

let mountSafe = (
  selector: string,
  html: string,
  ~onSuccess: Dom.element => unit,
  ~onError: string => unit,
): unit =>
  switch mountString(selector, html) {
  | Mounted(el) => onSuccess(el)
  | MountPointNotFound(s) => onError(`Mount point not found: ${s}`)
  | InvalidSelector(e) => onError(`Invalid selector: ${e}`)
  | InvalidHTML(e) => onError(`Invalid HTML: ${e}`)
  }

let mountBatch = (specs: array<mountSpec>): result<array<Dom.element>, string> => {
  let validatedSpecs = specs->Belt.Array.map(spec =>
    switch ProvenSelector.validate(spec.selector) {
    | Error(e) => Error(`Selector validation failed for "${spec.selector}": ${e}`)
    | Ok(validSelector) =>
        switch ProvenHTML.validate(spec.html) {
        | Error(e) => Error(`HTML validation failed for "${spec.selector}": ${e}`)
        | Ok(validHtml) => Ok((validSelector, validHtml))
        }
    }
  )

  let rec checkValidations = (arr, idx) =>
    if idx >= Belt.Array.length(arr) {
      Ok()
    } else {
      switch Belt.Array.getUnsafe(arr, idx) {
      | Error(err) => Error(err)
      | Ok(_) => checkValidations(arr, idx + 1)
      }
    }

  switch checkValidations(validatedSpecs, 0) {
  | Error(err) =>
      MountTracer.record("batch-mount-validation-failure", err)
      Error(err)
  | Ok() => {
      let rec mountAll = (idx: int, acc: array<Dom.element>): result<array<Dom.element>, string> => {
        if idx >= Belt.Array.length(validatedSpecs) {
          Ok(acc)
        } else {
          switch Belt.Array.getUnsafe(validatedSpecs, idx) {
          | Error(err) => Error(err)
          | Ok((validSelector, validHtml)) =>
              switch mount(validSelector, validHtml) {
              | Mounted(el) => {
                  let nextAcc = Belt.Array.concat(acc, [el])
                  mountAll(idx + 1, nextAcc)
                }
              | MountPointNotFound(reason) => {
                  let msg = `Batch mount failed: ${reason}`
                  MountTracer.record("batch-mount-failure", msg)
                  Error(msg)
                }
              | InvalidSelector(err) => {
                  let msg = `Batch mount invalid selector: ${err}`
                  MountTracer.record("batch-mount-failure", msg)
                  Error(msg)
                }
              | InvalidHTML(err) => {
                  let msg = `Batch mount invalid HTML: ${err}`
                  MountTracer.record("batch-mount-failure", msg)
                  Error(msg)
                }
              }
          }
        }
      }

      switch mountAll(0, []) {
      | Ok(elements) => {
          MountTracer.record("batch-mount-success", "count=" ++ Belt.Int.toString(Belt.Array.length(elements)))
          Ok(elements)
        }
      | Error(err) => {
          MountTracer.record("batch-mount-failure", err)
          Error(err)
        }
      }
    }
  }
}

let onDOMReady = (callback: unit => unit): unit => {
  MountTracer.record("dom-ready-check", "scheduling")
  let readyState: string = %raw(`document.readyState`)
  if readyState === "complete" || readyState === "interactive" {
    callback()
  } else {
    %raw(`document.addEventListener('DOMContentLoaded', callback)`)
    MountTracer.record("dom-ready-listen", "waiting for DOMContentLoaded")
  }
}

let mountWhenReady = (
  ~selector: string,
  ~html: string,
  ~onSuccess: Dom.element => unit,
  ~onError: string => unit,
): unit =>
  onDOMReady(() => mountSafe(selector, html, ~onSuccess, ~onError))

// ------------------------------------------------------------------
// Lifecycle: unmount and remount
// ------------------------------------------------------------------

// Unmount content from a DOM element, replacing it with empty content.
// Records the unmount event to MountTracer for audit completeness.
//
// This pairs with mount() to provide full lifecycle tracking.
// Without explicit unmounting, elements remain in the DOM after
// the application has finished with them, potentially leaking
// event listeners and memory.
//
// @param selector  A pre-validated CSS selector for the mount point
// @returns mountResult indicating success (Mounted) or failure (MountPointNotFound)
let unmount = (selector: ProvenSelector.validated): mountResult => {
  let selectorStr = switch selector {
  | ValidSelector(s) => s
  }
  MountTracer.record("unmount_attempt", selectorStr)
  let el = findMountPoint(selector)
  switch el {
  | None =>
    MountTracer.record("unmount_not_found", selectorStr)
    MountPointNotFound(selectorStr)
  | Some(element) =>
    %raw(`element.innerHTML = ""`)
    MountTracer.record("unmount_success", selectorStr)
    Mounted(element)
  }
}

// Remount: unmount then mount with new content in a single operation.
// Validates the new content before unmounting the old, so if validation
// fails, the existing content is preserved (atomic swap semantics).
//
// This is the recommended way to update mounted content because it
// guarantees that the user never sees a blank element due to a
// validation failure — the old content stays until the new content
// is proven safe.
//
// @param selector  CSS selector string (will be validated)
// @param html      New HTML content (will be sanitised and validated)
// @returns mountResult — Mounted on success, or the specific failure reason
let remount = (selector: string, html: string): mountResult => {
  switch ProvenSelector.validate(selector) {
  | Error(e) => InvalidSelector(e)
  | Ok(validSelector) =>
    switch ProvenHTML.validate(html) {
    | Error(e) => InvalidHTML(e)
    | Ok(validHtml) =>
      // Validation passed — safe to unmount old content
      let _ = unmount(validSelector)
      mount(validSelector, validHtml)
    }
  }
}

// ------------------------------------------------------------------
// CSP nonce support
// ------------------------------------------------------------------

// Mount with CSP nonce applied to any inline script/style tags.
// Content-Security-Policy requires a nonce attribute on inline scripts
// and styles to prevent injection attacks. This function adds the nonce
// to all <script> and <style> tags in the validated HTML before mounting.
//
// The nonce is injected before sanitisation and validation, so any
// script tags that survive sanitisation (none should, but defence-in-depth)
// will at least carry the correct nonce for CSP compliance.
//
// @param selector  CSS selector string for the mount point
// @param html      HTML content to mount
// @param ~nonce    CSP nonce value from the server's Content-Security-Policy header
// @returns mountResult — Mounted on success, or the specific failure reason
let mountWithNonce = (selector: string, html: string, ~nonce: string): mountResult => {
  switch ProvenSelector.validate(selector) {
  | Error(e) => InvalidSelector(e)
  | Ok(validSelector) =>
    // Inject nonce into script and style tags before validation.
    // This ensures that any inline scripts/styles that pass sanitisation
    // carry the server-issued nonce for CSP whitelisting.
    let noncedHtml = html
      ->Js.String2.replaceByRe(%re("/<script/gi"), `<script nonce="${nonce}"`)
      ->Js.String2.replaceByRe(%re("/<style/gi"), `<style nonce="${nonce}"`)
    switch ProvenHTML.validate(noncedHtml) {
    | Error(e) => InvalidHTML(e)
    | Ok(validHtml) =>
      MountTracer.record("mount_with_nonce", nonce)
      mount(validSelector, validHtml)
    }
  }
}
