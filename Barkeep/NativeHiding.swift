import AppKit

/// Hides apps through macOS 27's menu bar allow-list instead of stretching the divider,
/// so it works at any display width. The sections are read from the bar on every
/// change, because the user can ⌘-drag icons at any time.
@MainActor
final class NativeHiding {
    private var restriction: VisibilityRestriction?
    private var shown: Set<MenuBarSection>?
    private var sections: MenuBarSections?
    private var hiddenOwners: Set<String> = []
    private var hiddenSystemItems: Set<SystemItemID> = []
    /// Bumped on every request, so a slower, older one never overrides a newer one.
    private var generation = 0

    static var isUsable: Bool { NativeVisibility.isAvailable && MenuBarInventory.isTrusted }

    /// Only the visible section is showing, so the dividers have nothing to separate.
    var isCollapsed: Bool { restriction != nil && shown == [.visible] }

    /// `onApplied` runs once the new restriction is in place.
    func apply(_ state: RevealState, alwaysHiddenEnabled: Bool, onApplied: @escaping @MainActor () -> Void) {
        let everything = Set(MenuBarSection.allCases)
        let shown: Set<MenuBarSection> = switch state {
        case .collapsed: [.visible]
        case .expanded: alwaysHiddenEnabled ? [.visible, .hidden] : everything
        case .expandedAll: everything
        }
        guard shown != everything else { return lift() }
        generation += 1
        let generation = generation
        // Display changes don't affect native hiding, and re-reading now would find
        // the dividers hidden.
        guard restriction == nil || shown != self.shown else { return }

        Task {
            let snapshot = await MenuBarInventory.snapshot()
            guard generation == self.generation else { return }
            Log.menuBar.debug("Own items \(snapshot.own.map { "\($0.identifier ?? "?") \($0.frame)" }, privacy: .public)")
            let ownBundleID = Bundle.main.bundleIdentifier
            let fresh = MenuBarSections(snapshot: snapshot, screens: NSScreen.screens.map(\.frame), ownerToSkip: ownBundleID)
            // A divider that's just reappearing may not be laid out yet; the last read stands in.
            guard let sections = fresh.map({
                self.sections?.updated(with: $0, keeping: hiddenOwners, keepingSystemItems: hiddenSystemItems) ?? $0
            }) ?? self.sections else {
                Log.menuBar.error("Can't find Barkeep's divider in the menu bar; showing everything")
                return lift()
            }
            let allowed = sections.owners(in: shown)
            let systemItems = sections.allowedSystemItems(shown: shown)
            do {
                let restriction = try await NativeVisibility.restrict(
                    allowing: [ownBundleID].compactMap(\.self) + allowed,
                    systemItems: systemItems
                )
                guard generation == self.generation else { return restriction.lift() }
                // The new restriction is already on, so dropping the old one flashes nothing.
                self.restriction?.lift()
                self.restriction = restriction
                self.shown = shown
                self.sections = sections
                let concealed = everything.subtracting(shown)
                hiddenOwners = Set(sections.owners(in: concealed))
                hiddenSystemItems = Set(sections.bySystemItem.compactMap { id, section in concealed.contains(section) ? id : nil })
                Log.menuBar.info("Hiding \(self.hiddenOwners.sorted(), privacy: .public)")
                onApplied()
            } catch {
                Log.menuBar.error("Native hiding failed: \(error.localizedDescription, privacy: .public)")
                if generation == self.generation { lift() }
            }
        }
    }

    func lift() {
        generation += 1
        restriction?.lift()
        restriction = nil
        shown = nil
        hiddenOwners = []
        hiddenSystemItems = []
    }
}
