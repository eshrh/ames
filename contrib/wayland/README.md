# ames on wayland

This is a port of the [wlroots](https://github.com/eshrh/ames/tree/wlroots)
branch to the new configuration system which allows redefining functions
dependent on X11 without needing to touch the rest of the program logic that
does not depend on X11-specific binaries.

The provided [config](./config) overwrites these functions using
the Wayland utilities `slurp`/`grim`/`sway`/`wl-clipboard` but
a user on a different compositor/desktop environment could use
`gnome-screenshot`/`flameshot`, for example.
In addition, the [Python](../python/README.md) backend uses
[pyscreenshot](https://github.com/ponty/pyscreenshot),
which automatically support many different configurations.
- `get_selection()`
- `take_screenshot_region()`
- `take_screenshot_window()`
- `copied_text()`

For a detailed discussion on supporting Wayland for different compositors,
see the issue [Wayland Support #2](https://github.com/eshrh/ames/issues/2).

