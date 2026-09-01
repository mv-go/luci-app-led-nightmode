# OpenWrt SDK build

Development candidate `0.5.1-r1` produces three packages: the headless `led-nightmode` core, the UI-only `luci-app-led-nightmode`, and the optional Quectel provider. Its split gate requires that package metadata reported version `0.5.1-r1`, that every installed path has exactly one owner, and that an upgrade from monolithic `0.5.0-r8` succeeds transactionally. The validated `r8` evidence below remains the baseline until those checks complete.

The CLI/service/LuCI/provider release candidate is built against the official OpenWrt 25.12.4 SDK for `mediatek/filogic`:

- SDK: `openwrt-sdk-25.12.4-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst`
- SHA-256: `411a2277ca10f909c30275a506aab4dc28a4f1281d7fda4f19faaa2ded6630bb`
- Package architecture: `noarch`
- Base runtime dependencies: `libc`, `luci-base`, `jshn`, `procd`, `rpcd`, `sunwait`, and `uci`
- Quectel provider dependencies: the base package and `picocom`

The SDK archive and checksum are published in the [OpenWrt 25.12.4 mediatek/filogic downloads](https://downloads.openwrt.org/releases/25.12.4/targets/mediatek/filogic/).

## Build

The preferred reproducible path is the manual **OpenWrt SDK** GitHub workflow in [`.github/workflows/sdk.yml`](../../.github/workflows/sdk.yml). It pins `openwrt/gh-action-sdk` to an exact commit, runs on a native Linux worker, stages only the package feed input, and uploads only the two package outputs. The feed staging deliberately excludes `upstream/`: that directory is a separate LuCI-tree snapshot with its own `Makefile`, and presenting it to the downstream feed scanner produces a misleading `../../luci.mk` error.

For a local pre-push build, mirror the same workflow with `ghcr.io/openwrt/sdk:aarch64_cortex-a53-25.12.4`. Put the tracked source tree and artifacts in named Docker volumes rather than mounting the whole working directory. Preserve the container's `/builder` volume until validation is complete so a failed invocation can reuse downloaded and compiled dependencies. Ensure the artifacts volume is writable by the SDK container before starting the build.

On Apple Silicon, Docker Desktop runs this x86_64 image through emulation. A parallel first pass can fail in a nested GNU make with `write jobserver: Bad file descriptor`; this was reproduced in the Lua dependency rather than in LED Night Mode. Reuse the same warm `/builder` volume and repeat the package target serially:

```sh
make BUILD_LOG=1 CONFIG_AUTOREMOVE=y V=sc -j1 \
  package/luci-app-led-nightmode/compile
```

Do not discard the warm builder first: the official action prepares a large target dependency set even though both final application packages are `noarch`. The serial fallback is slow but avoids the emulated jobserver failure. Native Linux CI remains the normal first-choice build path.

Place this repository in the SDK package tree, enable it, and run the package target:

```sh
ln -s /path/to/luci-app-led-nightmode package/luci-app-led-nightmode
make defconfig
printf '%s\n' 'CONFIG_PACKAGE_luci-app-led-nightmode=m' >> .config
printf '%s\n' 'CONFIG_PACKAGE_led-nightmode-provider-quectel-qnwcfg-ledmode=m' >> .config
make defconfig
make package/luci-app-led-nightmode/compile V=sc
```

The OpenWrt 25.12 outputs use these filenames under `bin/packages/aarch64_cortex-a53/<feed>/`; the feed directory depends on how the package source was linked into the SDK:

- `luci-app-led-nightmode-0.5.0-r8.apk`;
- `led-nightmode-provider-quectel-qnwcfg-ledmode-0.5.0-r8.apk`.

The SDK is an x86_64 Linux build; an ARM64 macOS host must run it in a Linux x86_64 container or virtual machine.

For a fresh Ubuntu 24.04 container, install the complete host tool set before running any SDK target. The `python3-setuptools` and `swig` entries are required by the Filogic U-Boot prerequisite checks even though this application itself does not compile U-Boot:

```sh
apt-get update
apt-get install -y --no-install-recommends \
  bison build-essential ca-certificates file flex gawk gcc-multilib gettext git \
  libncurses-dev libssl-dev python3 python3-dev python3-setuptools rsync swig \
  unzip wget zlib1g-dev zstd
```

On Docker Desktop for macOS, copying the repository through a large bind-mounted directory can fail with `Resource deadlock avoided`. Create a tar archive of the tracked working-tree files on the host, exclude `upstream/`, mount that single archive read-only, and extract it into the feed volume as `luci-app-led-nightmode`. Set `COPYFILE_DISABLE=1` while creating the archive so macOS does not add `._*` AppleDouble files. This also excludes ignored release artifacts and local backup files from the package source.

Some minimal SDK environments retain `CONFIG_LUCI_JSMIN=y` without shipping the host-side `jsmin` executable. In that case, build this package with `CONFIG_LUCI_JSMIN=` on both the clean and compile invocations. This produces the supported unminified LuCI assets and avoids incomplete `.js.o` temporary files:

```sh
make package/luci-app-led-nightmode/clean CONFIG_LUCI_JSMIN=
make package/luci-app-led-nightmode/compile V=sc CONFIG_LUCI_JSMIN=
```

## Validated `0.5.0-r8` candidate artifact

Both `0.5.0-r8` package builds were produced by the pinned official SDK action image and checked with its `apk-tools 3.0.5`:

- `apk verify --allow-untrusted` reported `OK`;
- metadata reported version `0.5.0-r8` and architecture `noarch`;
- `/etc/config/led-nightmode` is registered as a conffile with mode `0600` and contains no device-specific provider default;
- the init script, UCI migration, shared service executable, two service runners, CLI, and provider driver have mode `0755`; the schedule and rpcd entry points are package symlinks to the shared executable; the ACL, LuCI menu, JavaScript view, and timezone-coordinate module have mode `0644`;
- the package contains no `.js.o` temporary files;
- every non-JavaScript runtime file matched its repository source byte for byte after extraction, and both JavaScript assets matched the output of the SDK's own `jsmin` applied to their sources;
- the extracted init script contains `START=97`, and the extracted UCI-defaults script migrates an enabled legacy `S95led-nightmode` link by disabling and re-enabling the service at its current priority.

Validated SHA-256 values:

- base APK: `7d21cc100f3cfd230c8a0723dbc68b0dc34afaa0739c0120eb7dec6b92513bd3`;
- Quectel provider APK: `50cdd1fb81e7189b29fe8442415a777481572d9a450b4bcccee8eb06df62ea8c`.

The locally exported artifact is kept under ignored `dist/` and is not committed to Git.

The architecture image used by the pinned action currently prepares the `bcm27xx/bcm2710` SDK target internally. This is official SDK packaging evidence for `aarch64_cortex-a53`, not a physical-device claim. Both outputs declare `noarch`; the separate live BPI-R3 Mini validation below establishes behaviour on `mediatek/filogic`.

## GitHub workflow validation

The manual [OpenWrt SDK run 32731204783](https://github.com/mv-go/luci-app-led-nightmode/actions/runs/32731204783) completed successfully for commit `25d39a28bdc0af7256140bdbf7e0e8ab1fdd80ab`. Its downloaded artifact contained exactly the two candidate APKs and no SDK dependency packages or build logs.

SHA-256 values of the GitHub-uploaded APKs:

- base APK: `97070522987be9d1d994d4c2a348a7b542a70d8c904e2fe203bf89623343483e`;
- Quectel provider APK: `a943e338c1b60e2c55c98b7680d2e88f986bf5e3f4b0d035c8111ef62ef4d626`.

These hashes identify the remote workflow outputs; the independent local SDK outputs above have their own hashes because APK build metadata is not byte-for-byte reproducible between the two build environments.

## Upstream snapshot validation

The universal application was staged as `applications/luci-app-led-nightmode` against LuCI `master` commit `5cb5db64213d712d1ca325dd895b4e1cd2340d50`. The staged tree uses LuCI's relative `../../luci.mk`, contains the generic sysfs core and provider interface, and deliberately excludes the device-specific Quectel provider package.

The [Upstream LuCI run 32744552250](https://github.com/mv-go/luci-app-led-nightmode/actions/runs/32744552250) completed successfully. It performed current LuCI JavaScript and JSON lint, regenerated and compared the translation template, then built the staged application with the official OpenWrt snapshot SDK for `aarch64_cortex-a53`. The snapshot toolchain reported GCC 14.4.0 and produced one `noarch` package:

- `luci-app-led-nightmode-0.5.0-r7.apk`;
- SHA-256 `e8340549c1ebb5dfb27b6a6365b1f52846857a8964a617797c4dad3daee8de32`.

The package build metadata recorded the expected dependencies on `luci-base`, `jshn`, `procd`, `rpcd`, `sunwait`, and `uci`. The downloaded workflow artifact also contains the package build logs; no provider APK is present in the upstream artifact.
