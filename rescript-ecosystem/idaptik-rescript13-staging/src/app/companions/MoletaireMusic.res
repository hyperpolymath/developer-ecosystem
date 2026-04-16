// SPDX-License-Identifier: PMPL-1.0-or-later
// MoletaireMusic  Synthesised chiptune loop for Moletaire training ground
//
// Web Audio API procedural music. Short 8-bar loop with square + triangle
// waves in a bouncy 4/4 feel (~114 BPM). Plays only during underground
// movement in the Moletaire training ground.
//
// Inspired by classic game chiptune aesthetics  short bouncy melody
// with a simple bass line. All original composition (no copyrighted samples).
//
// Uses raw Web Audio API bindings via %raw blocks since PixiJS Sound
// is designed for sample playback, not synthesis.

//  Web Audio FFI 

// Opaque type for AudioContext (avoids value restriction on open-object refs)
type audioContext

// AudioContext reference (lazily created)
let audioCtxRef: ref<option<audioContext>> = ref(None)

// State tracking
let isPlayingRef = ref(false)
let nextNoteTimeRef = ref(0.0)
let currentStepRef = ref(0)
let schedulerIdRef: ref<option<int>> = ref(None)

//  Constants 

let bpm = 114.0
let secondsPerBeat = SafeFloat.divOr(60.0, bpm, ~default=0.526)
let secondsPerStep = secondsPerBeat /. 4.0 // 16th notes
let scheduleAheadTimeSec = 0.1 // Look-ahead window for scheduling
let schedulerIntervalMs = 25 // Scheduler callback interval

// Total steps in the loop (8 bars x 4 beats x 4 sixteenths = 128 steps)
// Using a shorter 16-step pattern that repeats for simplicity
let patternLength = 16

//  Melody Pattern 
//
// Note frequencies (Hz) for a simple bouncy melody.
// 0.0 = rest (no note played).
// Pattern: 8 bars of C major pentatonic in a digging-themed rhythm.

let melodyNotes: array<float> = [
  523.25, // C5
  0.0, // rest
  659.26, // E5
  0.0, // rest
  783.99, // G5
  698.46, // F5
  659.26, // E5
  0.0, // rest
  523.25, // C5
  587.33, // D5
  659.26, // E5
  523.25, // C5
  440.00, // A4
  0.0, // rest
  523.25, // C5
  0.0, // rest
]

// Bass pattern  octave-lower root notes
let bassNotes: array<float> = [
  130.81, // C3
  0.0,
  0.0,
  0.0,
  164.81, // E3
  0.0,
  0.0,
  0.0,
  130.81, // C3
  0.0,
  146.83, // D3
  0.0,
  110.00, // A2
  0.0,
  0.0,
  0.0,
]

//  Oscillator Helpers 

// Create and play a short note using Web Audio API.
// waveType: "square" | "triangle" | "sawtooth"
// Params are used in %raw block below (ReScript warns because it cannot see into %raw).
@@warning("-27")
let playNote = (
  freq: float,
  ~startTime: float,
  ~duration: float,
  ~waveType: string,
  ~gain: float,
): unit => {
  switch audioCtxRef.contents {
  | Some(ctx) => {
      // Pass ctx in explicitly to avoid relying on ReScript variable capture
      // of opaque types in %raw.
      let _ctx = (ctx :> audioContext)
      %raw(`
        (function() {
          var osc = _ctx.createOscillator();
          var gainNode = _ctx.createGain();
          osc.type = waveType;
          osc.frequency.setValueAtTime(freq, startTime);
          gainNode.gain.setValueAtTime(gain, startTime);
          gainNode.gain.exponentialRampToValueAtTime(0.001, startTime + duration);
          osc.connect(gainNode);
          gainNode.connect(_ctx.destination);
          osc.start(startTime);
          osc.stop(startTime + duration + 0.02);
        })()
      `)
    }
  | None => ()
  }
}

//  Scheduler 
//
// Look-ahead scheduler that pre-schedules notes slightly ahead
// of real time. This prevents timing jitter from JS event loop.

let scheduleNotes = (): unit => {
  switch audioCtxRef.contents {
  | Some(ctx) => {
      let _ctx = (ctx :> audioContext)
      ignore(_ctx)
      let currentTime: float = %raw(`_ctx.currentTime`)
      while nextNoteTimeRef.contents < currentTime +. scheduleAheadTimeSec {
        let step = mod(currentStepRef.contents, patternLength)

        // Melody  square wave
        switch melodyNotes[step] {
        | Some(freq) if freq > 0.0 =>
          playNote(
            freq,
            ~startTime=nextNoteTimeRef.contents,
            ~duration=secondsPerStep *. 0.8,
            ~waveType="square",
            ~gain=0.08,
          )
        | _ => ()
        }

        // Bass  triangle wave
        switch bassNotes[step] {
        | Some(freq) if freq > 0.0 =>
          playNote(
            freq,
            ~startTime=nextNoteTimeRef.contents,
            ~duration=secondsPerStep *. 1.5,
            ~waveType="triangle",
            ~gain=0.12,
          )
        | _ => ()
        }

        // Advance
        nextNoteTimeRef.contents = nextNoteTimeRef.contents +. secondsPerStep
        currentStepRef.contents = currentStepRef.contents + 1
      }
    }
  | None => ()
  }
}

//  Public API 

// Start playing the underground training music loop
let start = (): unit => {
  if !isPlayingRef.contents {
    // Create or resume AudioContext
    let ctx: audioContext = switch audioCtxRef.contents {
    | Some(_existing) => {
        let _ = %raw(`_existing.resume()`)
        _existing
      }
    | None => {
        let newCtx: audioContext = %raw(`new (window.AudioContext || window.webkitAudioContext)()`)
        audioCtxRef := Some(newCtx)
        newCtx
      }
    }

    // Reset scheduling state
    let _ctx = (ctx :> audioContext)
    ignore(_ctx)
    let currentTime: float = %raw(`_ctx.currentTime`)
    nextNoteTimeRef.contents = currentTime
    currentStepRef.contents = 0
    isPlayingRef.contents = true

    // Start scheduler interval
    let id: int = %raw(`setInterval(function() { scheduleNotes() }, schedulerIntervalMs)`)
    schedulerIdRef := Some(id)
  }
}

// Stop playing the music
let stop = (): unit => {
  if isPlayingRef.contents {
    isPlayingRef.contents = false

    // Clear scheduler interval
    switch schedulerIdRef.contents {
    | Some(_id) => %raw(`clearInterval(_id)`)
    | None => ()
    }
    schedulerIdRef := None

    // Suspend AudioContext to save resources
    switch audioCtxRef.contents {
    | Some(_existing) => {
        let _ = %raw(`_existing.suspend()`)
      }
    | None => ()
    }
  }
}

// Is the music currently playing?
let isPlaying = (): bool => isPlayingRef.contents
