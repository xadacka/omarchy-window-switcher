import QtQuick
import Quickshell
import Quickshell.Io

// Bootstraps the Hyprland keybinding this plugin needs. Omarchy shell plugins
// only run inside the Quickshell process — they have no way to register a
// Hyprland keybind directly — so this idempotently appends one line to
// ~/.config/hypr/bindings.lua the first time the plugin loads, then leaves it
// alone. Safe to run on every shell startup: it's a no-op once the line is
// there.
Item {
  id: root

  // Injected by omarchy-shell (the first-party service loader).
  property var shell: null

  // Matches manifest.json's id, per the plugin authoring convention.
  readonly property string moduleName: "io.github.xadacka.window-switcher"

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/" + moduleName
  readonly property string scriptPath: pluginDir + "/bin/omarchy-window-switcher"
  readonly property string bindingsFile: home + "/.config/hypr/bindings.lua"
  readonly property string bindKey: "SUPER + GRAVE"
  readonly property string marker: "omarchy-window-switcher"

  Component.onCompleted: bootstrapProcess.running = true

  // Writes via the standard atomic-replace pattern (build a temp file, then
  // `mv` it over the target) rather than opening ~/.config/hypr/bindings.lua
  // for writing at all. A prior version narrowed the check-to-open gap
  // instead of removing it, which a marketplace security reviewer correctly
  // rejected — narrower is not the same as closed
  // (github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/2460).
  //
  // This version never opens the bindings path for writing, so there is
  // nothing for a symlink swapped into that path to redirect: `cp` and
  // `grep` against it are reads (at worst, a swap makes us read and copy
  // some other file's bytes into our own temp file — never a write to
  // anywhere but our own fresh mktemp file). The final `mv -f -- "$tmp"
  // "$bindings"` is a rename(2), which POSIX guarantees replaces whatever
  // directory entry currently sits at that path — symlink or not — rather
  // than following it; it can never write through to a symlink's target.
  // So the only path this script can ever write new content to is
  // literally ~/.config/hypr/bindings.lua itself, regardless of what that
  // path resolves to at any point while this runs.
  readonly property string bootstrapScript:
    "set -euo pipefail\n" +
    "chmod +x \"" + scriptPath + "\" 2>/dev/null || true\n" +
    "bindings=\"" + bindingsFile + "\"\n" +
    "[[ -e \"$bindings\" ]] || exit 0\n" +
    "grep -qF \"" + marker + "\" \"$bindings\" && exit 0\n" +
    "dir=$(dirname -- \"$bindings\")\n" +
    "tmp=$(mktemp \"$dir/.bindings.lua.XXXXXX\")\n" +
    "trap 'rm -f \"$tmp\"' EXIT\n" +
    "cp -- \"$bindings\" \"$tmp\"\n" +
    "{\n" +
    "  echo ''\n" +
    "  echo '-- Added by the xadacka.window-switcher plugin.'\n" +
    "  echo 'o.bind(\"" + bindKey + "\", \"Window switcher\", \"" + scriptPath + "\")'\n" +
    "} >> \"$tmp\"\n" +
    "chmod --reference=\"$bindings\" \"$tmp\" 2>/dev/null || true\n" +
    "mv -f -- \"$tmp\" \"$bindings\"\n" +
    "command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true\n"

  Process {
    id: bootstrapProcess
    command: ["bash", "-c", root.bootstrapScript]
    stderr: SplitParser {
      onRead: data => console.warn("xadacka.window-switcher: " + data)
    }
  }
}
