# Curated wallpaper provenance (Task 27b / Task 33)

Real image assets for each theme's curated wallpaper (referenced from
`design/tokens/themes.json`'s `"curated": true` entries, copied onto new
users by `gen_wallpaper.py --all` from this directory - see that script's
`--all` branch). Previously these files only existed inside
holycowstudios's own home directory on the guest and were never persisted
in this repo, which is why brand-new user accounts got no real wallpaper
for Forge at all, and a corrupted copy for Warm - fixed 12 Sept 2026.

- **jazz-wallpaper-forge-canyon.png**, **jazz-wallpaper-warm-canyon.png**:
  Recraft-generated source art (explosion/canyon composition), color-graded
  to each theme's own palette by this project (`grade_wallpaper.py`,
  scratch tooling, not committed). Akash-commissioned/generated - not
  third-party.

- **jazz-wallpaper-sapphire-hyprland.png**: Hyprland's own official
  bundled desktop wallpaper, shipped by the `hyprland` Arch package at
  `/usr/share/hypr/wall2.png` (confirmed via `pacman -Ql hyprland`),
  cropped from its native 7680x4191 to JAZZ's standard 1920x1080. Originally
  adopted for Midnight (12 Sept 2026); moved to Sapphire (15 Sept 2026,
  renamed from `jazz-wallpaper-midnight-hyprland.png`) as its default
  wallpaper at Akash's request once Sapphire became the default theme.
  Midnight now uses its own procedural placeholder as its sole wallpaper.

  **Licensing caveat, unresolved (same open class as Task 27f's Kvantum
  licensing item):** this art is not part of Hyprland's own source repo
  (`hyprwm/Hyprland` on GitHub has no `wall2.png` - checked live) and its
  original artist isn't documented anywhere in the package. It ships
  under the same BSD-3-Clause-licensed `hyprland` package as the rest of
  the desktop, but that doesn't necessarily mean the artwork itself is
  freely redistributable/re-brandable beyond "use it as your own
  Hyprland desktop background." Fine for personal/internal use on this
  dev machine; flag to Akash before this ships to anyone outside the
  project.
