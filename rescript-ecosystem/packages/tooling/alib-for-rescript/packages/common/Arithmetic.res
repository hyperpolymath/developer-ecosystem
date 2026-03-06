// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Arithmetic operations from the PolyglotFormalisms Common Library specification.
 *
 * ReScript implementation matching aggregate-library behavioral semantics.
 *
 * Each operation includes:
 * - Implementation following PolyglotFormalisms specification
 * - Type signatures for numeric operations
 * - Documentation matching specification format
 */

/**
 * add(a, b) -> number
 *
 * Computes the sum of two numbers.
 *
 * # Behavioral Semantics
 * - Parameters: a (augend), b (addend)
 * - Returns: The arithmetic sum of a and b
 *
 * # Mathematical Properties
 * - Commutativity: add(a, b) == add(b, a)
 * - Associativity: add(add(a, b), c) == add(a, add(b, c))
 * - Identity element: add(a, 0) == a
 *
 * # Examples
 * ```rescript
 * add(2.0, 3.0)       // Returns 5.0
 * add(-5.0, 3.0)      // Returns -2.0
 * add(0.0, 0.0)       // Returns 0.0
 * add(1.5, 2.5)       // Returns 4.0
 * add(-10.0, -20.0)   // Returns -30.0
 * ```
 *
 * # Specification
 * This implementation conforms to PolyglotFormalisms specification:
 * aggregate-library/specs/arithmetic/add.md
 */
let add = (a: float, b: float): float => a +. b

/**
 * subtract(a, b) -> number
 *
 * Computes the difference of two numbers.
 *
 * # Behavioral Semantics
 * - Parameters: a (minuend), b (subtrahend)
 * - Returns: The arithmetic difference a - b
 *
 * # Mathematical Properties
 * - Non-commutative: subtract(a, b) != subtract(b, a) (except when a == b)
 * - Identity element: subtract(a, 0) == a
 * - Inverse of add: subtract(a, b) == add(a, -b)
 *
 * # Examples
 * ```rescript
 * subtract(10.0, 3.0)      // Returns 7.0
 * subtract(5.0, 8.0)       // Returns -3.0
 * subtract(0.0, 0.0)       // Returns 0.0
 * subtract(10.5, 3.2)      // Returns 7.3
 * subtract(-5.0, -3.0)     // Returns -2.0
 * ```
 */
let subtract = (a: float, b: float): float => a -. b

/**
 * multiply(a, b) -> number
 *
 * Computes the product of two numbers.
 *
 * # Behavioral Semantics
 * - Parameters: a (multiplicand), b (multiplier)
 * - Returns: The arithmetic product of a and b
 *
 * # Mathematical Properties
 * - Commutativity: multiply(a, b) == multiply(b, a)
 * - Associativity: multiply(multiply(a, b), c) == multiply(a, multiply(b, c))
 * - Identity element: multiply(a, 1) == a
 * - Zero element: multiply(a, 0) == 0
 * - Distributivity: multiply(a, add(b, c)) == add(multiply(a, b), multiply(a, c))
 *
 * # Examples
 * ```rescript
 * multiply(4.0, 5.0)       // Returns 20.0
 * multiply(-3.0, 7.0)      // Returns -21.0
 * multiply(0.0, 100.0)     // Returns 0.0
 * multiply(2.5, 4.0)       // Returns 10.0
 * multiply(-2.0, -3.0)     // Returns 6.0
 * ```
 */
let multiply = (a: float, b: float): float => a *. b

/**
 * divide(a, b) -> number
 *
 * Computes the quotient of two numbers.
 *
 * # Behavioral Semantics
 * - Parameters: a (dividend), b (divisor)
 * - Returns: The arithmetic quotient a / b
 *
 * # Mathematical Properties
 * - Non-commutative: divide(a, b) != divide(b, a) (except when a == b)
 * - Identity element: divide(a, 1) == a
 * - Inverse of multiply: multiply(divide(a, b), b) ≈ a (when b != 0)
 *
 * # Edge Cases
 * - Division by zero: Returns Infinity (IEEE 754 behavior)
 * - Behavior follows JavaScript/IEEE 754 floating-point division
 *
 * # Examples
 * ```rescript
 * divide(10.0, 2.0)      // Returns 5.0
 * divide(7.0, 2.0)       // Returns 3.5
 * divide(10.5, 2.0)      // Returns 5.25
 * divide(-10.0, 2.0)     // Returns -5.0
 * divide(5.0, -2.0)      // Returns -2.5
 * ```
 */
let divide = (a: float, b: float): float => a /. b

/**
 * modulo(a, b) -> number
 *
 * Computes the remainder of integer division.
 *
 * # Behavioral Semantics
 * - Parameters: a (dividend), b (divisor)
 * - Returns: The remainder of a / b
 *
 * # Mathematical Properties
 * - Range constraint: For b > 0, result is in [0, b)
 * - Division relation: a == (a / b) * b + modulo(a, b) (when b != 0)
 *
 * # Edge Cases
 * - Modulo by zero: Returns NaN (JavaScript behavior)
 * - Sign handling follows JavaScript % operator semantics
 *
 * # Examples
 * ```rescript
 * modulo(10.0, 3.0)    // Returns 1.0
 * modulo(15.0, 4.0)    // Returns 3.0
 * modulo(7.0, 7.0)     // Returns 0.0
 * modulo(-10.0, 3.0)   // Returns -1.0 (JavaScript % semantics)
 * ```
 *
 * # Note
 * ReScript/JavaScript uses % which may differ from other languages' mod.
 * This follows JavaScript semantics for cross-platform consistency.
 */
let modulo = (a: float, b: float): float => mod_float(a, b)
