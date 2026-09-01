# Releasing

Application release `0.5.1` has published OpenWrt package revision `r1`. It splits the headless core from the LuCI UI while preserving the runtime and upgrade contract. The earlier `v0.5.0` release remains the validated monolithic baseline used by the automated upgrade test.

## Split gate

- [x] Move the universal runtime into a separately owned `led-nightmode` package tree.
- [x] Keep the LuCI package limited to JavaScript, menu, ACL, and translations with a dependency on `led-nightmode`.
- [x] Change the Quectel provider dependency from LuCI to the core package.
- [x] Keep fixture tests green and add package-boundary assertions.
- [x] Build and inspect all three `0.5.1-r1` APKs with the official stable SDK.
- [x] Verify transactional upgrade from the monolithic `0.5.0-r8` package without file conflicts or UCI changes.
- [x] Stage and fixture-validate the immutable-source `openwrt/packages` contribution; replace its hash placeholder with the published tag archive hash before upstream validation.
- [ ] Stage and validate the UI-only `openwrt/luci` contribution against the core package.
- [ ] Confirm the public author/sign-off name before final upstream commits.

## Automated gate

Run:

```sh
make release-check
```

This runs all fixture suites, POSIX shell syntax checks, release metadata checks, universal-runtime leakage checks, safe-default checks, symlink checks, and the translation-template check. GitHub CI additionally parses every shell source with BusyBox `ash`.

The manual **OpenWrt SDK** GitHub workflow builds all three packages with the official OpenWrt 25.12.4 `aarch64_cortex-a53` SDK image. It then runs an isolated `apk-tools` 3 upgrade transaction from the published monolithic `0.5.0-r8` package and checks preserved configuration, package ownership, symlinks, and installed file contents. Its uploaded artifact is deliberately limited to the three release APKs from the package feed's `action` directory; SDK dependency packages and build logs stay out of the release payload. Local SDK validation remains documented in [`building/openwrt-sdk.md`](building/openwrt-sdk.md).

## Release checklist

- [x] Fresh installation is write-safe and disabled.
- [x] Universal runtime contains no first-device LED names, modem model, provider driver, or serial-port default.
- [x] Empty sysfs LED inventory is a safe no-op.
- [x] Fixture-backed CLI, init, LuCI asset, provider, service, schedule, RPC, and UCI migration tests pass.
- [x] Current upstream LuCI JavaScript and JSON lint passes and is enforced in CI.
- [x] Compatibility evidence and unsupported scope are documented.
- [x] English LuCI translation template is generated from source.
- [x] Build and verify both `0.5.0-r8` APKs in the official SDK; record hashes in the SDK document.
- [x] Upgrade the first router from `r7` to `r8`, verify the legacy `S95` autostart link migrates to `S97`, and confirm preserved UCI, runtime health, provider behaviour, and connectivity.
- [x] Reboot the first router while forced to Night and confirm every managed sysfs LED remains at trigger `none` and brightness `0` after startup completes.
- [x] Physically unplug/replug the first router at Night to reproduce the owner's exact original power-loss path; the owner confirmed the expected result.
- [x] Confirm authenticated LuCI rendering on the first router; the owner completed the visual check.
- [x] Keep multi-device validation out of `v0.5.0` claims; a second physical OpenWrt target is explicitly deferred by the owner.

## GitHub release gate

For `v0.5.1`:

1. Confirm the working tree is clean and CI is green.
2. Create a signed `v0.5.1` tag and release notes from [`CHANGELOG.md`](../CHANGELOG.md), including known hardware limitations, the offline-only nature of the split-upgrade validation, and exact APK hashes.
3. Attach the three verified APKs and their SHA-256 file.
4. Publish or change repository visibility only with explicit owner approval.

## Upstream gate

The headless runtime and its LuCI UI have separate upstream destinations: `utils/led-nightmode` in `openwrt/packages` and `applications/luci-app-led-nightmode` in `openwrt/luci`. Before opening the two pull requests:

- create the signed `v0.5.1` release tag, calculate the tag archive SHA-256, and stage the core with `make stage-upstream-packages DEST=/path/to/packages/utils/led-nightmode PKG_HASH=<sha256>`;
- stage the UI with `make stage-upstream-luci DEST=/path/to/luci/applications/luci-app-led-nightmode`;
- keep the core contribution free of LuCI and provider files, and keep the LuCI contribution limited to UI, menu, ACL, and translations with its `+led-nightmode` dependency;
- rebase the application directory onto current LuCI `master` and build with the current snapshot SDK in addition to the stable SDK;
- run LuCI's current JavaScript/JSON checks and regenerate `po/templates/led-nightmode.pot` with LuCI's `build/i18n-scan.pl`;
- keep the device-specific Quectel provider out of both initial upstream contributions; it remains a downstream package until maintainers choose a suitable package-feed location;
- prepare a focused feature branch rather than submitting from `main`;
- rewrite/squash the upstream commit series with component-prefixed subjects and `Signed-off-by` lines using the contributor's real first and last name and a non-noreply email address.

The manual **Upstream LuCI** workflow accepts the published tag archive SHA-256, performs the current-tree lint and translation-template comparison, then builds the staged application and core package together with an official snapshot SDK. The staging tests enforce the ownership boundary and ensure the optional hardware-specific provider does not leak into either tree.

The repository uses the reachable address `rapture-ribose6k@icloud.com`, and the published preparation commit is signed and signed off. Its author name is currently `mv-go`; before the final upstream commit series, the owner must confirm the public first-and-last-name form required by LuCI's contribution rules. No name should be guessed or copied into Git history.

Current preparation status:

- [x] Reproducible universal application staging with provider exclusion.
- [x] Current LuCI `master` JavaScript/JSON lint and translation-template comparison.
- [x] Official OpenWrt snapshot SDK package build and downloaded artifact verification.
- [x] Public `mv-go/luci` fork and local `luci-app-led-nightmode` feature branch based on current `master`.
- [x] Replace the noreply placeholder with the contributor's reachable email and verify a signed, signed-off preparation commit.
- [x] Push the preparation feature branch without opening a pull request.
- [ ] Confirm the contributor's public author/sign-off name, replace the monolithic preparation branch after the core/LuCI split, and open the upstream pull request.
