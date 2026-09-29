# Barkeep

A tiny, free menu bar tidier for macOS. It does the one Bartender job that matters: keep a few icons visible and tuck the rest away until you want them.

No Screen Recording or Accessibility permission. No private APIs. About 500 lines of Swift.

## Use it

1. Launch Barkeep. A chevron and a thin divider (`│`) appear in the menu bar.
2. Hold `⌘` and drag icons:
   - **Right of the divider:** always visible (Wi-Fi, Control Center, Cursor, one or two more).
   - **Left of the divider:** hidden.
3. Show hidden icons by any of:
   - Clicking the chevron
   - Scrolling in the menu bar
   - Pressing `⌃⌥⌘B`
   - Hovering over the chevron (off by default)
4. They hide again 10 seconds after you stop using the menu bar. Barkeep waits while your pointer is in the menu bar or any menu is open.

Right-click the chevron for settings: the auto-hide delay, hover and scroll behavior, the always-hidden section, and Launch at Login.

**Always-hidden section (optional):** turning this on adds a dotted divider. Icons left of it stay hidden even after you click the chevron. `⌥`-click the chevron to show them.

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
xcodebuild -project Barkeep.xcodeproj -scheme Barkeep -destination 'platform=macOS' test
xcodebuild -project Barkeep.xcodeproj -scheme Barkeep -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Barkeep.app /Applications/
```

## How it works

Barkeep owns three status items:

```
[ always-hidden · ] [ hidden │ ] [ chevron ]   Wi-Fi  Control Center  Clock
```

To collapse, Barkeep widens the hidden divider to 45% of your narrowest display's width. That leaves no room for the icons to its left. On macOS 27 they move into the system's `«` overflow menu at the left end of the menu bar. To expand, Barkeep shrinks the divider back to 12 points. The always-hidden divider stays wide unless you `⌥`-click. Hidden Bar, Dozer, and early Ice all used the same trick with a fixed 10,000-point width.

The hotkey is a Carbon hot key, and scroll-to-show uses a global mouse monitor. Neither needs Accessibility permission. Each trackpad swipe toggles at most once, and momentum scrolling is ignored. Barkeep detects open menus by reading window levels, which doesn't need Screen Recording.

To see what Barkeep is doing:

```bash
log stream --level info --predicate 'subsystem == "com.samuelphifer.Barkeep"'
```

## What Bartender does, and what Barkeep keeps

Sources: the [Bartender 6](https://www.macbartender.com/Bartender6/) and [Bartender 7](https://www.macbartender.com/) pages, plus the [support page](https://www.macbartender.com/Bartender6/support/).

| Bartender feature | Barkeep | Notes |
| --- | --- | --- |
| Hide menu bar items, show on click | Yes | The core feature |
| Show on hover / scroll / swipe | Hover over the chevron, scroll anywhere in the menu bar | Bartender's hover works over any empty space in the menu bar. Detecting that needs screen reading. |
| Hotkey | `⌃⌥⌘B` | Fixed for now |
| Auto-rehide | 5 / 10 / 30 seconds or never | Counts down after you stop using the menu bar or an open menu |
| Always-hidden items | Optional dotted divider | |
| Launch at login | Yes | `SMAppService` |
| Bartender Bar (hidden items in a panel below the menu bar) | No | Needs Screen Recording to draw copies of other apps' icons, plus Accessibility to click them. On Tahoe it also moves your mouse, which the support page lists as a known problem. |
| Notch handling (auto-hide items stuck behind the notch) | No | Keep the always-visible set small, and the notch isn't an issue |
| Quick Search / Command Bar | No | Needs Accessibility |
| Presets, profiles, triggers (Wi-Fi, battery, time, location) | No | A lot of machinery for a simple bar |
| Groups, widgets, spacers, styling, tints, spacing | No | Cosmetic |
| Item indexing (keep order after reboot) | Built in | macOS remembers the order you `⌘`-drag into |

## macOS 27 notes

- **Half-width limit:** macOS 27 throws away any status item wider than half the display, instead of shrinking it. A 10,000-point divider just disappears and hides nothing. That's why Barkeep caps the divider at 45% of the narrowest attached display.
- **Large external displays:** because the cap follows your narrowest screen, a much wider display may still have room for some hidden icons. If a few show up there, move fewer icons left of the divider, or disconnect the smallest display.
- **Overflow instead of off screen:** hidden icons land in the system `«` overflow menu, so you can still reach them there without revealing.
- **Placeholder positions:** `MenuBarAgent` draws the menu bar, and apps' status item windows report overlapping placeholder frames, so Barkeep can't tell where its own items sit. If the chevron ever ends up hidden, press `⌃⌥⌘B` or scroll in the menu bar to bring everything back, then `⌘`-drag the divider to the left of the chevron.
