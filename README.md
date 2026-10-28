# Barkeep

A tiny, native macOS menu bar manager written in ~1,300 lines of Swift. It hides the menu bar icons you don't need staring at you all day and brings them back with a click, a scroll in the menu bar, or a hotkey (`⌃⌥⌘B`).

Built to replace Bartender with code you actually own—zero external dependencies, **zero Screen Recording permissions**, and no mouse-cursor jumping on newer macOS releases.

## Why Barkeep?

- **Zero Screen Recording permission:** Barkeep never captures pixels of your screen or redraws fake copies of your status items in a secondary floating bar. Every icon you click is the real status item in the real macOS menu bar.
- **Native hiding + Divider fallback:**
  - **With Accessibility access (macOS Tahoe / 27+):** Barkeep reads where each icon sits relative to its dividers and uses macOS's native menu bar visibility allow-list (`MenuBarClientCore`) to hide icons left of the divider cleanly across displays of any width—including optional hiding of macOS system items (like Battery or Wi-Fi) when dragged left of the divider.
  - **Without Accessibility access (Divider Mode):** Barkeep expands its divider to push icons to the left off the bar (capped at 45% of the narrowest display so macOS 27 never discards the status item).
- **Two sections (Hidden & Always-Hidden):**
  - Place everyday clutter left of the thin solid divider (`│`)—revealed on click, scroll, hover, or `⌃⌥⌘B`.
  - Enable the **Always-Hidden Section** for a second dotted divider (`┊`). Icons left of the dotted divider stay tucked away until you `⌥`-click the bow tie.
- **Smart auto-rehide:** Counts down (5s / 10s / 30s / Never) only after your pointer leaves the menu bar *and* all pop-up menus close, so a menu never collapses out from under your cursor.
- **Tiny & hackable:** ~1,300 lines of pure Swift (`AppKit`, `Carbon.HIToolbox`, `ServiceManagement`, `ApplicationServices`). Want to tweak a behavior when macOS updates? Change a few lines and rebuild in seconds.

## Quick Start

### Build & Install

Requires macOS 14.0+ and Xcode 16+.

```bash
./build.sh --install
open /Applications/Barkeep.app
```

Or build and test directly with `xcodebuild`:

```bash
xcodebuild -project Barkeep.xcodeproj -scheme Barkeep test
xcodebuild -project Barkeep.xcodeproj -scheme Barkeep -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/Barkeep.app /Applications/
```

### How to Use

1. **Launch Barkeep.** A bow tie icon and a thin divider (`│`) appear in your menu bar.
2. **Hold `⌘` and drag menu bar icons:**
   - **Right of the divider (`│`):** Always visible.
   - **Left of the divider (`│`):** Hidden when collapsed.
   - **Left of the dotted divider (`┊`, when Always-Hidden is enabled):** Hidden until you `⌥`-click the bow tie.
3. **Reveal hidden icons anytime:**
   - **Click** the bow tie (`⌥`-click to include the Always-Hidden section)
   - **Scroll** (two-finger swipe or mouse wheel) anywhere in the menu bar
   - **Press `⌃⌥⌘B`** from anywhere (registered via Carbon hot keys—no Accessibility permission required)
   - **Hover** over the bow tie (optional toggle in settings)
4. **Right-click the bow tie** for settings: Auto-Hide delay (`5s`, `10s`, `30s`, `Never`), Show on Hover, Show on Scroll, Always-Hidden Section, Divider Mode (stretched divider / system-item hiding fallback), and Launch at Login.

## How It Works

Barkeep owns three `NSStatusItem`s created in right-to-left order:

```text
[ always-hidden ┊ ]  [ hidden │ ]  [ bow tie ]   Wi-Fi  Control Center  Clock
```

- **Native Hiding (macOS 27+ with Accessibility):** Barkeep inspects status item frames via Accessibility (`MenuBarInventory`), partitions owners relative to the `│` and `┊` dividers (`MenuBarSections`), and applies a menu bar allow-list via `MenuBarClientCore` (`NativeVisibility`). While collapsed, the dividers shrink to `0pt` so only the bow tie and your visible icons remain. If Barkeep quits, macOS automatically lifts the restriction.
- **Stretched Divider Mode (Zero Permissions):** To collapse, Barkeep widens the active divider to `45%` of the narrowest connected screen width (`BarLayout.collapsedLength`), displacing icons to its left. To expand, it shrinks the divider back to `12pt`.
- **Trackpad & Wheel Scroll Debouncing:** `ScrollGesture` turns a continuous trackpad gesture into a single toggle and ignores momentum events, so a quick flick in the menu bar never double-toggles.
- **Menu Activity Detection:** `MenuBarActivity` checks mouse coordinates and `CGWindowListCopyWindowInfo` for pop-up menu window levels (`kCGPopUpMenuWindowLevelKey`)—requiring zero Screen Recording permissions.

To stream live logs while debugging:

```bash
log stream --level info --predicate 'subsystem == "com.samuelphifer.Barkeep"'
```

## Bartender vs. Barkeep

| Feature | Bartender 6 | Barkeep |
| :--- | :--- | :--- |
| **Price & Ownership** | Paid license ($20+ per major version), closed source | **Free, MIT Open Source, ~1,300 lines of Swift** |
| **Screen Recording Permission** | Required for Bartender Bar / hover / presets | **Never required** |
| **Click / Scroll / Hover / Hotkey (`⌃⌥⌘B`)** | Yes | **Yes** |
| **Hidden + Always-Hidden (`⌥`-click) sections** | Yes | **Yes (solid `│` + dotted `┊` dividers)** |
| **Auto-rehide that waits for open menus** | Yes | **Yes (5s / 10s / 30s / Never)** |
| **Mouse cursor hijacking on macOS Tahoe / 27** | Known issue when interacting with Bartender Bar | **None — icons stay native in the system menu bar** |

## License

Released under the [MIT License](LICENSE).
