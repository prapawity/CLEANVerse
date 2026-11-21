# CLEANVerse visual direction

Status: initial implementation; subject to refinement and accessibility testing. Researched 2026-11-21.

## Brand reference

GITVerse by PRAPAWITY uses a ringed-planet mark, blue/violet accents, Catppuccin-inspired surfaces and system-oriented typography. CLEANVerse adopts this family identity, uses its own name, and emphasizes approachable storage care. The planet image is reused from [GITVerse](https://github.com/prapawity/GITVerse-by-PRAPAWITY) at commit `3a368904f54f5102345682431ef1a45c67e460ba`; the MIT license is included alongside the asset. This is an in-app mark, not yet the operating-system application icon.

The initial dark palette maps canvas `#1e1e2e`, panel `#181825`, outline `#45475a`, action `#4cc2ff`, and violet accent `#cba6f7`. Text and controls use Flutter's dark color scheme. Use native/system text rather than requiring a font download. A light theme is a future task, not an implemented feature.

## CleanMyMac research

CleanMyMac organizes a range of tasks into modules, gives users a clear scan starting point, and makes results reviewable before running tasks. Its Space Lens pairs a storage visualization with a file list, and My Tools provides direct access to individual tools. These are useful interaction ideas for a consumer utility; they do not imply CLEANVerse currently implements those tools. Sources: [Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care), [My Tools](https://macpaw.com/support/cleanmymac/knowledgebase/my-tools), [Space Lens screenshot](https://cleanmymac.com/).

For CLEANVerse, use a clear primary task, calm explanatory copy and reviewable results. Preserve an independent layout, terminology and GITVerse-based branding; do not copy CleanMyMac artwork, animations, text, screenshots or proprietary UI assets. Do not present security, cleanup or storage visualization features as available until implemented.

## Validation

Check desktop and narrow layouts, 200% text scaling, keyboard and screen-reader labels, contrast, and actual states for scanning, cancellation, partial results and errors. The current version has automated widget checks; native platform, screen-reader and theme coverage still require device verification. See `DESIGN_REVIEW.md`.
