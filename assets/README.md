# Brand assets

- `AppIcon.png`: original raster master generated for ScreenMate with OpenAI's built-in image generation tool. The generated file is 1254 × 1254 with an alpha channel.
- `AppIcon.icns`: macOS multi-resolution icon, generated with `bash scripts/build-icon.sh` using Apple's `sips` for image sizing and a small Python standard-library ICNS container writer.
- The small monochrome menu bar glyph uses Apple's `rectangle.2.swap` system symbol, rather than the full-color app icon, for legibility in light/dark menu bars.

These project assets are included under the repository's MIT license. No third-party reference images were used.

## Design

Two overlapping display/window frames communicate moving between display setups. The mint corner marker represents a remembered position. Navy, blue, and teal keep a distinct silhouette against light and dark macOS backgrounds. The full-color icon is used by Finder, installation, and onboarding.

## Generation prompt

> Use case: logo-brand. Create one original production macOS application icon for ScreenMate, a native utility that remembers window layouts across monitors. Square 1024 x 1024 canvas. A premium rounded squircle tile in deep midnight navy, with subtle luminous teal and blue gradient. Center a bold, very simple sculpted glass-and-metal symbol consisting of two overlapping desktop display/window frames, one larger rear monitor and one smaller front window, with one small mint anchor-like corner marker conveying saved position. Large coherent silhouette, high contrast, exquisite restrained native macOS material depth, soft bevels and clean edges, readable at 32px, straight-on view. Entire icon contained within central 88% of canvas with transparent outside rounded tile. No text, no letters, no numbers, no Apple logo, no watermark, no mockup or surrounding scene. Single icon only.
