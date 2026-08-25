# CCCrome custom changes

This repository stores only the local Chromium customizations. It does not
contain the Chromium source checkout, build outputs, Visual Studio toolchain,
or browser profiles.

## Base

- Chromium commit: `2738560225e6c7d4d39e4839aab90d59bc8add04`
- Local checkpoint: `c8768952ea14b3fb37027ccbf64beba5707051c1`

## Contents

- `patches/`: Git patch containing the custom browser source changes.
- `workspace/`: Local build helpers, feature notes, and reference material.

## Restore

1. Check out Chromium at the base commit above.
2. From the Chromium `src` directory, apply the patch:

   ```powershell
   git am <path-to-this-repo>\patches\0001-chore-checkpoint-custom-Chromium-browser-work.patch
   ```

3. Copy the files from `workspace/` to the Chromium workspace root if the
   local build wrapper and notes are needed.

The generated `out/` directories are intentionally excluded and must be
rebuilt locally.
