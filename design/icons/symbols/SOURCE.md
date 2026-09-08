# Icon source

All SVGs in this directory are adapted from [Lucide](https://lucide.dev/) (ISC license),
normalized to JAZZ's spec: 24x24 canvas, 1.8px stroke, round linecap/linejoin, `fill: none`.
Lucide ships icons at 2px stroke with `stroke="currentColor"`; JAZZ's copies have that
narrowed to 1.8px and the color baked in directly, since Quickshell runs Qt's software
rendering backend on this hardware (`QT_QUICK_BACKEND=software`, `setup-hyprland.sh`),
which doesn't support the shader-based recoloring (`ColorOverlay`/`MultiEffect`) that would
otherwise let one SVG serve every theme.

Icons with a `-ondark`/`-onlight` suffix are theme-reactive contexts (dock icons, Settings)
where QML picks the file matching `Theme.darkMode` - see `shell.qml`/`Settings.qml`. Plain
names (no suffix) are top-bar icons, always white since the top bar is always the active
workspace's saturated color regardless of theme.

Full source/license/modification record: see Task 27f (asset licensing), not yet written -
this file is the interim note.
