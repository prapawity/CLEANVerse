# CLEANVerse visual direction

Status: initial implementation; subject to refinement and accessibility testing. Researched 2026-11-21.

## Brand reference

GITVerse by PRAPAWITY uses a ringed-planet mark, blue/violet accents, Catppuccin-inspired surfaces and system-oriented typography. CLEANVerse adopts the family palette while using its own cleaning-brush mark, with a subtle sweep inspired by [GITVerse](https://github.com/prapawity/GITVerse-by-PRAPAWITY). The brush is a provisional proposal used in the app and Windows icon, not an approved final identity. The earlier GITVerse asset and its MIT license remain in the repository as a reference. Other platform icons have not yet been updated.

The redesigned preview uses canvas `#141626`, panel `#1d2032`, outline `#353b53`, action `#73d5fb`, and violet accent `#c2a7f5`. Text and controls use Flutter's dark color scheme. Use native/system text rather than requiring a font download. A light theme is a future task, not an implemented feature.

## CleanMyMac research

CleanMyMac organizes a range of tasks into modules, gives users a clear scan starting point, and makes results reviewable before running tasks. Its Space Lens pairs a storage visualization with a file list, and My Tools provides direct access to individual tools. These are useful interaction ideas for a consumer utility; they do not imply CLEANVerse currently implements those tools. Sources: [Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care), [My Tools](https://macpaw.com/support/cleanmymac/knowledgebase/my-tools), [Space Lens screenshot](https://cleanmymac.com/).

For CLEANVerse, use a clear primary task, calm explanatory copy and reviewable results. Keep developer storage discovery easy to find in its own workspace area. Preserve an independent layout, terminology and GITVerse-based branding; do not copy CleanMyMac artwork, animations, text, screenshots or proprietary UI assets. Do not present security, cleanup or storage visualization features as available until implemented. The [OpenAI frontend design guide](https://learn.chatgpt.com/use-cases/frontend-designs) also recommends comparing the implemented interface at different sizes and iterating on visual results.

## Validation

Check desktop and narrow layouts, 200% text scaling, keyboard and screen-reader labels, contrast, and actual states for scanning, cancellation, partial results and errors. The redesigned interface has passed static analysis but has not been tested or verified on a native device; prior widget tests do not validate this redesign. See `DESIGN_REVIEW.md`.
