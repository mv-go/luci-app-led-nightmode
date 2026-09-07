# Client footprint audit

This audit measures the published `led-nightmode-0.5.1-r1.apk`, not the source archive used by the SDK. The source archive never reaches the router. The reference artifact has SHA-256 `7933d0f2aae7613911f26da4f6dddcd7a0db4f8dbddaa6a2bce7856b9e411d31` and was built by the pinned OpenWrt 25.12.4 SDK workflow.

## Results

The core APK is 10,110 bytes. Its package metadata reports 36,158 installed bytes: 35,778 bytes of regular runtime payload, two symlinks, and 380 bytes of package-owned bookkeeping files.

An install into an otherwise empty package database resolves to 18 packages. This is a dependency-closure bound, not a bootable minimal OpenWrt image:

| Scenario | New packages | APK download | Declared installed size | Regular payload | Observed logical root growth |
| --- | ---: | ---: | ---: | ---: | ---: |
| Empty package database | 18 | 628,671 B | 1,428,091 B | 1,426,619 B | 1,544,793 B |
| Standard headless base | 3 | 51,062 B | 165,108 B | 164,477 B | 222,268 B |
| LuCI-capable base | 2 | 23,606 B | 101,930 B | 101,533 B | 141,565 B |

The standard headless baseline is derived from the official OpenWrt 25.12.4 `mediatek/filogic` profile. Its `base-files`, `procd-ujail`, and `uci` closure already supplies `libc`, `jshn`, `procd`, `uci`, and every library needed by `rpcd`. The only missing direct dependencies are `rpcd` and `sunwait`. A LuCI-capable image already has `rpcd` because `luci-base` depends on it, leaving only `sunwait` and `led-nightmode` to add.

| Incremental package | Version used | APK | Declared installed | Regular payload | Needed on headless base | Needed with LuCI |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `led-nightmode` | `0.5.1-r1` | 10,110 B | 36,158 B | 35,778 B | yes | yes |
| `rpcd` | `2026.07.19~e37ed9d8-r1` | 27,456 B | 63,178 B | 62,944 B | yes | no |
| `sunwait` | `0.9.1-r2` | 13,496 B | 65,772 B | 65,755 B | yes | yes |

`sunwait` is therefore noticeable but not large: it adds 13.2 KiB of download and 64.2 KiB installed. On the standard headless baseline the complete feature set, including RPC and solar scheduling, remains below 50 KiB of APK download and below 162 KiB declared installed size.

For the complete application on a router that already has LuCI, add the UI-only APK: 12,335 bytes downloaded and 33,268 bytes installed, of which 33,057 bytes are regular files. The resulting application-specific total is 35,941 bytes downloaded and 135,198 bytes installed. Our core plus UI account for 69,426 installed bytes; `sunwait` accounts for the remaining 65,772 bytes. `rpcd` adds nothing in this scenario because `luci-base` already depends on it.

The observed logical root growth is deliberately reported separately from the sum of package `installed-size` fields. It includes growth of apk's global database and directory entries in the isolated fixture. Filesystem allocation on a real overlay depends on block size, compression, existing directories, and whether the packages are built into the read-only firmware image, so the declared size and payload figures are the portable comparisons.

## Dependency closure

The empty-database closure used these 18 packages from the official OpenWrt 25.12.4 repositories:

| Package | APK bytes | Installed bytes |
| --- | ---: | ---: |
| `led-nightmode` | 10,110 | 36,158 |
| `jshn` | 7,450 | 19,909 |
| `libblobmsg-json20260213` | 4,710 | 12,323 |
| `libc` | 297,206 | 590,904 |
| `libgcc1` | 50,219 | 131,107 |
| `libjson-c5` | 32,904 | 73,834 |
| `libjson-script20260213` | 5,873 | 12,337 |
| `libubox20260213` | 32,905 | 65,658 |
| `libubus20251202` | 12,988 | 28,859 |
| `libuci20250120` | 19,570 | 41,074 |
| `libudebug` | 4,967 | 12,359 |
| `procd` | 60,335 | 157,822 |
| `rpcd` | 27,456 | 63,178 |
| `sunwait` | 13,496 | 65,772 |
| `ubox` | 19,142 | 46,660 |
| `ubus` | 6,930 | 16,410 |
| `ubusd` | 14,769 | 33,021 |
| `uci` | 7,641 | 20,706 |

Most of this closure is part of OpenWrt itself and must not be attributed to installing LED Night Mode on a functioning router.

## Solar dependency review

LED Night Mode calls only `sunwait poll <twilight> <latitude> <longitude>` and consumes its day/night exit status. It supports the four fixed upstream twilight levels but does not use the wait, list, report, arbitrary-date, offset, custom-angle, formatted-output, debug, or help interfaces.

OpenWrt 25.12.4 offers no `sunwait-min` variant. Its package installs one already stripped 65,755-byte executable built from upstream `sunwait.c`, `sunriset.c`, and `print.c`; the package Makefile exposes no compile-time feature selection. The upstream CLI has four major modes and its 0.9.1 source contains 1,603 lines of C across those three files. A search of the official target, base, and packages indexes found `sunwait` as the only package whose description advertises sunrise or astronomical-twilight calculation.

Replacing it with locally implemented astronomy is technically possible but is not the safe size optimization. Correctness has edge cases around polar day/night, the date line, UTC/local-day boundaries, leap dates, and twilight definitions; upstream itself documents an estimated timing error of approximately four minutes. Reusing its calculation code would also bring GPL-3.0 code and maintenance into this project. The current design rule therefore remains appropriate: LED Night Mode does not implement astronomical calculations itself.

The low-risk optimization is dependency modularity, not a new algorithm. A future `led-nightmode-sun` companion can depend on `sunwait`, while the minimal core retains manual and fixed schedules and reports solar mode as unavailable when the companion is absent. The LuCI package can either depend on that companion to preserve today's complete feature set or detect its capability and disable the solar controls. A custom `sunwait-poll` fork should be considered only after a target-specific size budget shows that even the optional 65,772 installed bytes are unacceptable and after measuring the real saving from a prototype.

Primary source references for this review are the official [OpenWrt 25.12 sunwait package](https://github.com/openwrt/packages/blob/openwrt-25.12/utils/sunwait/Makefile), the upstream [build definition](https://github.com/risacher/sunwait/blob/0.9.1/makefile), [CLI implementation](https://github.com/risacher/sunwait/blob/0.9.1/sunwait.c), and [astronomical calculation module](https://github.com/risacher/sunwait/blob/0.9.1/sunriset.c).

## Transient storage and memory

With the three required repository indexes cached, the standard-headless fixture observed an upper bound of 273,330 bytes held as new package archives plus logical root growth during installation. A cold run added 856,433 bytes of compressed repository indexes, for 1,129,763 bytes if indexes, downloaded APKs, and the expanded root are all retained simultaneously. Normal cache cleanup can lower the post-transaction figure.

The verified run of the pinned `apk-tools` 3.0.7 container reported a 24,952,832-byte cgroup peak for the cold standard-headless transaction and 26,853,376 bytes for the cold empty-database transaction. These are reproducible harness upper bounds, not router RAM requirements: they include the container, TLS and index parsing, and x86_64 emulation on the ARM64 test host. `sunwait` is invoked briefly only while resolving a solar schedule; it is not a resident daemon. A trustworthy native target peak requires a future controlled install measurement on a representative low-memory router.

## Reproduction

Run the audit against the published core APK:

```sh
./scripts/audit-client-footprint.sh \
  dist/v0.5.1-tag-ba5e2a1/aarch64_cortex-a53/action/led-nightmode-0.5.1-r1.apk
```

The script uses the same digest-pinned Alpine `apk-tools` 3 image as the release workflow and reads the official OpenWrt 25.12.4 target, base, and packages repositories. It verifies the relevant default-base closure, then measures the empty, headless-base, and LuCI-capable scenarios separately. OpenWrt release package feeds can receive rebuilds without changing the release number, so the script prints the package versions and repository-index hashes used by each run.

Primary inputs are the official [25.12.4 `mediatek/filogic` profiles](https://downloads.openwrt.org/releases/25.12.4/targets/mediatek/filogic/profiles.json), [target packages](https://downloads.openwrt.org/releases/25.12.4/targets/mediatek/filogic/packages/), [base feed](https://downloads.openwrt.org/releases/25.12.4/packages/aarch64_cortex-a53/base/), and [packages feed](https://downloads.openwrt.org/releases/25.12.4/packages/aarch64_cortex-a53/packages/).

## Decision

The measurements do not justify changing the already published `0.5.1` release or its upstream submission: the standard headless increment is about 49.9 KiB to download and 161.2 KiB declared installed while retaining the complete RPC and solar feature set. They do identify optional solar scheduling as most of the LuCI-capable installed increment, so a future minimal-headless package profile is reasonable if low-flash devices are an explicit target rather than a hypothetical one.

If a concrete target later cannot afford this amount, the useful split points are clear: making solar scheduling an optional companion would save the 13,496-byte APK and 65,772 installed bytes; moving the rpcd entry point out of the headless core would save another 27,456-byte APK and 63,178 installed bytes on images without LuCI. Do not merely drop either dependency from the current package, because that would leave advertised modes or entry points incomplete.
