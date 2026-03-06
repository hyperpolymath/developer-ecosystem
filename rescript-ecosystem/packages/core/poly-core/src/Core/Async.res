// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Async/Promise utilities for ReScript.
 */

/** Sleep for a given number of milliseconds */
let sleep = (ms: int): promise<unit> => {
  Promise.make((resolve, _reject) => {
    let _ = setTimeout(() => resolve(), ms)
  })
}

/** Timeout a promise after ms milliseconds */
exception Timeout(string)

let timeout = async (ms: int, promise: promise<'a>): 'a => {
  let timeoutPromise = Promise.make((_, reject) => {
    let _ = setTimeout(() => reject(Timeout(`Operation timed out after ${Int.toString(ms)}ms`)), ms)
  })
  await Promise.race([promise, timeoutPromise])
}

/** Retry configuration */
type retryConfig = {
  maxAttempts: int,
  initialDelayMs: int,
  maxDelayMs: int,
  backoffMultiplier: float,
}

let defaultRetryConfig: retryConfig = {
  maxAttempts: 3,
  initialDelayMs: 1000,
  maxDelayMs: 30000,
  backoffMultiplier: 2.0,
}

/** Retry a promise-returning function with exponential backoff */
let retry = async (
  ~config: retryConfig=defaultRetryConfig,
  fn: unit => promise<'a>,
): 'a => {
  let rec attempt = async (attemptNum: int, delay: int) => {
    try {
      await fn()
    } catch {
    | e =>
      if attemptNum >= config.maxAttempts {
        raise(e)
      } else {
        await sleep(delay)
        let nextDelay = Int.min(
          Float.toInt(Int.toFloat(delay) *. config.backoffMultiplier),
          config.maxDelayMs,
        )
        await attempt(attemptNum + 1, nextDelay)
      }
    }
  }
  await attempt(1, config.initialDelayMs)
}

/** Run promises in parallel with concurrency limit */
let parallelLimit = async (
  ~concurrency: int,
  tasks: array<unit => promise<'a>>,
): array<'a> => {
  let results: array<'a> = []
  let running = ref(0)
  let index = ref(0)
  let total = tasks->Array.length

  await Promise.make((resolve, reject) => {
    let rec runNext = () => {
      while running.contents < concurrency && index.contents < total {
        let currentIndex = index.contents
        index := index.contents + 1
        running := running.contents + 1

        let task = tasks->Array.getUnsafe(currentIndex)
        let _ = task()->Promise.thenResolve(result => {
          results->Array.push(result)->ignore
          running := running.contents - 1
          if results->Array.length == total {
            resolve(results)
          } else {
            runNext()
          }
        })->Promise.catch(e => {
          reject(e)
          Promise.resolve()
        })
      }
    }
    if total == 0 {
      resolve([])
    } else {
      runNext()
    }
  })
}

/** Run promises sequentially */
let sequential = async (tasks: array<unit => promise<'a>>): array<'a> => {
  let results: array<'a> = []
  for i in 0 to tasks->Array.length - 1 {
    let task = tasks->Array.getUnsafe(i)
    let result = await task()
    results->Array.push(result)->ignore
  }
  results
}

/** Map over array with async function */
let mapAsync = async (arr: array<'a>, fn: 'a => promise<'b>): array<'b> => {
  let results: array<'b> = []
  for i in 0 to arr->Array.length - 1 {
    let item = arr->Array.getUnsafe(i)
    let result = await fn(item)
    results->Array.push(result)->ignore
  }
  results
}

/** Filter array with async predicate */
let filterAsync = async (arr: array<'a>, predicate: 'a => promise<bool>): array<'a> => {
  let results: array<'a> = []
  for i in 0 to arr->Array.length - 1 {
    let item = arr->Array.getUnsafe(i)
    let keep = await predicate(item)
    if keep {
      results->Array.push(item)->ignore
    }
  }
  results
}

/** Debounce a function */
type debounced<'a> = {
  call: 'a => unit,
  cancel: unit => unit,
}

let debounce = (delayMs: int, fn: 'a => unit): debounced<'a> => {
  let timeoutId = ref(None)
  {
    call: arg => {
      switch timeoutId.contents {
      | Some(id) => clearTimeout(id)
      | None => ()
      }
      timeoutId := Some(setTimeout(() => fn(arg), delayMs))
    },
    cancel: () => {
      switch timeoutId.contents {
      | Some(id) => clearTimeout(id)
      | None => ()
      }
      timeoutId := None
    },
  }
}

/** Throttle a function */
let throttle = (limitMs: int, fn: 'a => unit): ('a => unit) => {
  let lastRun = ref(0.0)
  arg => {
    let now = Date.now()
    if now -. lastRun.contents >= Int.toFloat(limitMs) {
      lastRun := now
      fn(arg)
    }
  }
}
