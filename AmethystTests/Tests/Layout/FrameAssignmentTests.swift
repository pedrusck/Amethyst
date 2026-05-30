//
//  FrameAssignmentTests.swift
//  AmethystTests
//
//  Regression tests for FrameAssignment.perform(withWindow:) ensuring it
//  applies the final frame on background and main threads without
//  deadlocking, and that the focused-window "peek" branch clamps the
//  window origin within the screen frame.
//

@testable import Amethyst
import Nimble
import Quick
import Silica
import XCTest

class FrameAssignmentTests: QuickSpec {
    override func spec() {
        describe("FrameAssignment.perform") {
            let screenFrame = CGRect(x: 0, y: 0, width: 2000, height: 1000)
            let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)

            func makeAssignment(
                frame: CGRect,
                window: LayoutWindow<TestWindow>,
                screenFrame: CGRect = screenFrame
            ) -> FrameAssignment<TestWindow> {
                return FrameAssignment<TestWindow>(
                    frame: frame,
                    window: window,
                    screenFrame: screenFrame,
                    resizeRules: resizeRules,
                    disableWindowMargins: true
                )
            }

            it("applies the final frame when called from a background queue") {
                let window = TestWindow(element: nil)!
                let layoutWindow = LayoutWindow<TestWindow>(id: window.id(), frame: window.frame(), isFocused: false)
                let targetFrame = CGRect(x: 100, y: 200, width: 400, height: 300)
                let assignment = makeAssignment(frame: targetFrame, window: layoutWindow)

                let queue = DispatchQueue(label: "FrameAssignmentTests.bg", qos: .utility)
                let expectation = self.expectation(description: "perform from bg")
                queue.async {
                    assignment.perform(withWindow: window)
                    expectation.fulfill()
                }
                self.wait(for: [expectation], timeout: 2.0)

                expect(window.frame()).to(equal(targetFrame))
            }

            it("applies the final frame when called from the main thread without deadlocking") {
                let window = TestWindow(element: nil)!
                let layoutWindow = LayoutWindow<TestWindow>(id: window.id(), frame: window.frame(), isFocused: false)
                let targetFrame = CGRect(x: 50, y: 75, width: 600, height: 400)
                let assignment = makeAssignment(frame: targetFrame, window: layoutWindow)

                // If perform() incorrectly issues main.sync from the main thread,
                // this line deadlocks and the test times out.
                assignment.perform(withWindow: window)

                expect(window.frame()).to(equal(targetFrame))
            }

            it("clamps the origin within screenFrame for a focused window") {
                let window = TestWindow(element: nil)!
                window.isFocusedValue = true
                // Pre-seed the window with a frame that places the focused branch's
                // peek read at an out-of-bounds origin so clamping is observable.
                window.setFrame(CGRect(x: 1800, y: 800, width: 400, height: 400),
                                withThreshold: CGSize(width: 1, height: 1))
                let layoutWindow = LayoutWindow<TestWindow>(id: window.id(), frame: window.frame(), isFocused: true)

                // Requested frame origin is in-bounds, but peek logic preserves the
                // window's current origin first, then clamps to the screen bounds.
                let targetFrame = CGRect(x: 200, y: 200, width: 400, height: 400)
                let assignment = makeAssignment(frame: targetFrame, window: layoutWindow)

                let queue = DispatchQueue(label: "FrameAssignmentTests.focused.bg", qos: .utility)
                let expectation = self.expectation(description: "perform focused")
                queue.async {
                    assignment.perform(withWindow: window)
                    expectation.fulfill()
                }
                self.wait(for: [expectation], timeout: 2.0)

                let resulting = window.frame()
                expect(resulting.minX).to(beGreaterThanOrEqualTo(screenFrame.minX))
                expect(resulting.minY).to(beGreaterThanOrEqualTo(screenFrame.minY))
                expect(resulting.maxX).to(beLessThanOrEqualTo(screenFrame.maxX))
                expect(resulting.maxY).to(beLessThanOrEqualTo(screenFrame.maxY))
            }

            it("skips the peek branch for a non-focused window and applies the requested frame as-is") {
                let window = TestWindow(element: nil)!
                window.isFocusedValue = false
                // Seed an arbitrary current frame; non-focused branch should ignore it.
                window.setFrame(CGRect(x: 1500, y: 700, width: 300, height: 300),
                                withThreshold: CGSize(width: 1, height: 1))
                let layoutWindow = LayoutWindow<TestWindow>(id: window.id(), frame: window.frame(), isFocused: false)

                // Request a frame whose origin is outside screenFrame; non-focused
                // branch should NOT clamp and should pass it through unchanged.
                let targetFrame = CGRect(x: -100, y: -50, width: 400, height: 300)
                let assignment = makeAssignment(frame: targetFrame, window: layoutWindow)

                let queue = DispatchQueue(label: "FrameAssignmentTests.nonfocused.bg", qos: .utility)
                let expectation = self.expectation(description: "perform non-focused")
                queue.async {
                    assignment.perform(withWindow: window)
                    expectation.fulfill()
                }
                self.wait(for: [expectation], timeout: 2.0)

                expect(window.frame()).to(equal(targetFrame))
            }
        }
    }
}
