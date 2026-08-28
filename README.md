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

## Restore the Chromium 148 checkpoint

1. Check out Chromium at the base commit above.
2. From the Chromium `src` directory, apply the patch:

   ```powershell
   git am <path-to-this-repo>\patches\0001-chore-checkpoint-custom-Chromium-browser-work.patch
   ```

3. Copy the files from `workspace/` to the Chromium workspace root if the
   local build wrapper and notes are needed.

4. To expose the Chromium browser sign-in UI, put the private
   `google_api_key`, `google_default_client_id`, and
   `google_default_client_secret` values in the local
   `src/out/UpstreamFastDev/args.gn`. Do not commit those values.

5. Regenerate the build files and rebuild the Google API component:

   ```powershell
   gn gen out\UpstreamFastDev
   autoninja --fast_local -C out\UpstreamFastDev google_apis
   ```

6. Start `src/out/UpstreamFastDev/chrome.exe` normally. No launcher or OAuth
   command-line parameters are required for the UI to appear.

## Restore the current Chromium 154 build

The current upstream-based checkout uses Chromium commit
`6ec4ee43f0aea01464d220c8bd87e4674d1ae9df`.

1. Check out Chromium at the commit above.
2. Apply the current patches in order:

   ```powershell
   git am <path-to-this-repo>\patches\0002-restore-google-account-sync-ui.patch
   git am <path-to-this-repo>\patches\0003-Add-browser-control-CLI-and-proxy-management.patch
   git am <path-to-this-repo>\patches\0004-Add-managed-Mihomo-proxy-dashboard.patch
   ```

3. Put the private Google API key, OAuth client ID, and OAuth client secret in
   the local `out/UpstreamFastDev/args.gn`. Never commit those values.
4. Generate and fully build the browser target:

   ```powershell
   gn gen out\UpstreamFastDev
   autoninja -C out\UpstreamFastDev chrome
   ```

5. Start the browser normally, or use the automation CLI:

   ```powershell
   .\ccchrome.cmd up
   .\ccchrome.cmd open https://example.com
   .\ccchrome.cmd tabs
   .\ccchrome.cmd proxy show
   .\ccchrome.cmd proxy setup
   .\ccchrome.cmd proxy dashboard
   ```

## Managed proxy

Patch `0004` adds an on-demand Mihomo proxy core, subscription management,
automatic core/dashboard updates with rollback, node selection and testing,
and a local Chinese proxy settings page. The Advanced dashboard opens the
bundled MetaCubeXD traffic, connection, rule, and log views.

Mihomo, MetaCubeXD, subscriptions, generated proxy configuration, logs, and
process state are downloaded or created under `src/out/browserctl/mihomo`.
They are intentionally excluded from Git. After restoring the source patches,
install the current official runtime files with:

```powershell
.\ccchrome.cmd proxy setup [clash-or-mihomo-subscription-url]
```

The core starts only in managed proxy mode and exits with the managed browser.
Direct and system proxy modes do not start it. Complete Clash/Mihomo YAML
subscriptions and local YAML files are supported; raw Base64 URI lists must be
converted to Clash/Mihomo YAML first.

## Google sync verification

Google account login and sync are working in the Chromium 154 build. The
earlier `no_authorization_code` result came from an incomplete incremental
build that mixed stale and current browser components. A full `chrome` target
build regenerated the matching executable and DLL set and restored sign-in.

After changing Google API settings, DICE/sign-in code, Chrome settings UI, or
other core browser code, rebuild the complete `chrome` target before testing.
Rebuilding only `google_apis` is not sufficient for this checkout.

The generated `out/` directories are intentionally excluded and must be
rebuilt locally.
