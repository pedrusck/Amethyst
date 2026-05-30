//
//  LayoutMathTests.swift
//  AmethystTests
//
//  Unit tests for the LayoutMath helpers that guard paned-layout
//  arithmetic against zero counts, non-finite divisors, and
//  out-of-range ratios.
//

@testable import Amethyst
import CoreGraphics
import Nimble
import Quick

class LayoutMathTests: QuickSpec {
    override func spec() {
        describe("safeDivide(_:_:)") {
            it("divides normally for positive finite divisors") {
                expect(LayoutMath.safeDivide(10, 2)).to(equal(5))
            }

            it("returns zero when the divisor is zero") {
                expect(LayoutMath.safeDivide(10, 0)).to(equal(0))
            }

            it("returns zero when the divisor is negative") {
                expect(LayoutMath.safeDivide(10, -2)).to(equal(0))
            }

            it("returns zero when the divisor is NaN") {
                expect(LayoutMath.safeDivide(10, .nan)).to(equal(0))
            }

            it("returns zero when the divisor is infinite") {
                expect(LayoutMath.safeDivide(10, .infinity)).to(equal(0))
            }
        }

        describe("safeDivide(_:byCount:) Int") {
            it("divides by a positive count") {
                expect(LayoutMath.safeDivide(100, byCount: 4)).to(equal(25))
            }

            it("returns zero when count is zero") {
                expect(LayoutMath.safeDivide(100, byCount: 0)).to(equal(0))
            }

            it("returns zero when count is negative") {
                expect(LayoutMath.safeDivide(100, byCount: -3)).to(equal(0))
            }
        }

        describe("safeDivide(_:byCount:) UInt") {
            it("divides by a positive count") {
                expect(LayoutMath.safeDivide(100, byCount: UInt(4))).to(equal(25))
            }

            it("returns zero when count is zero") {
                expect(LayoutMath.safeDivide(100, byCount: UInt(0))).to(equal(0))
            }
        }

        describe("clamp(_:lower:upper:fallback:)") {
            it("returns the value when within range") {
                expect(LayoutMath.clamp(0.5, lower: 0, upper: 1, fallback: 0.5)).to(equal(0.5))
            }

            it("clamps to the lower bound") {
                expect(LayoutMath.clamp(-0.3, lower: 0, upper: 1, fallback: 0.5)).to(equal(0))
            }

            it("clamps to the upper bound") {
                expect(LayoutMath.clamp(2.0, lower: 0, upper: 1, fallback: 0.5)).to(equal(1))
            }

            it("returns the fallback when value is NaN") {
                expect(LayoutMath.clamp(.nan, lower: 0, upper: 1, fallback: 0.5)).to(equal(0.5))
            }

            it("returns the fallback when value is infinite") {
                expect(LayoutMath.clamp(.infinity, lower: 0, upper: 1, fallback: 0.5)).to(equal(0.5))
            }

            it("clamps the fallback itself if the fallback lies outside the range") {
                expect(LayoutMath.clamp(.nan, lower: 0, upper: 1, fallback: 2.0)).to(equal(1))
            }
        }
    }
}
