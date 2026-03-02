// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Logical operations from the PolyglotFormalisms Common Library specification.
 *
 * ReScript implementation matching aggregate-library behavioral semantics.
 *
 * Each operation includes:
 * - Implementation following PolyglotFormalisms specification
 * - Type signatures for boolean operations
 * - Documentation matching specification format
 */

/**
 * and(a, b) -> bool
 *
 * Computes the logical conjunction (AND) of two boolean values.
 *
 * # Behavioral Semantics
 * - Parameters: a (first boolean), b (second boolean)
 * - Returns: true if both a and b are true, otherwise false
 *
 * # Truth Table
 * | a     | b     | and(a, b) |
 * |-------|-------|-----------|
 * | true  | true  | true      |
 * | true  | false | false     |
 * | false | true  | false     |
 * | false | false | false     |
 *
 * # Mathematical Properties
 * - Commutativity: and(a, b) == and(b, a)
 * - Associativity: and(and(a, b), c) == and(a, and(b, c))
 * - Identity element: and(a, true) == a
 * - Annihilator: and(a, false) == false
 * - Idempotence: and(a, a) == a
 * - Distributivity: and(a, or(b, c)) == or(and(a, b), and(a, c))
 *
 * # Examples
 * ```rescript
 * and(true, true)     // Returns true
 * and(true, false)    // Returns false
 * and(false, true)    // Returns false
 * and(false, false)   // Returns false
 * ```
 */
let and = (a: bool, b: bool): bool => a && b

/**
 * or(a, b) -> bool
 *
 * Computes the logical disjunction (OR) of two boolean values.
 *
 * # Behavioral Semantics
 * - Parameters: a (first boolean), b (second boolean)
 * - Returns: true if at least one of a or b is true, otherwise false
 *
 * # Truth Table
 * | a     | b     | or(a, b) |
 * |-------|-------|----------|
 * | true  | true  | true     |
 * | true  | false | true     |
 * | false | true  | true     |
 * | false | false | false    |
 *
 * # Mathematical Properties
 * - Commutativity: or(a, b) == or(b, a)
 * - Associativity: or(or(a, b), c) == or(a, or(b, c))
 * - Identity element: or(a, false) == a
 * - Annihilator: or(a, true) == true
 * - Idempotence: or(a, a) == a
 * - Distributivity: or(a, and(b, c)) == and(or(a, b), or(a, c))
 *
 * # Examples
 * ```rescript
 * or(true, true)     // Returns true
 * or(true, false)    // Returns true
 * or(false, true)    // Returns true
 * or(false, false)   // Returns false
 * ```
 */
let or = (a: bool, b: bool): bool => a || b

/**
 * not(a) -> bool
 *
 * Computes the logical negation (NOT) of a boolean value.
 *
 * # Behavioral Semantics
 * - Parameters: a (boolean value to negate)
 * - Returns: true if a is false, false if a is true
 *
 * # Truth Table
 * | a     | not(a) |
 * |-------|--------|
 * | true  | false  |
 * | false | true   |
 *
 * # Mathematical Properties
 * - Involution (double negation): not(not(a)) == a
 * - Excluded middle: or(a, not(a)) == true
 * - Non-contradiction: and(a, not(a)) == false
 * - De Morgan's laws:
 *   - not(and(a, b)) == or(not(a), not(b))
 *   - not(or(a, b)) == and(not(a), not(b))
 *
 * # Examples
 * ```rescript
 * not(true)     // Returns false
 * not(false)    // Returns true
 * ```
 */
let not = (a: bool): bool => !a
