// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Comparison conformance tests matching PolyglotFormalisms specification.
 */

open RescriptMocha

describe("Comparison Operations", () => {
  describe("lessThan", () => {
    it("should return true for 2 < 3", () => {
      Assert.isTrue(Comparison.lessThan(2.0, 3.0))
    })

    it("should return false for 5 < 5", () => {
      Assert.isFalse(Comparison.lessThan(5.0, 5.0))
    })

    it("should return false for 10 < 3", () => {
      Assert.isFalse(Comparison.lessThan(10.0, 3.0))
    })

    it("should return true for -5 < 0", () => {
      Assert.isTrue(Comparison.lessThan(-5.0, 0.0))
    })

    describe("Transitivity", () => {
      it("should be transitive (1 < 2 && 2 < 3 => 1 < 3)", () => {
        let a = 1.0
        let b = 2.0
        let c = 3.0
        Assert.isTrue(
          Comparison.lessThan(a, b) &&
          Comparison.lessThan(b, c) &&
          Comparison.lessThan(a, c),
        )
      })
    })

    describe("Irreflexivity", () => {
      it("should never be less than itself", () => {
        Assert.isFalse(Comparison.lessThan(5.0, 5.0))
      })
    })
  })

  describe("greaterThan", () => {
    it("should return true for 5 > 3", () => {
      Assert.isTrue(Comparison.greaterThan(5.0, 3.0))
    })

    it("should return false for 2 > 2", () => {
      Assert.isFalse(Comparison.greaterThan(2.0, 2.0))
    })

    it("should return false for 1 > 10", () => {
      Assert.isFalse(Comparison.greaterThan(1.0, 10.0))
    })
  })

  describe("equal", () => {
    it("should return true for 5 == 5", () => {
      Assert.isTrue(Comparison.equal(5.0, 5.0))
    })

    it("should return false for 3 == 7", () => {
      Assert.isFalse(Comparison.equal(3.0, 7.0))
    })

    describe("Reflexivity", () => {
      it("should always equal itself", () => {
        Assert.isTrue(Comparison.equal(5.0, 5.0))
      })
    })

    describe("Symmetry", () => {
      it("should be symmetric (a == b => b == a)", () => {
        let a = 5.0
        let b = 5.0
        Assert.equal(Comparison.equal(a, b), Comparison.equal(b, a))
      })
    })
  })

  describe("notEqual", () => {
    it("should return true for 5 != 3", () => {
      Assert.isTrue(Comparison.notEqual(5.0, 3.0))
    })

    it("should return false for 7 != 7", () => {
      Assert.isFalse(Comparison.notEqual(7.0, 7.0))
    })

    describe("Negation of equal", () => {
      it("should be opposite of equal", () => {
        let a = 5.0
        let b = 3.0
        Assert.equal(Comparison.notEqual(a, b), !Comparison.equal(a, b))
      })
    })
  })

  describe("lessEqual", () => {
    it("should return true for 2 <= 3", () => {
      Assert.isTrue(Comparison.lessEqual(2.0, 3.0))
    })

    it("should return true for 5 <= 5", () => {
      Assert.isTrue(Comparison.lessEqual(5.0, 5.0))
    })

    it("should return false for 10 <= 3", () => {
      Assert.isFalse(Comparison.lessEqual(10.0, 3.0))
    })

    describe("Reflexivity", () => {
      it("should always be less than or equal to itself", () => {
        Assert.isTrue(Comparison.lessEqual(5.0, 5.0))
      })
    })
  })

  describe("greaterEqual", () => {
    it("should return true for 5 >= 3", () => {
      Assert.isTrue(Comparison.greaterEqual(5.0, 3.0))
    })

    it("should return true for 7 >= 7", () => {
      Assert.isTrue(Comparison.greaterEqual(7.0, 7.0))
    })

    it("should return false for 2 >= 10", () => {
      Assert.isFalse(Comparison.greaterEqual(2.0, 10.0))
    })
  })
})
