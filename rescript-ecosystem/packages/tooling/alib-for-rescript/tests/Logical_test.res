// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Logical conformance tests matching PolyglotFormalisms specification.
 */

open RescriptMocha

describe("Logical Operations", () => {
  describe("and", () => {
    it("should return true for true && true", () => {
      Assert.isTrue(Logical.and(true, true))
    })

    it("should return false for true && false", () => {
      Assert.isFalse(Logical.and(true, false))
    })

    it("should return false for false && true", () => {
      Assert.isFalse(Logical.and(false, true))
    })

    it("should return false for false && false", () => {
      Assert.isFalse(Logical.and(false, false))
    })

    describe("Commutativity", () => {
      it("should be commutative (a && b == b && a)", () => {
        Assert.equal(Logical.and(true, false), Logical.and(false, true))
      })
    })

    describe("Identity", () => {
      it("should have identity element true (true && true == true)", () => {
        Assert.equal(Logical.and(true, true), true)
      })

      it("should have identity element true (false && true == false)", () => {
        Assert.equal(Logical.and(false, true), false)
      })
    })

    describe("Annihilator", () => {
      it("should have annihilator false (true && false == false)", () => {
        Assert.equal(Logical.and(true, false), false)
      })
    })

    describe("Idempotence", () => {
      it("should be idempotent (true && true == true)", () => {
        Assert.equal(Logical.and(true, true), true)
      })

      it("should be idempotent (false && false == false)", () => {
        Assert.equal(Logical.and(false, false), false)
      })
    })
  })

  describe("or", () => {
    it("should return true for true || true", () => {
      Assert.isTrue(Logical.or(true, true))
    })

    it("should return true for true || false", () => {
      Assert.isTrue(Logical.or(true, false))
    })

    it("should return true for false || true", () => {
      Assert.isTrue(Logical.or(false, true))
    })

    it("should return false for false || false", () => {
      Assert.isFalse(Logical.or(false, false))
    })

    describe("Commutativity", () => {
      it("should be commutative (a || b == b || a)", () => {
        Assert.equal(Logical.or(true, false), Logical.or(false, true))
      })
    })

    describe("Identity", () => {
      it("should have identity element false (true || false == true)", () => {
        Assert.equal(Logical.or(true, false), true)
      })

      it("should have identity element false (false || false == false)", () => {
        Assert.equal(Logical.or(false, false), false)
      })
    })

    describe("Annihilator", () => {
      it("should have annihilator true (true || true == true)", () => {
        Assert.equal(Logical.or(true, true), true)
      })

      it("should have annihilator true (false || true == true)", () => {
        Assert.equal(Logical.or(false, true), true)
      })
    })
  })

  describe("not", () => {
    it("should return false for !true", () => {
      Assert.isFalse(Logical.not(true))
    })

    it("should return true for !false", () => {
      Assert.isTrue(Logical.not(false))
    })

    describe("Involution", () => {
      it("should satisfy double negation (!!true == true)", () => {
        Assert.equal(Logical.not(Logical.not(true)), true)
      })

      it("should satisfy double negation (!!false == false)", () => {
        Assert.equal(Logical.not(Logical.not(false)), false)
      })
    })

    describe("Excluded middle", () => {
      it("should satisfy excluded middle (true || !true == true)", () => {
        Assert.isTrue(Logical.or(true, Logical.not(true)))
      })

      it("should satisfy excluded middle (false || !false == true)", () => {
        Assert.isTrue(Logical.or(false, Logical.not(false)))
      })
    })

    describe("Non-contradiction", () => {
      it("should satisfy non-contradiction (true && !true == false)", () => {
        Assert.isFalse(Logical.and(true, Logical.not(true)))
      })

      it("should satisfy non-contradiction (false && !false == false)", () => {
        Assert.isFalse(Logical.and(false, Logical.not(false)))
      })
    })
  })
})
