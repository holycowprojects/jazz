# Kvantum base theme — source & license

`JazzBase.kvconfig` and `JazzBase.svg` are vendored, unmodified copies of
**KvArcDark**, one of the "extra themes" bundled with the official
`kvantum` package (Arch `extra` repo, `1.1.8-1`), taken directly from
`/usr/share/Kvantum/KvArcDark/` on the installed system — not downloaded
from a third-party source.

- **Author:** Tsu Jan (Kvantum's maintainer)
- **License:** GPL-3.0-or-later (Kvantum project license, confirmed via
  `pacman -Qi kvantum`)
- **Modifications:** none to the vendored files here — both `JazzBase.kvconfig`
  and `JazzBase.svg` are used as read-only templates. `jazz-theme-set`
  (Task 27e/27d) generates a real per-JAZZ-theme `.kvconfig` **and** `.svg`
  at install/theme-switch time by substituting KvArcDark's hardcoded color
  values with each JAZZ theme's own tokens from `design/tokens/themes.json`
  (the `.svg` needs this too — KvArcDark bakes its accent-blue family
  directly into ~65 shape fills like checkbox ticks and focus rings, not
  purely `[GeneralColors]`-driven, found live via pixel-sampling a
  rendered checkbox in Task 27d), and writes the result to
  `~/.config/Kvantum/Jazz-<theme-id>/`. The original vendored files here
  are never edited in place.

Recorded here for Task 27f (asset licensing record) to pick up.
