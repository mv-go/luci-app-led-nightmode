# Releasing

Application release `0.5.0` uses OpenWrt package revision `r7`. Preparing and validating the candidate does not by itself publish the private repository, create a tag, or change access controls.

## Automated gate

Run:

```sh
make release-check
```

This runs all fixture suites, POSIX shell syntax checks, release metadata checks, universal-runtime leakage checks, safe-default checks, symlink checks, and the translation-template check. GitHub CI additionally parses every shell source with BusyBox `ash`.

The manual **OpenWrt SDK** GitHub workflow builds both packages with the official OpenWrt 25.12.4 `aarch64_cortex-a53` SDK image. Its uploaded artifact is deliberately limited to the two candidate APKs from the package feed's `action` directory; SDK dependency packages and build logs stay out of the release payload. Local SDK validation remains documented in [`building/openwrt-sdk.md`](building/openwrt-sdk.md).

## Candidate checklist

- [x] Fresh installation is write-safe and disabled.
- [x] Universal runtime contains no first-device LED names, modem model, provider driver, or serial-port default.
- [x] Empty sysfs LED inventory is a safe no-op.
- [x] Fixture-backed CLI, init, LuCI asset, provider, service, schedule, RPC, and UCI migration tests pass.
- [x] Current upstream LuCI JavaScript and JSON lint passes and is enforced in CI.
- [x] Compatibility evidence and unsupported scope are documented.
- [x] English LuCI translation template is generated from source.
- [x] Build and verify both `0.5.0-r7` APKs in the official SDK; record hashes in the SDK document.
- [x] Upgrade the first router from `r6` to `r7` and verify preserved UCI, runtime health, provider behaviour, connectivity, and day/night restoration.
- [x] Confirm authenticated LuCI rendering on the first router; the owner completed the visual check.
- [x] Keep multi-device validation out of `v0.5.0` claims; a second physical OpenWrt target is explicitly deferred by the owner.

## GitHub release gate

After every candidate item is complete:

1. Confirm the working tree is clean and CI is green.
2. Create signed release notes from [`CHANGELOG.md`](../CHANGELOG.md), including known hardware limitations and exact APK hashes.
3. Tag the application version as `v0.5.0`; `r7` remains the OpenWrt packaging revision, not a separate semantic-version tag.
4. Attach the two verified APKs and their SHA-256 file.
5. Publish or change repository visibility only with explicit owner approval.

## Upstream LuCI gate

The intended destination is a new `applications/luci-app-led-nightmode` directory in `openwrt/luci`. Before opening a pull request:

- stage the universal application with `make stage-upstream DEST=/path/to/luci/applications/luci-app-led-nightmode`;
- rebase the application directory onto current LuCI `master` and build with the current snapshot SDK in addition to the stable SDK;
- run LuCI's current JavaScript/JSON checks and regenerate `po/templates/led-nightmode.pot` with LuCI's `build/i18n-scan.pl`;
- keep the device-specific Quectel provider out of the initial LuCI application; it remains a downstream package until maintainers choose a suitable package-feed location;
- prepare a focused feature branch rather than submitting from `main`;
- rewrite/squash the upstream commit series with component-prefixed subjects and `Signed-off-by` lines using the contributor's real first and last name and a non-noreply email address.

The manual **Upstream LuCI** workflow performs the current-tree lint, translation-template comparison, and an official snapshot SDK build against the staged application. The staging test ensures the universal runtime stays byte-for-byte aligned while the optional hardware-specific provider does not leak into the LuCI tree.

The repository currently uses a GitHub noreply identity, so the final upstream commit series cannot be prepared correctly until the contributor identity is supplied. No identity should be guessed or copied into Git history.

Current preparation status:

- [x] Reproducible universal application staging with provider exclusion.
- [x] Current LuCI `master` JavaScript/JSON lint and translation-template comparison.
- [x] Official OpenWrt snapshot SDK package build and downloaded artifact verification.
- [x] Public `mv-go/luci` fork and local `luci-app-led-nightmode` feature branch based on current `master`.
- [ ] Replace the noreply placeholder with the contributor's reachable identity and create a signed, signed-off commit.
- [ ] Push the feature branch and open the upstream pull request.
