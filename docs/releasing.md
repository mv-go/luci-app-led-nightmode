# Releasing

The current candidate is `0.5.0-r7`. Preparing and validating a candidate does not publish the private repository, create a tag, or change access controls.

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
- [ ] Upgrade the first router from `r6` to `r7`, verify preserved UCI, runtime health, day/night restoration, and authenticated LuCI rendering.
- [ ] Validate the core on at least one additional physical OpenWrt device before describing the application broadly as multi-device validated.

## GitHub release gate

After every candidate item is complete:

1. Confirm the working tree is clean and CI is green.
2. Create signed release notes from [`CHANGELOG.md`](../CHANGELOG.md), including known hardware limitations and exact APK hashes.
3. Tag the application version as `v0.5.0`; `r7` remains the OpenWrt packaging revision, not a separate semantic-version tag.
4. Attach the two verified APKs and their SHA-256 file.
5. Publish or change repository visibility only with explicit owner approval.

## Upstream LuCI gate

The intended destination is a new `applications/luci-app-led-nightmode` directory in `openwrt/luci`. Before opening a pull request:

- rebase the application directory onto current LuCI `master` and build with the current snapshot SDK in addition to the stable SDK;
- run LuCI's current JavaScript/JSON checks and regenerate `po/templates/led-nightmode.pot` with LuCI's `build/i18n-scan.pl`;
- decide with maintainers whether the app-specific provider subpackage stays in the LuCI package Makefile or moves to a package feed;
- prepare a focused feature branch rather than submitting from `main`;
- rewrite/squash the upstream commit series with component-prefixed subjects and `Signed-off-by` lines using the contributor's real first and last name and a non-noreply email address.

The repository currently uses a GitHub noreply identity, so the final upstream commit series cannot be prepared correctly until the contributor identity is supplied. No identity should be guessed or copied into Git history.
