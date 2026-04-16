// SPDX-License-Identifier: PMPL-1.0-or-later
// Random utilities for ReScript

// Math helpers
@val @scope("Math") external imul: (int, int) => int = "imul"
@val @scope("Math") external floor: float => int = "floor"
@val @scope("Math") external sqrt: float => float = "sqrt"
@val @scope("Math") external random: unit => float = "random"
@val @scope("Math") external floatMin: (float, float) => float = "min"
@val @scope("Math") external floatMax: (float, float) => float = "max"

// Bitwise operations using raw JS
let lxor: (int, int) => int = %raw(`(a, b) => a ^ b`)
let lor: (int, int) => int = %raw(`(a, b) => a | b`)
let land: (int, int) => int = %raw(`(a, b) => a & b`)
let lsl: (int, int) => int = %raw(`(a, b) => a << b`)
let lsr: (int, int) => int = %raw(`(a, b) => a >>> b`)

// xmur3 hash function for seeding - use raw JS to avoid integer overflow warnings
let xmur3: string => (unit => int) = %raw(`
  function(str) {
    var h = 1779033703 ^ str.length;
    for (var i = 0; i < str.length; i++) {
      h = Math.imul(h ^ str.charCodeAt(i), 3432918353);
      h = (h << 13) | (h >>> 19);
    }
    return function() {
      h = Math.imul(h ^ (h >>> 16), 2246822507);
      h = Math.imul(h ^ (h >>> 13), 3266489909);
      return (h ^= h >>> 16) >>> 0;
    };
  }
`)

// mulberry32 PRNG
let mulberry32: int => (unit => float) = %raw(`
  function(seed) {
    var a = seed;
    return function() {
      a = (a + 0x6d2b79f5) | 0;
      var t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
`)

let hashCharset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

// Creates a seeded random function
let seeded = (seed: string): (unit => float) => {
  mulberry32(xmur3(seed)())
}

// Returns a random color
let color = (~randomFn=random, ()): int => {
  let r = floor(255.0 *. randomFn())
  let g = floor(255.0 *. randomFn())
  let b = floor(255.0 *. randomFn())
  lor(lor(lsl(r, 16), lsl(g, 8)), b)
}

// Returns a random number within a range
let range = (~randomFn=random, min: float, max: float): float => {
  let a = floatMin(min, max)
  let b = floatMax(min, max)
  a +. (b -. a) *. randomFn()
}

// Returns a random item from an array
let item = (~randomFn=random, arr: array<'a>): option<'a> => {
  let len = Array.length(arr)
  if len == 0 {
    None
  } else {
    Array.get(arr, floor(randomFn() *. Int.toFloat(len)))
  }
}

// Returns a random boolean
let bool = (~weight=0.5, ~randomFn=random, ()): bool => {
  randomFn() < weight
}

// Shuffle array in place (using raw JS for efficiency)
let shuffle: (~randomFn: unit => float=?, array<'a>) => array<'a> = %raw(`
  function(randomFn, arr) {
    var rng = randomFn || Math.random;
    var currentIndex = arr.length;
    while (currentIndex !== 0) {
      var randomIndex = Math.floor(rng() * currentIndex);
      currentIndex--;
      var temp = arr[currentIndex];
      arr[currentIndex] = arr[randomIndex];
      arr[randomIndex] = temp;
    }
    return arr;
  }
`)

// Returns a random hash string
let hash = (~randomFn=random, ~charset=hashCharset, length: int): string => {
  let charsetLength = String.length(charset)
  let result = ref("")

  for _ in 0 to length - 1 {
    let idx = floor(randomFn() *. Int.toFloat(charsetLength))
    result := result.contents ++ String.charAt(charset, idx)
  }

  result.contents
}

// Returns a random float within a range
let float = (~randomFn=random, min: float, max: float): float => {
  randomFn() *. (max -. min) +. min
}

// Returns a random integer within a range (inclusive)
let int = (~randomFn=random, min: int, max: int): int => {
  floor(randomFn() *. Int.toFloat(max - min + 1)) + min
}
