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

The `workspace/ccgoogle.ps1` launcher starts the custom Chromium build with
the local Google OAuth settings, without storing those settings in this
repository.

## Restore

1. Check out Chromium at the base commit above.
2. From the Chromium `src` directory, apply the patch:

   ```powershell
   git am <path-to-this-repo>\patches\0001-chore-checkpoint-custom-Chromium-browser-work.patch
   ```

3. Copy the files from `workspace/` to the Chromium workspace root if the
   local build wrapper and notes are needed.

4. Put the private `google_default_client_id` and
   `google_default_client_secret` values in the local `src/out/UpstreamFastDev/args.gn`,
   then run `ccgoogle.cmd` from the workspace root to open the Google sign-in
   settings page.

The generated `out/` directories are intentionally excluded and must be
rebuilt locally.

## Latest upstream snapshot

The current upstream-based checkout uses Chromium commit
`6ec4ee43f0aea01464d220c8bd87e4674d1ae9df`. To restore the Google account
sync UI change on that checkout, apply:

```powershell
git am <path-to-this-repo>\patches\0002-restore-google-account-sync-ui.patch
```
