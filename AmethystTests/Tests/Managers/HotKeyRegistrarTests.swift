//
//  HotKeyRegistrarTests.swift
//  AmethystTests
//
//  Created to cover hot-key handler deduplication in HotKeyManager.
//

@testable import Amethyst
import KeyboardShortcuts
import Nimble
import Quick
import Silica

class HotKeyRegistrarTests: QuickSpec {
    override func spec() {
        describe("HotKeyManager dedup") {
            it("replaces a previously installed handler for the same name") {
                let manager = HotKeyManager<SIApplication>(userConfiguration: UserConfiguration(storage: TestConfigurationStorage()))
                let name = KeyboardShortcuts.Name("amethyst.test.dedup.replace")

                var firstCount = 0
                var secondCount = 0

                manager.setShortcutHandler({ firstCount += 1 }, for: name)
                manager.setShortcutHandler({ secondCount += 1 }, for: name)

                manager.dispatchShortcut(for: name)
                manager.dispatchShortcut(for: name)

                expect(firstCount).to(equal(0))
                expect(secondCount).to(equal(2))
                expect(manager.hasShortcutHandler(for: name)).to(beTrue())
            }

            it("dispatches independently per shortcut name") {
                let manager = HotKeyManager<SIApplication>(userConfiguration: UserConfiguration(storage: TestConfigurationStorage()))
                let nameA = KeyboardShortcuts.Name("amethyst.test.dedup.a")
                let nameB = KeyboardShortcuts.Name("amethyst.test.dedup.b")

                var aCount = 0
                var bCount = 0

                manager.setShortcutHandler({ aCount += 1 }, for: nameA)
                manager.setShortcutHandler({ bCount += 1 }, for: nameB)

                manager.dispatchShortcut(for: nameA)
                manager.dispatchShortcut(for: nameA)
                manager.dispatchShortcut(for: nameB)

                expect(aCount).to(equal(2))
                expect(bCount).to(equal(1))
            }

            it("is a no-op to dispatch a name with no handler") {
                let manager = HotKeyManager<SIApplication>(userConfiguration: UserConfiguration(storage: TestConfigurationStorage()))
                let name = KeyboardShortcuts.Name("amethyst.test.dedup.absent")

                expect(manager.hasShortcutHandler(for: name)).to(beFalse())
                manager.dispatchShortcut(for: name)
                expect(manager.hasShortcutHandler(for: name)).to(beFalse())
            }
        }
    }
}
