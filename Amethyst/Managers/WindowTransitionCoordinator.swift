//
//  WindowTransitionCoordinator.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/24/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

enum WindowTransition<Window: WindowType> {
    typealias Screen = Window.Screen
    case switchWindows(_ window1: Window, _ window2: Window)
    case moveWindowToScreen(_ window: Window, screen: Screen)
    case moveWindowToSpaceAtIndex(_ window: Window, spaceIndex: Int, sourceSpaceIndex: Int)
    case resetFocus
}

protocol WindowTransitionTarget: AnyObject {
    associatedtype Application: ApplicationType
    typealias Window = Application.Window
    typealias Screen = Window.Screen

    func executeTransition(_ transition: WindowTransition<Window>)

    func isWindowFloating(_ window: Window) -> Bool
    func currentLayout() -> Layout<Application.Window>?
    func screen(at index: Int) -> Screen?
    func activeWindows(on screen: Screen) -> [Window]
    func nextScreenIndexClockwise(from screen: Screen) -> Int
    func nextScreenIndexCounterClockwise(from screen: Screen) -> Int
    func lastMainWindowForCurrentSpace() -> Window?
}

class WindowTransitionCoordinator<Target: WindowTransitionTarget> {
    typealias Window = Target.Window
    typealias Screen = Window.Screen

    weak var target: Target?

    init() {}

    func swapFocusedWindowToMain() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false, let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.activeWindows(on: screen), let focusedIndex = windows.firstIndex(of: focusedWindow) else {
            return
        }

        if windows.count <= 1 {
            return
        }

        if focusedIndex == 0 {
            guard let lastMainWindow = target?.lastMainWindowForCurrentSpace() else {
                return
            }
            target?.executeTransition(.switchWindows(lastMainWindow, focusedWindow))
            return
        }

        if focusedIndex != 0 {
            // Swap focused window with main window if other window is focused
            target?.executeTransition(.switchWindows(focusedWindow, windows[0]))
        }
    }

    func swapFocusedWindowCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.activeWindows(on: screen), let focusedWindowIndex = windows.firstIndex(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)]

        target?.executeTransition(.switchWindows(focusedWindow, windowToSwapWith))
    }

    func swapFocusedWindowClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.activeWindows(on: screen), let focusedWindowIndex = windows.firstIndex(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count]

        target?.executeTransition(.switchWindows(focusedWindow, windowToSwapWith))
    }

    func throwToScreenAtIndex(_ screenIndex: Int) {
        guard let screen = target?.screen(at: screenIndex), let focusedWindow = Window.currentlyFocused() else {
            return
        }

        // If the window is already on the screen do nothing.
        guard let focusedScreen = focusedWindow.screen(), focusedScreen.screenID() != screen.screenID() else {
            return
        }

        target?.executeTransition(.moveWindowToScreen(focusedWindow, screen: screen))
    }

    func swapFocusedWindowScreenClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let nextScreenIndex = target?.nextScreenIndexClockwise(from: screen), let nextScreen = target?.screen(at: nextScreenIndex) else {
            return
        }

        target?.executeTransition(.moveWindowToScreen(focusedWindow, screen: nextScreen))
    }

    func swapFocusedWindowScreenCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), target?.isWindowFloating(focusedWindow) == false else {
            target?.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let nextScreenIndex = target?.nextScreenIndexCounterClockwise(from: screen), let nextScreen = target?.screen(at: nextScreenIndex) else {
            return
        }

        target?.executeTransition(.moveWindowToScreen(focusedWindow, screen: nextScreen))
    }

    func pushFocusedWindowToSpace(_ space: Int) {
        guard let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(), let spaces = CGSpacesInfo<Window>.spacesForAllScreens() else {
            return
        }

        guard let index = spaces.firstIndex(of: currentFocusedSpace), index < spaces.count else {
            return
        }

        pushFocusedWindowToSpace(space, sourceSpace: index)
    }

    func pushFocusedWindowToSpace(_ space: Int, sourceSpace: Int) {
        guard let focusedWindow = Window.currentlyFocused(), focusedWindow.screen() != nil else {
            return
        }

        target?.executeTransition(.moveWindowToSpaceAtIndex(focusedWindow, spaceIndex: space, sourceSpaceIndex: sourceSpace))
    }

    func pushFocusedWindowToSpaceLeft() {
        guard let indices = adjacentSpaceIndices(offset: -1) else {
            return
        }
        pushFocusedWindowToSpace(indices.target, sourceSpace: indices.source)
    }

    func pushFocusedWindowToSpaceRight() {
        guard let indices = adjacentSpaceIndices(offset: +1) else {
            return
        }
        pushFocusedWindowToSpace(indices.target, sourceSpace: indices.source)
    }

    /// Returns the (target, source) **global** user-space indices for the
    /// space adjacent to the currently focused space on the focused window's
    /// screen. `offset` must be -1 (left) or +1 (right).
    ///
    /// The returned indices satisfy the contract required by
    /// `WindowManager.executeTransition`: index == macOS space number - 1
    /// (i.e. the offset into `spacesForAllScreens(includeOnlyUserSpaces: true)`,
    /// which maps 1:1 to the `kCGSSymbolicHotKeySpace1 + index` hotkey that
    /// Silica fires to drag a window to another space).
    private func adjacentSpaceIndices(offset: Int) -> (target: Int, source: Int)? {
        guard
            let focusedWindow = Window.currentlyFocused(),
            let screen = focusedWindow.screen(),
            let screenSpaces = CGSpacesInfo<Window>.spacesForScreen(screen, includeOnlyUserSpaces: true),
            let currentSpace = CGSpacesInfo<Window>.currentSpaceForScreen(screen),
            let allUserSpaces = CGSpacesInfo<Window>.spacesForAllScreens(includeOnlyUserSpaces: true)
        else {
            return nil
        }

        return Self.adjacentSpaceIndices(
            offset: offset,
            screenUserSpaces: screenSpaces,
            currentSpace: currentSpace,
            allUserSpaces: allUserSpaces
        )
    }

    /// Pure, side-effect-free index math for `adjacentSpaceIndices(offset:)`,
    /// exposed at internal visibility so it can be unit-tested without mocking
    /// the macOS Core Graphics / Spaces APIs.
    ///
    /// - Parameters:
    ///   - offset: -1 for "left", +1 for "right".
    ///   - screenUserSpaces: The user spaces on the focused window's screen,
    ///     in display order.
    ///   - currentSpace: The currently focused space (must be a member of
    ///     `screenUserSpaces`).
    ///   - allUserSpaces: All user spaces across every screen, in the order
    ///     macOS exposes them — this order is what `kCGSSymbolicHotKeySpaceN`
    ///     selects (i.e. `index == macOSSpaceNumber - 1`).
    /// - Returns: `(target, source)` global user-space indices, or `nil` if
    ///   the move would leave the focused screen, the current space cannot be
    ///   located, or any of the inputs are inconsistent.
    static func adjacentSpaceIndices(
        offset: Int,
        screenUserSpaces: [Space],
        currentSpace: Space,
        allUserSpaces: [Space]
    ) -> (target: Int, source: Int)? {
        guard let localIndex = screenUserSpaces.firstIndex(of: currentSpace) else {
            return nil
        }

        let targetLocalIndex = localIndex + offset
        guard targetLocalIndex >= 0, targetLocalIndex < screenUserSpaces.count else {
            return nil
        }

        guard
            let sourceGlobalIndex = allUserSpaces.firstIndex(of: currentSpace),
            let targetGlobalIndex = allUserSpaces.firstIndex(of: screenUserSpaces[targetLocalIndex])
        else {
            return nil
        }

        return (target: targetGlobalIndex, source: sourceGlobalIndex)
    }
}
