//
//  WindowTransitionCoordinatorTests.swift
//  AmethystTests
//
//  Regression coverage for the "move window to space left/right" bug where
//  focus was switching to the adjacent space but the window was being left
//  behind. The root cause was that `pushFocusedWindowToSpaceLeft/Right`
//  derived their `spaceIndex` from a per-screen-filtered list and passed it
//  to `WindowManager.executeTransition`, which interprets `spaceIndex` as
//  `macOSSpaceNumber - 1` (the global Mission Control user-space ordinal
//  that maps 1:1 to the `kCGSSymbolicHotKeySpaceN` hotkey Silica fires to
//  drag a window across spaces).
//
//  These tests pin down that contract by exercising the pure index helper
//  `WindowTransitionCoordinator.adjacentSpaceIndices(offset:screenUserSpaces:
//  currentSpace:allUserSpaces:)` directly, with no CGS/Spaces mocking
//  required.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

private func userSpace(_ id: CGSSpaceID) -> Space {
    return Space(id: id, type: CGSSpaceTypeUser, uuid: "user-\(id)")
}

private typealias Coordinator = WindowTransitionCoordinator<MockWindowTransitionTarget>

class WindowTransitionCoordinatorTests: QuickSpec {
    override func spec() {
        describe("adjacentSpaceIndices") {
            // MARK: - Happy path
            context("single screen, only user spaces") {
                let screenSpaces = [userSpace(1), userSpace(2), userSpace(3)]
                let allUserSpaces = screenSpaces

                it("moves left to the previous space and reports correct source") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: -1,
                        screenUserSpaces: screenSpaces,
                        currentSpace: screenSpaces[1],
                        allUserSpaces: allUserSpaces
                    )

                    expect(result?.target).to(equal(0))
                    expect(result?.source).to(equal(1))
                }

                it("moves right to the next space and reports correct source") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: +1,
                        screenUserSpaces: screenSpaces,
                        currentSpace: screenSpaces[1],
                        allUserSpaces: allUserSpaces
                    )

                    expect(result?.target).to(equal(2))
                    expect(result?.source).to(equal(1))
                }

                it("returns nil at the leftmost edge") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: -1,
                        screenUserSpaces: screenSpaces,
                        currentSpace: screenSpaces[0],
                        allUserSpaces: allUserSpaces
                    )

                    expect(result).to(beNil())
                }

                it("returns nil at the rightmost edge") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: +1,
                        screenUserSpaces: screenSpaces,
                        currentSpace: screenSpaces.last!,
                        allUserSpaces: allUserSpaces
                    )

                    expect(result).to(beNil())
                }
            }

            // MARK: - Regression: trailing/in-between fullscreen space
            //
            // Pre-fix the bounds check compared a `filteredSpaces` index
            // against the unfiltered `spaces.count`, which permitted "right"
            // off the end of the user-space list whenever non-user spaces
            // were present on the same display. After the fix this is a
            // no-op.
            context("user space with a trailing fullscreen space on the same screen") {
                let userSpaces = [userSpace(10), userSpace(11)]
                // Note: only user spaces are passed in - the helper itself
                // never sees the fullscreen space, but the old buggy code
                // compared against an unfiltered count one larger.

                it("refuses to move right past the last user space") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: +1,
                        screenUserSpaces: userSpaces,
                        currentSpace: userSpaces.last!,
                        allUserSpaces: userSpaces
                    )

                    expect(result).to(beNil())
                }
            }

            // MARK: - Regression: multi-monitor must not cross screens
            //
            // The old implementation flattened user spaces across all
            // displays via `spacesForAllScreens()` and used a position in
            // that flat list as both "is there an adjacent space?" and
            // "where to send the window". The result was that "left" from
            // the first user space of a secondary display silently moved
            // the window to a different monitor.
            context("multi-monitor at a screen boundary") {
                let screen1 = [userSpace(100), userSpace(101)]
                let screen2 = [userSpace(200), userSpace(201)]
                let allUserSpaces = screen1 + screen2

                it("does not move left off the leftmost space of the secondary screen") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: -1,
                        screenUserSpaces: screen2,
                        currentSpace: screen2[0],
                        allUserSpaces: allUserSpaces
                    )

                    expect(result).to(beNil())
                }

                it("does not move right off the rightmost space of the primary screen") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: +1,
                        screenUserSpaces: screen1,
                        currentSpace: screen1.last!,
                        allUserSpaces: allUserSpaces
                    )

                    expect(result).to(beNil())
                }

                it("produces a target/source matching the global Mission Control ordinal on the secondary screen") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: +1,
                        screenUserSpaces: screen2,
                        currentSpace: screen2[0],
                        allUserSpaces: allUserSpaces
                    )

                    // screen2[0] is the 3rd user space globally -> index 2
                    // screen2[1] is the 4th user space globally -> index 3
                    expect(result?.source).to(equal(2))
                    expect(result?.target).to(equal(3))
                }
            }

            // MARK: - Regression: target index must be a global ordinal
            //
            // The pre-fix implementation derived the target index from the
            // position inside the focused screen's filtered list, not from
            // its position inside the global user-space list. When earlier
            // displays contributed user spaces, the resulting hotkey number
            // pointed at the wrong space — macOS switched to that wrong
            // space, Silica's mouse-drag-with-hotkey trick missed, and the
            // window stayed behind. The assertion below would FAIL against
            // the buggy implementation because it returned a per-screen
            // index (0) instead of the global ordinal (2).
            context("target translation across displays") {
                let screen1 = [userSpace(1), userSpace(2)]
                let screen2 = [userSpace(3), userSpace(4), userSpace(5)]
                let allUserSpaces = screen1 + screen2

                it("translates a per-screen left move on screen 2 into a global ordinal") {
                    let result = Coordinator.adjacentSpaceIndices(
                        offset: -1,
                        screenUserSpaces: screen2,
                        currentSpace: screen2[1],
                        allUserSpaces: allUserSpaces
                    )

                    // screen2[0] is user space 3 globally -> index 2
                    // screen2[1] is user space 4 globally -> index 3
                    expect(result?.target).to(equal(2))
                    expect(result?.source).to(equal(3))
                }
            }

            // MARK: - Defensive: inconsistent inputs return nil rather than crash
            context("inconsistent inputs") {
                it("returns nil when current space is not on the screen") {
                    let screenSpaces = [userSpace(1), userSpace(2)]
                    let stranger = userSpace(99)

                    let result = Coordinator.adjacentSpaceIndices(
                        offset: -1,
                        screenUserSpaces: screenSpaces,
                        currentSpace: stranger,
                        allUserSpaces: screenSpaces + [stranger]
                    )

                    expect(result).to(beNil())
                }

                it("returns nil when the target screen space is missing from the global list") {
                    let screenSpaces = [userSpace(1), userSpace(2)]
                    // allUserSpaces is missing userSpace(1) — simulates a
                    // momentary CGS race where the global enumeration is
                    // out of sync with the per-screen one. The helper must
                    // bail out instead of producing a bogus index.
                    let allUserSpaces = [userSpace(2)]

                    let result = Coordinator.adjacentSpaceIndices(
                        offset: -1,
                        screenUserSpaces: screenSpaces,
                        currentSpace: screenSpaces[1],
                        allUserSpaces: allUserSpaces
                    )

                    expect(result).to(beNil())
                }
            }
        }
    }
}

// MARK: - Minimal mocks required only so the generic type
// `WindowTransitionCoordinator<MockWindowTransitionTarget>` resolves at
// compile-time. The pure helper under test never invokes any of these.

private final class MockWindowTransitionTarget: WindowTransitionTarget {
    typealias Application = MockApplication

    func executeTransition(_ transition: WindowTransition<TestWindow>) {}
    func isWindowFloating(_ window: TestWindow) -> Bool { return false }
    func currentLayout() -> Layout<TestWindow>? { return nil }
    func screen(at index: Int) -> TestScreen? { return nil }
    func activeWindows(on screen: TestScreen) -> [TestWindow] { return [] }
    func nextScreenIndexClockwise(from screen: TestScreen) -> Int { return 0 }
    func nextScreenIndexCounterClockwise(from screen: TestScreen) -> Int { return 0 }
    func lastMainWindowForCurrentSpace() -> TestWindow? { return nil }
}

private final class MockApplication: ApplicationType {
    typealias Window = TestWindow

    static func == (lhs: MockApplication, rhs: MockApplication) -> Bool { return lhs === rhs }

    init(runningApplication: NSRunningApplication) { fatalError("unused") }

    func title() -> String? { return nil }
    func windows() -> [TestWindow] { return [] }
    func pid() -> pid_t { return 0 }
    func defaultFloatForWindow(_ window: TestWindow) -> Reliable<DefaultFloat> { return .reliable(.notFloating) }
    func dropWindowsCache() {}
    func observe(notification: String, handler: @escaping SIAXNotificationHandler) -> AXError { return .success }
    func observe(notification: String, window: TestWindow, handler: @escaping SIAXNotificationHandler) -> AXError { return .success }
    func unobserve(notification: String) {}
    func unobserve(notification: String, window: TestWindow) {}
}
