// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Arithmetic conformance tests matching PolyglotFormalisms specification.
 *
 * These tests correspond exactly to the test cases defined in:
 * - aggregate-library/specs/arithmetic/*.md
 */

open RescriptMocha

describe("Arithmetic Operations", () => {
  describe("add", () => {
    it("should add positive integers", () => {
      Assert.equal(Arithmetic.add(2.0, 3.0), 5.0)
    })

    it("should add with negative number", () => {
      Assert.equal(Arithmetic.add(-5.0, 3.0), -2.0)
    })

    it("should add zeros", () => {
      Assert.equal(Arithmetic.add(0.0, 0.0), 0.0)
    })

    it("should add decimal numbers", () => {
      Assert.equal(Arithmetic.add(1.5, 2.5), 4.0)
    })

    it("should add two negative numbers", () => {
      Assert.equal(Arithmetic.add(-10.0, -20.0), -30.0)
    })

    describe("Commutativity", () => {
      it("should be commutative (5 + 3 == 3 + 5)", () => {
        Assert.equal(Arithmetic.add(5.0, 3.0), Arithmetic.add(3.0, 5.0))
      })

      it("should be commutative (-2 + 7 == 7 + -2)", () => {
        Assert.equal(Arithmetic.add(-2.0, 7.0), Arithmetic.add(7.0, -2.0))
      })
    })

    describe("Associativity", () => {
      it("should be associative ((2 + 3) + 4 == 2 + (3 + 4))", () => {
        Assert.equal(
          Arithmetic.add(Arithmetic.add(2.0, 3.0), 4.0),
          Arithmetic.add(2.0, Arithmetic.add(3.0, 4.0)),
        )
      })
    })

    describe("Identity", () => {
      it("should have identity element 0 (5 + 0 == 5)", () => {
        Assert.equal(Arithmetic.add(5.0, 0.0), 5.0)
      })

      it("should have identity element 0 (0 + 5 == 5)", () => {
        Assert.equal(Arithmetic.add(0.0, 5.0), 5.0)
      })
    })
  })

  describe("subtract", () => {
    it("should subtract positive integers", () => {
      Assert.equal(Arithmetic.subtract(10.0, 3.0), 7.0)
    })

    it("should result in negative", () => {
      Assert.equal(Arithmetic.subtract(5.0, 8.0), -3.0)
    })

    it("should subtract zeros", () => {
      Assert.equal(Arithmetic.subtract(0.0, 0.0), 0.0)
    })

    it("should subtract decimals", () => {
      Assert.closeTo(Arithmetic.subtract(10.5, 3.2), 7.3, 0.0001)
    })

    it("should subtract two negatives", () => {
      Assert.equal(Arithmetic.subtract(-5.0, -3.0), -2.0)
    })

    describe("Identity", () => {
      it("should have identity element 0 (7 - 0 == 7)", () => {
        Assert.equal(Arithmetic.subtract(7.0, 0.0), 7.0)
      })
    })
  })

  describe("multiply", () => {
    it("should multiply positive integers", () => {
      Assert.equal(Arithmetic.multiply(4.0, 5.0), 20.0)
    })

    it("should multiply with negative", () => {
      Assert.equal(Arithmetic.multiply(-3.0, 7.0), -21.0)
    })

    it("should multiply by zero", () => {
      Assert.equal(Arithmetic.multiply(0.0, 100.0), 0.0)
    })

    it("should multiply decimals", () => {
      Assert.equal(Arithmetic.multiply(2.5, 4.0), 10.0)
    })

    it("should multiply two negatives", () => {
      Assert.equal(Arithmetic.multiply(-2.0, -3.0), 6.0)
    })

    describe("Commutativity", () => {
      it("should be commutative (4 * 5 == 5 * 4)", () => {
        Assert.equal(Arithmetic.multiply(4.0, 5.0), Arithmetic.multiply(5.0, 4.0))
      })
    })

    describe("Identity", () => {
      it("should have identity element 1 (7 * 1 == 7)", () => {
        Assert.equal(Arithmetic.multiply(7.0, 1.0), 7.0)
      })
    })

    describe("Zero element", () => {
      it("should have zero element (100 * 0 == 0)", () => {
        Assert.equal(Arithmetic.multiply(100.0, 0.0), 0.0)
      })
    })
  })

  describe("divide", () => {
    it("should divide integers", () => {
      Assert.equal(Arithmetic.divide(10.0, 2.0), 5.0)
    })

    it("should divide with remainder", () => {
      Assert.equal(Arithmetic.divide(7.0, 2.0), 3.5)
    })

    it("should divide decimals", () => {
      Assert.closeTo(Arithmetic.divide(10.5, 2.0), 5.25, 0.0001)
    })

    it("should divide with negative", () => {
      Assert.equal(Arithmetic.divide(-10.0, 2.0), -5.0)
    })

    it("should divide by negative", () => {
      Assert.equal(Arithmetic.divide(5.0, -2.0), -2.5)
    })

    describe("Identity", () => {
      it("should have identity element 1 (7 / 1 == 7)", () => {
        Assert.equal(Arithmetic.divide(7.0, 1.0), 7.0)
      })
    })

    describe("Division by zero", () => {
      it("should return Infinity for division by zero", () => {
        Assert.isInfinite(Arithmetic.divide(5.0, 0.0))
      })
    })
  })

  describe("modulo", () => {
    it("should compute modulo", () => {
      Assert.equal(Arithmetic.modulo(10.0, 3.0), 1.0)
    })

    it("should compute modulo with larger remainder", () => {
      Assert.equal(Arithmetic.modulo(15.0, 4.0), 3.0)
    })

    it("should return 0 for equal numbers", () => {
      Assert.equal(Arithmetic.modulo(7.0, 7.0), 0.0)
    })

    it("should return 0 for zero modulo", () => {
      Assert.equal(Arithmetic.modulo(0.0, 5.0), 0.0)
    })

    it("should return 0 for modulo by 1", () => {
      Assert.equal(Arithmetic.modulo(10.0, 1.0), 0.0)
    })
  })
})
