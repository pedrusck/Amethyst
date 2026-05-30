//
//  LayoutMath.swift
//  Amethyst
//
//  Math helpers for paned layouts that need to be robust against
//  degenerate inputs (zero counts, ratios at 0 or 1, non-finite
//  values from corrupted state). Routing every paned-layout divisor
//  through these helpers prevents NaN/inf propagation into CGRect
//  frames, which produced undefined window placement.
//

import CoreGraphics

enum LayoutMath {
    /// Returns `numerator / denominator` when `denominator` is strictly
    /// positive and finite; otherwise `0`. Intended for layout slot
    /// calculations where a zero or non-finite divisor would propagate
    /// NaN/inf into CGRect frames.
    @inline(__always)
    static func safeDivide(_ numerator: CGFloat, _ denominator: CGFloat) -> CGFloat {
        guard denominator.isFinite, denominator > 0 else { return 0 }
        return numerator / denominator
    }

    /// Same as `safeDivide(_:_:)`, accepting an `Int` count. Counts <= 0
    /// produce `0` instead of dividing by zero (or by a negative).
    @inline(__always)
    static func safeDivide(_ numerator: CGFloat, byCount count: Int) -> CGFloat {
        return safeDivide(numerator, CGFloat(max(count, 0)))
    }

    /// Same as `safeDivide(_:_:)`, accepting a `UInt` count.
    @inline(__always)
    static func safeDivide(_ numerator: CGFloat, byCount count: UInt) -> CGFloat {
        return safeDivide(numerator, CGFloat(count))
    }

    /// Clamps `value` to the closed interval `[lower, upper]`. Non-finite
    /// values are coerced to `fallback` before clamping; useful for sanitizing
    /// user-supplied ratios that may arrive as NaN/inf from corrupted state.
    @inline(__always)
    static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat, fallback: CGFloat) -> CGFloat {
        let sanitized = value.isFinite ? value : fallback
        return min(max(sanitized, lower), upper)
    }
}
