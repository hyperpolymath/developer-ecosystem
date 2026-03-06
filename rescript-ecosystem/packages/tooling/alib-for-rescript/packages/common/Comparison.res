// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Comparison operations from the PolyglotFormalisms Common Library specification.
 *
 * ReScript implementation matching aggregate-library behavioral semantics.
 *
 * Each operation includes:
 * - Implementation following PolyglotFormalisms specification
 * - Type signatures for comparison operations
 * - Documentation matching specification format
 */

/**
 * lessThan(a, b) -> bool
 *
 * Checks if the first value is strictly less than the second value.
 *
 * # Behavioral Semantics
 * - Parameters: a (first value), b (second value)
 * - Returns: true if a < b, otherwise false
 *
 * # Mathematical Properties
 * - Transitivity: lessThan(a, b) && lessThan(b, c) => lessThan(a, c)
 * - Irreflexivity: !lessThan(a, a)
 * - Asymmetry: lessThan(a, b) => !lessThan(b, a)
 *
 * # Examples
 * ```rescript
 * lessThan(2.0, 3.0)       // Returns true
 * lessThan(5.0, 5.0)       // Returns false
 * lessThan(10.0, 3.0)      // Returns false
 * lessThan(-5.0, 0.0)      // Returns true
 * lessThan(1.5, 2.5)       // Returns true
 * ```
 */
let lessThan = (a: float, b: float): bool => a < b

/**
 * greaterThan(a, b) -> bool
 *
 * Checks if the first value is strictly greater than the second value.
 *
 * # Behavioral Semantics
 * - Parameters: a (first value), b (second value)
 * - Returns: true if a > b, otherwise false
 *
 * # Mathematical Properties
 * - Transitivity: greaterThan(a, b) && greaterThan(b, c) => greaterThan(a, c)
 * - Irreflexivity: !greaterThan(a, a)
 * - Relation to lessThan: greaterThan(a, b) == lessThan(b, a)
 *
 * # Examples
 * ```rescript
 * greaterThan(5.0, 3.0)       // Returns true
 * greaterThan(2.0, 2.0)       // Returns false
 * greaterThan(1.0, 10.0)      // Returns false
 * greaterThan(0.0, -5.0)      // Returns true
 * greaterThan(3.5, 1.2)       // Returns true
 * ```
 */
let greaterThan = (a: float, b: float): bool => a > b

/**
 * equal(a, b) -> bool
 *
 * Checks if two values are equal.
 *
 * # Behavioral Semantics
 * - Parameters: a (first value), b (second value)
 * - Returns: true if a == b, otherwise false
 *
 * # Mathematical Properties
 * - Reflexivity: equal(a, a)
 * - Symmetry: equal(a, b) => equal(b, a)
 * - Transitivity: equal(a, b) && equal(b, c) => equal(a, c)
 *
 * # Edge Cases
 * - NaN: equal(NaN, NaN) returns false (IEEE 754)
 * - Infinity: equal(Infinity, Infinity) returns true
 * - Signed zero: equal(-0.0, 0.0) returns true
 *
 * # Examples
 * ```rescript
 * equal(5.0, 5.0)          // Returns true
 * equal(3.0, 7.0)          // Returns false
 * equal(0.0, 0.0)          // Returns true
 * equal(2.5, 2.5)          // Returns true
 * equal(-0.0, 0.0)         // Returns true
 * ```
 */
let equal = (a: float, b: float): bool => a == b

/**
 * notEqual(a, b) -> bool
 *
 * Checks if two values are not equal.
 *
 * # Behavioral Semantics
 * - Parameters: a (first value), b (second value)
 * - Returns: true if a != b, otherwise false
 *
 * # Mathematical Properties
 * - Negation of equal: notEqual(a, b) == !equal(a, b)
 * - Symmetry: notEqual(a, b) => notEqual(b, a)
 *
 * # Edge Cases
 * - NaN: notEqual(NaN, NaN) returns true (NaN != NaN)
 * - Infinity: notEqual(Infinity, Infinity) returns false
 *
 * # Examples
 * ```rescript
 * notEqual(5.0, 3.0)       // Returns true
 * notEqual(7.0, 7.0)       // Returns false
 * notEqual(0.0, 1.0)       // Returns true
 * notEqual(-5.0, -5.0)     // Returns false
 * notEqual(2.5, 2.6)       // Returns true
 * ```
 */
let notEqual = (a: float, b: float): bool => a != b

/**
 * lessEqual(a, b) -> bool
 *
 * Checks if the first value is less than or equal to the second value.
 *
 * # Behavioral Semantics
 * - Parameters: a (first value), b (second value)
 * - Returns: true if a <= b, otherwise false
 *
 * # Mathematical Properties
 * - Reflexivity: lessEqual(a, a)
 * - Transitivity: lessEqual(a, b) && lessEqual(b, c) => lessEqual(a, c)
 * - Antisymmetry: lessEqual(a, b) && lessEqual(b, a) => equal(a, b)
 * - Relation to lessThan: lessEqual(a, b) == (lessThan(a, b) || equal(a, b))
 *
 * # Examples
 * ```rescript
 * lessEqual(2.0, 3.0)       // Returns true
 * lessEqual(5.0, 5.0)       // Returns true
 * lessEqual(10.0, 3.0)      // Returns false
 * lessEqual(-5.0, 0.0)      // Returns true
 * lessEqual(1.5, 1.5)       // Returns true
 * ```
 */
let lessEqual = (a: float, b: float): bool => a <= b

/**
 * greaterEqual(a, b) -> bool
 *
 * Checks if the first value is greater than or equal to the second value.
 *
 * # Behavioral Semantics
 * - Parameters: a (first value), b (second value)
 * - Returns: true if a >= b, otherwise false
 *
 * # Mathematical Properties
 * - Reflexivity: greaterEqual(a, a)
 * - Transitivity: greaterEqual(a, b) && greaterEqual(b, c) => greaterEqual(a, c)
 * - Antisymmetry: greaterEqual(a, b) && greaterEqual(b, a) => equal(a, b)
 * - Relation to lessEqual: greaterEqual(a, b) == lessEqual(b, a)
 *
 * # Examples
 * ```rescript
 * greaterEqual(5.0, 3.0)       // Returns true
 * greaterEqual(7.0, 7.0)       // Returns true
 * greaterEqual(2.0, 10.0)      // Returns false
 * greaterEqual(0.0, -5.0)      // Returns true
 * greaterEqual(3.5, 3.5)       // Returns true
 * ```
 */
let greaterEqual = (a: float, b: float): bool => a >= b
