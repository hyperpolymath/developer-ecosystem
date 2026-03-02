// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * String
 *
 * String operations from the PolyglotFormalisms Common Library specification.
 *
 * ReScript implementation matching aggregate-library behavioral semantics.
 */

/**
 * Concatenates two strings.
 *
 * # Behavioral Semantics
 * - Parameters: a (first string), b (second string)
 * - Returns: The concatenation of a and b
 *
 * # Mathematical Properties
 * - Associativity: concat(concat(a, b), c) == concat(a, concat(b, c))
 * - Identity element: concat(a, "") == concat("", a) == a
 * - Non-commutativity: concat(a, b) != concat(b, a) (in general)
 */
let concat = (a: string, b: string): string => a ++ b

/**
 * Returns the length of a string (number of characters).
 *
 * # Behavioral Semantics
 * - Parameters: s (string to measure)
 * - Returns: Number of Unicode characters in the string
 *
 * # Mathematical Properties
 * - Non-negativity: length(s) >= 0
 * - Empty string: length("") == 0
 * - Concatenation: length(concat(a, b)) == length(a) + length(b)
 */
let length = (s: string): int => String.length(s)

/**
 * Extracts a substring from start index to end index (inclusive, 0-indexed in ReScript).
 *
 * # Behavioral Semantics
 * - Parameters: s (source string), start (start index), end_pos (end index)
 * - Returns: Substring from start to end_pos (inclusive)
 * - Indexing: 0-based (ReScript convention)
 *
 * # Edge Cases
 * - If start > end_pos: returns empty string
 * - If indices out of bounds: returns empty string or truncated result
 */
let substring = (s: string, start: int, endPos: int): string => {
  if start > endPos {
    ""
  } else {
    let len = endPos - start + 1
    String.slice(s, ~start, ~end=start + len)
  }
}

/**
 * Finds the first occurrence of a substring.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to search), substr (substring to find)
 * - Returns: 0-based index of first occurrence, or -1 if not found
 *
 * # Mathematical Properties
 * - Not found convention: returns -1 (ReScript standard)
 * - Empty substring: indexOf(s, "") == 0 (found at start)
 */
let indexOf = (s: string, substr: string): int => {
  if substr == "" {
    0
  } else {
    switch String.indexOf(s, substr) {
    | Some(idx) => idx
    | None => -1
    }
  }
}

/**
 * Checks if a string contains a substring.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to search), substr (substring to find)
 * - Returns: true if substr is found in s, false otherwise
 *
 * # Mathematical Properties
 * - Empty substring: contains(s, "") == true (always)
 * - Reflexivity: contains(s, s) == true
 */
let contains = (s: string, substr: string): bool => String.includes(s, substr)

/**
 * Checks if a string starts with a given prefix.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to check), prefix (prefix to match)
 * - Returns: true if s starts with prefix, false otherwise
 *
 * # Mathematical Properties
 * - Empty prefix: startsWith(s, "") == true (always)
 * - Reflexivity: startsWith(s, s) == true
 */
let startsWith = (s: string, prefix: string): bool => String.startsWith(s, prefix)

/**
 * Checks if a string ends with a given suffix.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to check), suffix (suffix to match)
 * - Returns: true if s ends with suffix, false otherwise
 *
 * # Mathematical Properties
 * - Empty suffix: endsWith(s, "") == true (always)
 * - Reflexivity: endsWith(s, s) == true
 */
let endsWith = (s: string, suffix: string): bool => String.endsWith(s, suffix)

/**
 * Converts all characters in a string to uppercase.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to convert)
 * - Returns: New string with all characters in uppercase
 *
 * # Mathematical Properties
 * - Idempotence: toUppercase(toUppercase(s)) == toUppercase(s)
 */
let toUppercase = (s: string): string => String.toUpperCase(s)

/**
 * Converts all characters in a string to lowercase.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to convert)
 * - Returns: New string with all characters in lowercase
 *
 * # Mathematical Properties
 * - Idempotence: toLowercase(toLowercase(s)) == toLowercase(s)
 */
let toLowercase = (s: string): string => String.toLowerCase(s)

/**
 * Removes leading and trailing whitespace from a string.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to trim)
 * - Returns: New string with whitespace removed from both ends
 *
 * # Mathematical Properties
 * - Idempotence: trim(trim(s)) == trim(s)
 */
let trim = (s: string): string => String.trim(s)

/**
 * Splits a string into parts using a delimiter.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to split), delimiter (separator)
 * - Returns: Array of substrings
 * - Empty delimiter: returns array of individual characters
 */
let split = (s: string, delimiter: string): array<string> => {
  if delimiter == "" {
    String.split(s, "")
  } else {
    String.split(s, delimiter)
  }
}

/**
 * Joins an array of strings with a separator.
 *
 * # Behavioral Semantics
 * - Parameters: parts (array of strings), separator (string to insert between parts)
 * - Returns: Single string with parts joined by separator
 *
 * # Mathematical Properties
 * - Empty array: join([], sep) == ""
 * - Single element: join([s], sep) == s
 */
let join = (parts: array<string>, separator: string): string => Array.joinWith(parts, separator)

/**
 * Replaces all occurrences of a substring with another string.
 *
 * # Behavioral Semantics
 * - Parameters: s (source string), old (substring to replace), new (replacement)
 * - Returns: New string with all occurrences replaced
 *
 * # Edge Cases
 * - old not found: returns original string unchanged
 * - Empty old: returns original string unchanged
 */
let replace = (s: string, old: string, newStr: string): string => {
  if old == "" {
    s
  } else {
    String.replaceAll(s, old, newStr)
  }
}

/**
 * Checks if a string is empty.
 *
 * # Behavioral Semantics
 * - Parameters: s (string to check)
 * - Returns: true if string has zero length, false otherwise
 *
 * # Mathematical Properties
 * - Equivalent to: length(s) == 0
 */
let isEmpty = (s: string): bool => s == ""
