import AppKit

/// Hides apps through macOS 27's menu bar allow-list instead of stretching the divider,
/// so it works at any display width. The sections are read from the bar on every
/// change, because the user can ⌘-drag icons at any time.
@MainActor
final class NativeHiding {
    private var restriction: VisibilityRestriction?
    private var sections: MenuBarSections?
    private var hiddenOwners: Set<String> = []
    /// Bumped on every request, so a slower, older one never overrides a newer one.
    private var generation = 0

    static var isUsable: Bool { NativeVisibility.isAvailable && MenuBarInventory.isTrusted }

    func apply(_ state: RevealState, alwaysHiddenEnabled: Bool) {
        let everything = Set(MenuBarSection.allCases)
        let shown: Set<MenuBarSection> = switch state {
        case .collapsed: [.visible]
        case .expanded: alwaysHiddenEnabled ? [.visible, .hidden] : everything
        case .expandedAll: everything
        }
        guard shown != everything else { return lift() }
        generation += 1
        let generation = generation

        Task {
            let snapshot = await MenuBarInventory.snapshot()
            guard generation == self.generation else { return }
            Log.menuBar.debug("Own items \(snapshot.own.map { "\($0.identifier ?? "?") \($0.frame)" }, privacy: .public)")
            let ownBundleID = Bundle.main.bundleIdentifier
            guard let fresh = MenuBarSections(snapshot: snapshot, screens: NSScreen.screens.map(\.frame), ownerToSkip: ownBundleID) else {
                Log.menuBar.error("Can't find Barkeep's divider in the menu bar; showing everything")
                return lift()
            }
            let sections = self.sections?.updated(with: fresh, keeping: hiddenOwners) ?? fresh
            let allowed = sections.owners(in: shown)
            do {
                let restriction = try await NativeVisibility.restrict(allowing: [ownBundleID].compactMap(\.self) + allowed)
                guard generation == self.generation else { return restriction.lift() }
                // The new restriction is already on, so dropping the old one flashes nothing.
                self.restriction?.lift()
                self.restriction = restriction
                self.sections = sections
                hiddenOwners = Set(sections.owners(in: Set(MenuBarSection.allCases).subtracting(shown)))
                Log.menuBar.info("Hiding \(self.hiddenOwners.sorted(), privacy: .public)")
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
        hiddenOwners = []
    }
}
