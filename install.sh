#!/bin/bash
# Installs omarchy-window-switcher and wires up a keybinding.
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin_dir="$HOME/.local/bin"
bindings_file="$HOME/.config/hypr/bindings.lua"
key="${OMARCHY_WINDOW_SWITCHER_KEY:-SUPER + GRAVE}"

mkdir -p "$bin_dir"
install -m 755 "$repo_dir/bin/omarchy-window-switcher" "$bin_dir/omarchy-window-switcher"
echo "Installed $bin_dir/omarchy-window-switcher"

if [[ ! -f $bindings_file ]]; then
  echo "warning: $bindings_file not found — skipping keybinding setup." >&2
  echo "Add this line yourself once it exists:" >&2
  echo "  o.bind(\"$key\", \"Window switcher\", \"omarchy-window-switcher\")" >&2
  exit 0
fi

if grep -q "omarchy-window-switcher" "$bindings_file"; then
  echo "A binding for omarchy-window-switcher already exists in $bindings_file — leaving it as is."
elif command -v omarchy >/dev/null 2>&1 && omarchy menu keybindings --print 2>/dev/null | grep -Fq "$key "; then
  echo "warning: $key is already bound to something else. Skipping keybinding setup." >&2
  echo "Pick a free key and add this yourself in $bindings_file:" >&2
  echo "  o.bind(\"$key\", \"Window switcher\", \"omarchy-window-switcher\")" >&2
else
  # Atomic-replace rather than opening bindings_file for writing: build the
  # new content in our own temp file, then `mv` it over the target. rename(2)
  # replaces whatever directory entry sits at bindings_file — symlink or
  # not — rather than following it, so there's no write-open against the
  # (mutable, same-user-writable) path for a symlink swap to redirect.
  # See github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/2460.
  bindings_dir=$(dirname -- "$bindings_file")
  tmp=$(mktemp "$bindings_dir/.bindings.lua.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  cp -- "$bindings_file" "$tmp"
  {
    echo ""
    echo "-- Searchable window switcher (type to filter open windows, Enter to focus)."
    echo "-- Installed by omarchy-window-switcher's install.sh."
    echo "o.bind(\"$key\", \"Window switcher\", \"omarchy-window-switcher\")"
  } >> "$tmp"
  chmod --reference="$bindings_file" "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$bindings_file"
  trap - EXIT
  echo "Added a $key keybinding to $bindings_file"
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null 2>&1 || true
  echo "Reloaded Hyprland config."
fi

echo "Done. Press $key to try it."
