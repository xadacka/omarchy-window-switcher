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

  readonly property string bootstrapScript:
    "set -euo pipefail\n" +
    "chmod +x \"" + scriptPath + "\" 2>/dev/null || true\n" +
    "bindings=\"" + bindingsFile + "\"\n" +
    "[[ -f \"$bindings\" ]] || exit 0\n" +
    "grep -qF \"" + marker + "\" \"$bindings\" && exit 0\n" +
    "{\n" +
    "  echo ''\n" +
    "  echo '-- Added by the xadacka.window-switcher plugin.'\n" +
    "  echo 'o.bind(\"" + bindKey + "\", \"Window switcher\", \"" + scriptPath + "\")'\n" +
    "} >> \"$bindings\"\n" +
    "command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true\n"

  Process {
    id: bootstrapProcess
    command: ["bash", "-c", root.bootstrapScript]
    stderr: SplitParser {
      onRead: data => console.warn("xadacka.window-switcher: " + data)
    }
  }
}
