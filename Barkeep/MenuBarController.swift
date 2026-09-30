import AppKit

/// Owns the reveal state. Every trigger — click, hotkey, hover, scroll, menu, timer —
/// funnels into `transition(to:)`, the only place the state changes.
@MainActor
final class MenuBarController {
    private let settings: Settings
    private let items = StatusItems()
    private var state: RevealState = .expanded
    private var scrollGesture = ScrollGesture()
    private var systemEvents: SystemEvents?
    private var hotKey: GlobalHotKey?
    private lazy var rehide = RehideTimer { [weak self] in self?.transition(to: .collapsed) }

    init(settings: Settings) {
        self.settings = settings
    }

    func start() {
        items.alwaysHiddenVisible = settings.alwaysHiddenEnabled
        items.onClick = { [weak self] click in self?.handle(click) }
        items.onHover = { [weak self] in self?.hovered() }
        systemEvents = SystemEvents(
            onScroll: { [weak self] sample in self?.scrolled(sample) },
            onScreensChanged: { [weak self] in self?.relayout() }
        )
        hotKey = GlobalHotKey(.toggle) { [weak self] in self?.toggle(showAll: false) }
        if hotKey == nil {
            Log.menuBar.error("Hotkey \(HotKeyCombo.toggle.label, privacy: .public) is already registered by another app")
        }
        LaunchAtLogin.enableOnFirstInstalledLaunch(settings: settings)

        if settings.hasShownWelcome {
            transition(to: .collapsed)
        } else {
            settings.hasShownWelcome = true
            showHelp()
        }
    }

    // MARK: - State

    private func transition(to target: RevealState) {
        state = target.normalized(alwaysHiddenEnabled: settings.alwaysHiddenEnabled)
        relayout()
        if state == .collapsed {
            rehide.cancel()
        } else {
            rehide.restart(after: settings.rehideDelay)
        }
        Log.menuBar.info("State \(String(describing: self.state), privacy: .public)")
    }

    private func toggle(showAll: Bool) {
        transition(to: state.toggled(showAll: showAll && settings.alwaysHiddenEnabled))
    }

    private func relayout() {
        items.show(state)
    }

    // MARK: - Triggers

    private func handle(_ click: StatusClick) {
        switch click {
        case .toggle: toggle(showAll: false)
        case .showAll: toggle(showAll: true)
        case .menu(let button): showMenu(from: button)
        }
    }

    private func hovered() {
        guard settings.revealOnHover, state == .collapsed else { return }
        transition(to: .expanded)
    }

    private func scrolled(_ sample: ScrollSample) {
        guard settings.revealOnScroll, MenuBarActivity.isPointerInMenuBar else { return }
        if scrollGesture.shouldToggle(deltaY: sample.deltaY, phase: sample.phase, momentumPhase: sample.momentumPhase, now: .now) {
            toggle(showAll: false)
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        SettingsMenu(
            state: state,
            settings: settings,
            hotKey: .toggle,
            hotKeyAvailable: hotKey != nil,
            actions: SettingsMenu.Actions(
                toggle: { [weak self] in self?.toggle(showAll: false) },
                showAll: { [weak self] in self?.transition(to: .expandedAll) },
                showHelp: { [weak self] in self?.showHelp() },
                settingsChanged: { [weak self] in self?.settingsChanged() }
            )
        ).popUp(from: button)
    }

    private func settingsChanged() {
        items.alwaysHiddenVisible = settings.alwaysHiddenEnabled
        transition(to: state)
    }

    /// The alert runs modally, so it's deferred until any open menu has finished tracking.
    private func showHelp() {
        transition(to: .expandedAll)
        Task { Alerts.showWelcome(hotKeyLabel: HotKeyCombo.toggle.label) }
    }
}
