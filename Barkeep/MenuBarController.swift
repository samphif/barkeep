import AppKit
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class MenuBarController: NSObject {
    private static let hotKeyDescription = "⌃⌥⌘B"
    private static let scrollThreshold: CGFloat = 3
    private static let scrollCooldown: TimeInterval = 0.6

    private let settings: Settings
    // Items created first sit furthest right, so this order yields: [always-hidden] [hidden] [chevron].
    private let toggleItem: NSStatusItem
    private let hiddenDivider: NSStatusItem
    private let alwaysHiddenDivider: NSStatusItem

    private var state: RevealState = .expanded
    private var revealedAt = Date()
    private var rehideTask: Task<Void, Never>?
    private var scrollMonitor: Any?
    private var lastScrollToggle = Date.distantPast
    private var hotKey: GlobalHotKey?

    init(settings: Settings) {
        self.settings = settings
        let statusBar = NSStatusBar.system
        toggleItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        hiddenDivider = statusBar.statusItem(withLength: BarLayout.dividerLength)
        alwaysHiddenDivider = statusBar.statusItem(withLength: BarLayout.dividerLength)
        super.init()

        configureItems()
        configureScrollMonitor()
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_B, modifiers: controlKey | optionKey | cmdKey) { [weak self] in
            self?.toggle()
        }
        apply(.expanded)

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.finishLaunch()
        }
    }

    // MARK: - Setup

    private func configureItems() {
        toggleItem.autosaveName = "BarkeepToggle"
        hiddenDivider.autosaveName = "BarkeepHiddenDivider"
        alwaysHiddenDivider.autosaveName = "BarkeepAlwaysHiddenDivider"

        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(toggleClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            ))
        }

        for (item, image) in [(hiddenDivider, StatusImages.divider), (alwaysHiddenDivider, StatusImages.alwaysHiddenDivider)] {
            item.button?.image = image
            item.button?.target = self
            item.button?.action = #selector(dividerClicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        alwaysHiddenDivider.isVisible = settings.alwaysHiddenEnabled
    }

    private func configureScrollMonitor() {
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let delta = event.scrollingDeltaY
            MainActor.assumeIsolated { self?.handleScroll(delta: delta) }
        }
    }

    private func finishLaunch() {
        if settings.hasShownWelcome {
            collapse(explainIfBlocked: false)
        } else {
            settings.hasShownWelcome = true
            showHelp()
        }
    }

    // MARK: - State

    private func toggle() {
        if state == .collapsed {
            reveal(.expanded)
        } else {
            collapse(explainIfBlocked: true)
        }
    }

    private func reveal(_ newState: RevealState) {
        apply(newState)
        revealedAt = Date()
        scheduleRehide()
    }

    private func collapse(explainIfBlocked: Bool) {
        guard layoutIsOrdered else {
            if explainIfBlocked { showLayoutHelp() }
            return
        }
        rehideTask?.cancel()
        apply(.collapsed)
    }

    private func apply(_ newState: RevealState) {
        state = newState
        let lengths = BarLayout.lengths(for: newState)
        hiddenDivider.length = lengths.hidden
        alwaysHiddenDivider.length = lengths.alwaysHidden
        toggleItem.button?.image = newState == .collapsed ? StatusImages.showHidden : StatusImages.hideItems
    }

    private func scheduleRehide() {
        rehideTask?.cancel()
        guard let delay = settings.rehideDelay else { return }
        rehideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            while !Task.isCancelled {
                guard let self else { return }
                if BarLayout.shouldRehide(
                    now: Date(),
                    revealedAt: self.revealedAt,
                    delay: delay,
                    mouseInMenuBar: self.isMouseInMenuBar
                ) {
                    self.collapse(explainIfBlocked: false)
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var layoutIsOrdered: Bool {
        guard let toggle = toggleItem.button?.window?.frame,
              let hidden = hiddenDivider.button?.window?.frame
        else { return false }
        let alwaysHidden = alwaysHiddenDivider.isVisible ? alwaysHiddenDivider.button?.window?.frame : nil
        return BarLayout.isOrdered(toggle: toggle, hidden: hidden, alwaysHidden: alwaysHidden)
    }

    private var isMouseInMenuBar: Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
            return BarLayout.isInMenuBar(point: mouse, screenFrame: screen.frame, menuBarHeight: menuBarHeight)
        }
    }

    // MARK: - Triggers

    @objc private func toggleClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu(from: sender)
        } else if event.modifierFlags.contains(.option), settings.alwaysHiddenEnabled {
            if state == .expandedAll {
                collapse(explainIfBlocked: true)
            } else {
                reveal(.expandedAll)
            }
        } else {
            toggle()
        }
    }

    @objc private func dividerClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu(from: sender)
        } else {
            toggle()
        }
    }

    // NSTrackingArea sends `mouseEntered:` / `mouseExited:` to its owner; a missing or
    // misnamed selector throws inside AppKit and tears down any open modal alert.
    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        guard settings.revealOnHover, state == .collapsed else { return }
        reveal(.expanded)
    }

    @objc(mouseExited:) func mouseExited(with event: NSEvent) {}

    private func handleScroll(delta: CGFloat) {
        guard settings.revealOnScroll,
              abs(delta) >= Self.scrollThreshold,
              isMouseInMenuBar,
              Date().timeIntervalSince(lastScrollToggle) >= Self.scrollCooldown
        else { return }
        lastScrollToggle = Date()
        toggle()
    }

    // MARK: - Menu

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(item(state == .collapsed ? "Show Hidden Items" : "Hide Items", #selector(menuToggle)))
        if settings.alwaysHiddenEnabled {
            menu.addItem(item("Show All Items", #selector(menuShowAll)))
        }
        menu.addItem(.separator())

        let rehideMenu = NSMenu()
        for delay in Settings.rehideDelayChoices {
            let choice = item("After \(Int(delay)) Seconds", #selector(menuSetRehideDelay(_:)), checked: settings.rehideDelay == delay)
            choice.representedObject = delay
            rehideMenu.addItem(choice)
        }
        let never = item("Never", #selector(menuSetRehideDelay(_:)), checked: settings.rehideDelay == nil)
        never.representedObject = 0.0
        rehideMenu.addItem(never)
        let rehideItem = NSMenuItem(title: "Auto-Hide", action: nil, keyEquivalent: "")
        rehideItem.submenu = rehideMenu
        menu.addItem(rehideItem)

        menu.addItem(item("Show on Hover Over Chevron", #selector(menuToggleHover), checked: settings.revealOnHover))
        menu.addItem(item("Show on Scroll in Menu Bar", #selector(menuToggleScroll), checked: settings.revealOnScroll))
        menu.addItem(item("Always-Hidden Section", #selector(menuToggleAlwaysHidden), checked: settings.alwaysHiddenEnabled))
        menu.addItem(item("Launch at Login", #selector(menuToggleLaunchAtLogin), checked: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())

        let hotKeyTitle = hotKey == nil
            ? "Hotkey \(Self.hotKeyDescription) unavailable (in use)"
            : "Toggle Hotkey: \(Self.hotKeyDescription)"
        menu.addItem(NSMenuItem(title: hotKeyTitle, action: nil, keyEquivalent: ""))
        menu.addItem(item("How to Use Barkeep…", #selector(menuShowHelp)))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Barkeep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    private func item(_ title: String, _ action: Selector, checked: Bool = false) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.state = checked ? .on : .off
        return menuItem
    }

    @objc private func menuToggle() { toggle() }

    @objc private func menuShowAll() { reveal(.expandedAll) }

    @objc private func menuSetRehideDelay(_ sender: NSMenuItem) {
        let delay = sender.representedObject as? TimeInterval ?? 0
        settings.rehideDelay = delay > 0 ? delay : nil
        if state != .collapsed {
            revealedAt = Date()
            scheduleRehide()
        }
    }

    @objc private func menuToggleHover() { settings.revealOnHover.toggle() }

    @objc private func menuToggleScroll() { settings.revealOnScroll.toggle() }

    @objc private func menuToggleAlwaysHidden() {
        settings.alwaysHiddenEnabled.toggle()
        alwaysHiddenDivider.isVisible = settings.alwaysHiddenEnabled
        apply(state == .expandedAll && !settings.alwaysHiddenEnabled ? .expanded : state)
    }

    @objc private func menuToggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            presentAlert(title: "Couldn’t change Launch at Login", message: error.localizedDescription)
        }
    }

    @objc private func menuShowHelp() {
        Task { self.showHelp() }
    }

    // MARK: - Alerts

    private func showHelp() {
        reveal(.expandedAll)
        presentAlert(
            title: "Welcome to Barkeep",
            message: """
            Barkeep added a chevron and a thin divider (│) to your menu bar.

            Hold ⌘ and drag menu bar icons:
            • Right of the divider: always visible (Wi-Fi, Control Center, Cursor…)
            • Left of the divider: hidden until you click the chevron

            Show hidden items by clicking the chevron, scrolling in the menu bar, or pressing \(Self.hotKeyDescription). They hide again automatically.

            Turn on the Always-Hidden Section to get a second, dotted divider. Icons left of it only appear when you ⌥-click the chevron.

            Right-click the chevron for settings.
            """
        )
    }

    private func showLayoutHelp() {
        reveal(.expandedAll)
        presentAlert(
            title: "Move the divider left of the chevron",
            message: "Hold ⌘ and drag Barkeep’s divider (│) so it sits to the left of the chevron, then click the chevron again. The dotted divider must be left of the solid one."
        )
    }

    private func presentAlert(title: String, message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.window.level = .floating
        alert.runModal()
    }
}
