# Geistos keyboard and lifecycle controls

The Hyprland bindings are the global authority. Quickshell panels expose the same actions where a panel has a corresponding interaction.

## Window management

- `SUPER + H/J/K/L` or `SUPER + arrows`: focus left/down/up/right.
- `SUPER + SHIFT + H/J/K/L`: move the active window left/down/up/right.
- `SUPER + W`: close the active window.
- `SUPER + T`: toggle floating.
- `SUPER + F`: toggle fullscreen.

The movement bindings are directional and symmetric. Workspace movement remains on `SUPER + SHIFT + number`.

## Shell and wallpaper recovery

- `SUPER + CTRL + B`: restart the `quickshell-mgeist.service` user unit.
- `SUPER + CTRL + SHIFT + W`: restart Hyprpaper through the Quickshell wallpaper service and reapply the active wallpaper.
- `SUPER + CTRL + SPACE`: open theme and wallpaper selection.
- `SUPER + CTRL + R`: advance the paired wallpaper/theme rotation.

Wallpaper changes update Hyprpaper, the Quickshell wallpaper state, the generated palette, theme clients, and the stable Hyprlock background symlink. A shell restart does not create a second wallpaper source.

## Session controls

- `SUPER + ESC`: open the session menu.
- Lock and suspend act immediately.
- Log out, reboot, and power off require a second activation.

The session menu is a desktop action surface; it is not exposed by the lock screen itself. Destructive actions stay confirmation-gated.

## Panels

- `SUPER + SPACE`: launcher.
- `SUPER + CTRL + K`: keybinding browser.
- `SUPER + CTRL + W`: quick settings.
- `SUPER + CTRL + V`: clipboard history.
- `SUPER + CTRL + N`: notifications.
- `SUPER + CTRL + A`: local AI panel.

The keybinding browser is generated from Hyprland's descriptions, so new global bindings should always include a description.
