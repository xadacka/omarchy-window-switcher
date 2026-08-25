# omarchy-window-switcher

A searchable window switcher for [Omarchy](https://omarchy.org/)/Hyprland — an
Alt-Tab alternative that lets you type to filter open windows by title or app,
instead of cycling through them one at a time.

It reuses Omarchy's own menu UI (the same overlay used for the system menu,
theme picker, etc.) via its dmenu-style IPC, so it looks and feels native —
no extra launcher (rofi/wofi/fuzzel/walker) required.

## Why

Hyprland/Omarchy already bind `ALT + TAB` to "focus next window", which
cycles one window at a time — fine with two or three windows open, tedious
with a dozen. This gives you a `SUPER + GRAVE` (backtick) binding that opens
a filterable list instead: type a few letters of the title or app name,
press Enter, done.

## Requirements

- Omarchy (tested on the Quickshell-based `omarchy-shell` release, Hyprland 0.56.2)
- `jq`

## Install

```bash
git clone <this-repo> ~/Projects/omarchy-window-switcher
cd ~/Projects/omarchy-window-switcher
./install.sh
```

This:
1. Copies `bin/omarchy-window-switcher` to `~/.local/bin/`
2. Appends a `SUPER + GRAVE` keybinding to `~/.config/hypr/bindings.lua`
   (skipped if that key is already bound to something else, or if the
   binding is already there)
3. Reloads Hyprland if it's currently running

Override the key with an env var if you'd rather bind something else:

```bash
OMARCHY_WINDOW_SWITCHER_KEY="SUPER + SHIFT + TAB" ./install.sh
```

### Manual install

Copy `bin/omarchy-window-switcher` somewhere on your `PATH` and add a binding
yourself in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + GRAVE", "Window switcher", "omarchy-window-switcher")
```

## Usage

Press the bound key, start typing to filter, use ↑/↓ to move, Enter to
focus the selected window, Esc to cancel.

## How it works

`hyprctl clients -j` lists open windows (address, title, class, workspace,
recency). The script builds that into Omarchy's generic dmenu payload and
opens it with:

```bash
omarchy-shell shell summon omarchy.menu '{"mode":"select", ...}'
```

then blocks on the selection/done temp files the menu writes back to, the
same round-trip Omarchy's own image picker uses. Once a window is picked,
it's focused with:

```bash
hyprctl dispatch 'hl.dsp.focus({ window = "address:0x..." })'
```

(Hyprland 0.56's Lua dispatch API — the classic `hyprctl dispatch
focuswindow address:0x...` string syntax no longer works on this version.)

The currently-focused window is left out of the list, since switching to it
would be a no-op.

## Caveats

- Requires the Quickshell-based Omarchy shell (the `omarchy.menu` IPC
  target) — not compatible with older wofi/walker-based Omarchy releases.
- Two windows with an identical title, app, and workspace are
  indistinguishable in the list; picking either one focuses whichever of
  them was enumerated first.
