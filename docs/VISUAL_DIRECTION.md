# CLEANVerse visual direction

Status: initial implementation; subject to refinement and accessibility testing. Researched 2026-11-21.

## Brand reference

GITVerse by PRAPAWITY uses a ringed-planet mark, blue/violet accents, Catppuccin-inspired surfaces and system-oriented typography. CLEANVerse adopts the family palette with its own mark. The earlier GITVerse asset and its MIT license remain in the repository as a reference; the earlier "Orbit Brush" (`assets/brand/cleanverse-brush.svg`) is kept as history.

### App icon: "Swept Orbit" (current design, subject to the owner's approval)

A planet on a dark squircle tile, half dusty (muted violet with dust specks) and half clean (bright violet `#c2a7f5`), divided by a cyan `#73d5fb` orbit that sweeps across its face and ends in a bright leading particle. The orbit nods to GITVerse's ringed planet; the dusty-to-clean split says "cleanup" without a trash can, broom or sparkle, and is not derived from CleanMyMac or any other product's artwork. The tile follows macOS Big Sur+ grammar: about 10% transparent margin (824 px tile on a 1024 canvas), a top-lit gradient from `#2a2d45` to canvas `#141626`, a faint rim and a soft stacked shadow. The 16 and 32 px sizes use a simplified variant (larger planet, flat colours, no dust or tail fade, lighter dusty half) so the split and orbit stay legible.

Files (in `apps/cleanverse/`):
- `assets/brand/cleanverse-icon.svg`: master, 1024 canvas, used for 64 px and up.
- `assets/brand/cleanverse-icon-small.svg`: simplified 16/32 px variant.
- `assets/brand/cleanverse-mark.svg`: flat mark on a transparent background; rendered to `cleanverse-mark.png` (40 px) with `2.0x/` and `3.0x/` variants for the in-app `_Brand` logo.
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png` (16 to 1024) and `windows/runner/resources/app_icon.ico` (16, 24, 32, 48, 64, 256) are renders of the SVGs above.

Linux sets the window icon at runtime from the bundled `assets/brand/cleanverse-icon-256.png` (`gtk_window_set_icon_from_file`); no desktop entry is installed yet, so launchers may still show a generic icon. Window titles read "CLEANVerse" on all platforms. Neither the Windows nor the Linux icon has been checked on a real host.

The redesigned preview uses canvas `#141626`, panel `#1d2032`, outline `#353b53`, action `#73d5fb`, and violet accent `#c2a7f5`. Text and controls use Flutter's dark color scheme. Use native/system text rather than requiring a font download. A light theme is a future task, not an implemented feature.

## CleanMyMac research

CleanMyMac organizes a range of tasks into modules, gives users a clear scan starting point, and makes results reviewable before running tasks. Its Space Lens pairs a storage visualization with a file list, and My Tools provides direct access to individual tools. These are useful interaction ideas for a consumer utility; they do not imply CLEANVerse currently implements those tools. Sources: [Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care), [My Tools](https://macpaw.com/support/cleanmymac/knowledgebase/my-tools), [Space Lens screenshot](https://cleanmymac.com/).

For CLEANVerse, use a clear primary task, calm explanatory copy and reviewable results. Keep developer storage discovery easy to find in its own workspace area. Preserve an independent layout, terminology and GITVerse-based branding; do not copy CleanMyMac artwork, animations, text, screenshots or proprietary UI assets. Do not present security, cleanup or storage visualization features as available until implemented. The [OpenAI frontend design guide](https://learn.chatgpt.com/use-cases/frontend-designs) also recommends comparing the implemented interface at different sizes and iterating on visual results.

## Validation

Check desktop and narrow layouts, 200% text scaling, keyboard and screen-reader labels, contrast, and actual states for scanning, cancellation, partial results and errors. The redesigned interface has passed static analysis but has not been tested or verified on a native device; prior widget tests do not validate this redesign. See `DESIGN_REVIEW.md`.
