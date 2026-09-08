# OpenWrt LED subsystem boundary audit

## Verdict

Keep a separate **temporary scheduled override and recovery layer over the Linux LED class**. Do not replace its runtime snapshot with `/etc/init.d/led turnon`, `start`, or daily writes to `system.led`.

The current core is already an overlay, not a second hardware driver or persistent LED configuration system. Its ordinary enumeration and scalar writes overlap stock facilities, but this is mostly necessary consumption of the same kernel interface. Replacing the sysfs writer with `led_off()` would remove almost no logic and would lose the configurable fixture root and the external-`cat` write-status workaround.

**Metadata-only change is insufficient.** The broad “exact restoration” claim exceeds implementation and test coverage. Nested trigger settings, runtime ownership, hotplug, and recovery visibility need bounded fixes. Hardware-specific providers remain a separate path; an additional downstream provider probe issue was found.

This is an audit and proposed patch plan. Runtime, package metadata, release tags, upstream branches and PRs were not modified. Existing client-footprint work in the checkout was preserved.

## Evidence baseline

- Project `main`: `051d4ec2924b98d88cb93259a56e8dacb62fa2e5` (local HEAD and remote main agree).
- Release `v0.5.1`: `ba5e2a177eed728a39c5c9ae1a3ea32f58866352`. `git diff v0.5.1 -- core` is empty.
- [Packages PR #30426](https://github.com/openwrt/packages/pull/30426): closed, not merged; head `f9d0cf4a1d2519f264852d567741f6c2f5dc0912`. BKPepe requested changes on that head, identifying scheduling and state restoration as the potentially justified scope.
- [LuCI PR #8998](https://github.com/openwrt/luci/pull/8998): open Draft; head `e35359f7898d8157db6f77f858f44dcf2e163a84`. The later reviewed head has no new findings in its review summary. The full inline-thread resolution history was not independently re-audited in this pass.
- The upstream package matrix subsequently completed with five passing jobs and five failures after successful package builds. Three failed on unavailable snapshot kmod indexes; two passed led-nightmode's generic tests but failed sunwait's version check. These are separate from the runtime findings below; the [CI failure analysis](../building/upstream-ci.md) records the exact jobs and next actions.
- OpenWrt main: `74eb10ed5c61feff51f8d6ca6109b94e9c504ec1`; LuCI master: `7dda604a39076d6a17bb2b11e2d0f8faa32aa58c`.
- Kernel semantics checked against Linux v6.12, `adc218676eef25575469234709c2d87185ca223a`; current upstream LED class/trigger sources were also inspected. This is source evidence, not a claim of running these kernels on the router.

## What stock OpenWrt actually supplies

| Mechanism | Actual abstraction and intended use | Reuse decision |
| --- | --- | --- |
| [Kernel LED class](https://github.com/torvalds/linux/blob/adc218676eef25575469234709c2d87185ca223a/drivers/leds/led-class.c#L28) | Enumerated LED devices; readable brightness/max; writable brightness. Writing zero removes the active trigger. | Already reused directly. No new hardware abstraction is needed. |
| [Kernel triggers](https://github.com/torvalds/linux/blob/adc218676eef25575469234709c2d87185ca223a/drivers/leds/led-triggers.c#L155) | Active trigger is bracketed in the trigger listing. Switching triggers removes attribute groups and calls deactivate/activate; trigger state can be destroyed and reconstructed. | Already reused. Capture restorable settings before detaching; a trigger name alone is insufficient. |
| [`/lib/functions/leds.sh`](https://github.com/openwrt/openwrt/blob/74eb10ed5c61feff51f8d6ca6109b94e9c504ec1/package/base-files/files/lib/functions/leds.sh#L54) | `led_set_attr` is an existence check plus `echo` to a fixed `/sys/class/leds` path. `led_off` selects none and zero; `led_on` selects none and 255. DT/status helpers address boot/status LEDs. | Valid runtime primitives, but no transaction, discovery API, snapshot, arbitrary baseline restore, fixture-root injection, or scheduling. Keep the small checked writer; do not claim scalar writes as product value. |
| [`/etc/init.d/led`](https://github.com/openwrt/openwrt/blob/74eb10ed5c61feff51f8d6ca6109b94e9c504ec1/package/base-files/files/etc/init.d/led) | `START=96`; `load_led` applies UCI `system.led`, including trigger-specific settings and brightness/default. `turnoff` writes zero to every class LED. `turnon` additionally runs diag `set_state done` and `start`. | Stock owns persistent policy. Neither turnoff/turnon nor restart is an arbitrary runtime round trip. |
| Stock `/var/run/led.state` | `load_led` saves pre-configuration trigger/brightness and optional colour for configured entries; `start` restores that record, consumes it, then applies UCI again. It is not a snapshot of all LEDs immediately before an overlay, and does not save all trigger settings or retain failures transactionally. | Do not consume, overwrite, or share this file. Its existence makes “OpenWrt has no restoration” an incorrect argument. |
| [LED hotplug](https://github.com/openwrt/openwrt/blob/74eb10ed5c61feff51f8d6ca6109b94e9c504ec1/package/base-files/files/etc/hotplug.d/leds/00-init) | On `ACTION=add`, runs stock `led start "$DEVICENAME"`. | Respect this ordering before capturing a newly added LED. `S97` solves initial boot ordering only. |
| [LuCI `getLEDs`](https://github.com/openwrt/luci/blob/7dda604a39076d6a17bb2b11e2d0f8faa32aa58c/modules/luci-base/root/usr/share/rpcd/ucode/luci#L176) | Read-only inventory of names, supported/active triggers, brightness and maxima; implemented in luci-base's ucode RPC object. | Reusable by LuCI; not suitable as a mandatory headless snapshot dependency. It does not return trigger-specific settings. |
| [Stock LED Configuration](https://github.com/openwrt/luci/blob/7dda604a39076d6a17bb2b11e2d0f8faa32aa58c/modules/luci-mod-system/htdocs/luci-static/resources/view/system/leds.js#L49) | Edits `form.Map('system')`, `led` sections and trigger plugins using stock inventory. | Keep persistent trigger selection here. A global reversible schedule is not a trigger plugin. |

## Operation-by-operation core matrix

Line numbers refer to the audited project HEAD. `service` below is `core/root/usr/libexec/led-nightmode-service`; `CLI` is `core/root/usr/sbin/led-nightmode`.

| Operation | Current code | Stock counterpart | Decision |
| --- | --- | --- | --- |
| Enumerate LEDs | CLI `command_list` (293), `command_status` (327), `command_night` (371) glob injected sysfs root | Kernel class; LuCI `getLEDs`; stock turnoff loop | Enumeration itself is ordinary plumbing. Headless enumeration stays; optional future UI deduplication is not an upstream blocker. |
| Read attributes/active trigger | CLI `read_led_value` (54), `active_trigger` (63), `trigger_supported` (84) | Same sysfs attributes read by stock init/getLEDs | Justified before snapshot and write validation. |
| Derive night target | CLI `night_target` (360) | `led_off` zero; `led_on` 255 | Own overlay policy: zero for binary/unverified devices by default; explicit multilevel opt-in clamped to max. |
| Write scalar state | CLI `write_value` (100), `write_trigger` (140), night (407–415) | `led_set_attr`, kernel sysfs | Keep direct kernel interface and checked external cat; no broad control API to replace. |
| Capture transaction | CLI `save_state` (242), `save_trigger_attributes` (191) | Stock `led.state` has different lifetime/coverage | Own logic justified; current broad writable-file sweep is not a universal serialization schema. |
| Restore/retry | CLI `load_state` (275), `command_day` (427), `restore_trigger_attributes` (212) | Stock start restores old defaults then applies UCI | Keep per-LED retained recovery state; validate supported settings and ownership. |
| Schedule/phase | service `validate_schedule`, `resolve_fixed`, `resolve_sun`, `apply_phase` (551) | procd supervises; sunwait provides astronomy | Distinct package value. Schedule and phase reconciliation must not be confused with per-device convergence. |
| Stop/reload | service `cleanup` (576); init `start_service`, `service_triggers` | rc.common/procd lifecycle | Keep integration; failed stop retains snapshot but no retry worker remains when disabled. Only `led-nightmode` config reload is registered. |
| RPC/UCI | service `rpc_leds` (241), `rpc_status`, `rpc_set_manual`, dispatch | stock getLEDs overlaps inventory; rpcd/UCI provide transport/config | Narrow API is justified; UCI writes are confined to `led-nightmode`, not `system.led`. `rpc_leds` adapts CLI output, not a second sysfs scan. |
| Provider lifecycle | independent provider runner, init instances, RPC driver/probe/test | No matching LED-class interface for modem AT control | Keep generic optional boundary; no serial dependency or device guessing in core. |

The schedule executable and rpcd object are symlinks to the service executable, not three copies of schedule/control logic. The implementation combines these roles in one file; splitting it for aesthetics is not necessary to resolve this review.

## Restoration semantics and demonstrated gaps

“Normal” needs two distinct meanings: **persistent intent** belongs to `system.led`; **the baseline for a temporary override** is the supported runtime configuration immediately before that override, after stock boot/hotplug configuration. The latter may differ from UCI or may concern an LED absent from UCI.

| Case | Current behaviour | Target contract |
| --- | --- | --- |
| LED absent from UCI | CLI still captures it; stock configuration cannot describe its arbitrary runtime state. | Capture supported runtime state; do not create daily UCI entries. |
| Runtime differs from UCI | Snapshot restores the runtime value, whereas stock reapply chooses UCI. | Preserve pre-overlay runtime unless an explicitly coordinated configuration update supersedes it. |
| Driver defaults/active trigger | Trigger reactivation may determine brightness and lose internal timer phase. | Restore trigger configuration/behaviour, not an exact physical waveform or frozen instantaneous brightness. Exact scalar brightness applies to `none`. |
| Nested USB trigger attributes | `save_trigger_attributes` checks only direct regular files. `usbport` stores selections under `ports/*`, rebuilt from DT defaults on activation. Day can return success and delete snapshot without restoring selections. | Implement a validated USB-port settings schema (including zero selections) or skip the unsupported trigger with an explicit reason before mutation. |
| Arbitrary writable attributes | Read/write permission alone does not prove replay semantics, independence, or safe ordering. | Use a defined trigger-setting schema; do not recursively replay every writable sysfs file as a shortcut. |
| LED added during Night | Successful `apply_phase` sets CURRENT_PHASE; unchanged phase returns immediately. Later LEDs remain unmanaged until another transition/start. | Reconcile new devices after stock hotplug setup; snapshot once per device lifetime. Avoid tearing down/reapplying every trigger on every poll. |
| Missing LED | Day returns failure and retains its state. A running transition loop can retry; an explicit later CLI day can also retry. | Preserve pending recovery and expose it; do not falsely report all devices restored. |
| Same-name replacement | State is keyed only by LED name; a replacement receives the old snapshot. | Detect removal/re-registration and bind records to an observed device generation. A sysfs path alone is not proof of physical identity. On ambiguity retain/report, do not blindly apply. |
| Stop/reload/disable | Normal TERM cleanup restores. CLI has no lock shared between manual invocations and the service. Failed cleanup leaves the record, removes phase, and exits. | Serialize mutating CLI transactions, retain failure diagnostics, distinguish requested phase from pending recovery, and test restart ordering. |
| Crash vs reboot | A same-boot process restart can reuse `/var/run` state. Reboot loses it; S97 captures current-boot defaults after S96. | Promise same-boot sysfs recovery, not reconstruction of pre-reboot transient settings. Do not move generic sysfs snapshots to flash. |
| Stock configuration applied during Night | No system reload coordination. Foreign values remain while phase reports Night; Day later overwrites them with the old snapshot. | Require release → successful restore → stock config apply → fresh capture → resume. Uncoordinated foreign changes must become an ownership conflict rather than silently overwriting either state. |

USB source evidence: [attribute storage](https://github.com/torvalds/linux/blob/adc218676eef25575469234709c2d87185ca223a/drivers/usb/core/ledtrig-usbport.c#L80), [DT-derived defaults](https://github.com/torvalds/linux/blob/adc218676eef25575469234709c2d87185ca223a/drivers/usb/core/ledtrig-usbport.c#L127), and [activation/deactivation](https://github.com/torvalds/linux/blob/adc218676eef25575469234709c2d87185ca223a/drivers/usb/core/ledtrig-usbport.c#L302). Kernel `led_trigger_set` removes attribute groups; the existing regular-file fixtures do not model this lifecycle automatically. A green fixture suite therefore cannot establish restoration for every trigger.

## Provider boundary

The generic runner resolves the shared schedule, launches an explicitly selected executable with endpoint/instance environment, retries failures and invokes day on termination. It does not scan ports. The Quectel package owns picocom, AT parsing, saved two-field state, per-instance serialization, visual testing and write verification. Persistent state under `/etc/led-nightmode/state/providers` is appropriate for hardware whose settings may survive a host reboot. None of this should be translated into stock sysfs calls when no LED-class device exists.

An independent contract defect exists downstream: the Quectel driver's final dispatch recovers `test-ledmode` before **probe or status**, as well as night/day. Thus a supposedly read-only probe can issue a restoring AT write after an interrupted visual test. The fixture probe demonstrates this without a modem. Keep recovery on explicit mutating/recovery paths and have read methods report pending recovery. This provider is excluded from both first upstream PRs, so it is not the explanation for BKPepe's core objection.

## Recommended patch sequence

1. **Define the promise and reposition the package.** Update `README.md`, `docs/architecture/service-and-uci.md`, `docs/compatibility.md`, root `Makefile` and `upstream/packages/Makefile.in` around temporary scheduling + supported runtime restoration. Remove unconditional exact-restore language. Document `none` brightness vs active-trigger behaviour, volatile recovery, supported triggers, and stop/apply/resume for stock configuration. Update stale PR status in `AGENTS.md` as a separate factual documentation edit. Suggested title: `Scheduled LED overrides with state restoration`.
2. **Repair snapshot coverage and transaction safety.** In CLI `save_trigger_attributes`, `restore_trigger_attributes`, `save_state`, `load_state`, `command_night`, `command_day`, add a versioned supported-settings schema, explicit USB `ports/*` handling or preflight exclusion, ordered restore/verification, generation/ownership metadata and one lock shared by mutating CLI callers. Unknown/unrestorable settings must prevent mutation of that LED and be reported; they must not silently earn an exact-restoration claim. Keep the injected sysfs root and external-cat writer. Add missing coverage in `tests/test-cli.sh`.
3. **Reconcile lifecycle and expose incomplete work.** Change service `apply_phase`, its loop, `cleanup` and `rpc_status`; adjust init `start_service`/`service_triggers` and add an ordered LED hotplug integration if needed. Track per-device managed/pending/conflict state; process arrivals after stock setup, retry retained restores, detect external ownership changes, and bound work at shutdown. A bare `system` reload trigger is insufficient: by then stock apply may already have overwritten Night. For the first fix, document and enforce release/apply/resume rather than claiming transparent concurrent editing. Update `tests/test-service.sh` and `tests/test-init.sh`.
4. **Fix the independent provider read contract.** Change the Quectel driver's final command dispatch and recovery entry point; extend `tests/test-modem-provider.sh` to verify `probe`/`status` never write, even with pending `test-ledmode`. Keep explicit recovery available to mutating operations. Describe it in `docs/architecture/providers.md`.

Do not add a mandatory dependency on luci-base just to deduplicate inventory. Keep hardware providers outside the first upstream submissions. A later optional UI-only inventory reuse can be considered separately. No core-only archive, solar split, major rewrite, or `luci-mod-system` integration is required by this audit.

## Validation and limits

Executed successfully: `make test` (including shell syntax and all CLI/init/LuCI-assets/provider/service/staging/UCI-migration suites) and `git diff --check`.

At audit baseline `f2b250f`, the diagnostic `scripts/audit-led-subsystem.py` asserted the limitations below. The follow-up implementation converts it into desired-behavior regressions registered in `make test`. The original diagnostic confirmed:

- omitted nested USB selection with successful snapshot deletion;
- an external value overwritten by the original snapshot;
- volatile-state loss preventing pre-reboot reconstruction;
- same-name replacement receiving a stale snapshot;
- late LED omission and unreconciled external writes during unchanged Night;
- normal service-stop restoration as a control;
- a pending visual-test record making provider probe mutate emulated hardware.

These use temporary regular-file fixtures. The USB case explicitly models the kernel's documented reset of port selection between Night and Day; it is not a kernel execution test. Reboot is simulated by losing the volatile record and supplying a new driver default. No live router, kernel module, real LED, or AT endpoint was touched.

Required regression gates for a patch: trigger deactivate/recreate and nested settings; timer/netdev configuration rather than instantaneous blinking brightness; unsupported/read-only/unavailable attributes; failure retention and retries; concurrent CLI/service calls; hotplug add/remove/replacement after stock configuration; stop/reload/disable and interrupted recovery; external configuration conflict and coordinated baseline refresh; provider read purity. Then run `make check`, `make test`, BusyBox ash validation in the available OpenWrt/container environment and SDK/package checks for a new release. A controlled virtual-kernel LED test should supplement flat-file fixtures; new physical validation still requires an explicit owner request. Existing BPI-R3 Mini evidence remains limited to the recorded scenarios.

## Follow-up correctness implementation

Development main now validates known trigger schemas before mutation, saves nested USB port selections, serializes CLI writers, records snapshot format/identity/transaction stage, and checks the managed Night target before automatic restoration. Reconciliation discovers late LEDs during the same phase. Conflicts and partial restores retain snapshots and surface pending recovery through CLI/rpcd/LuCI; `day --force` is an explicit, identity-checked recovery path. Provider probe/status no longer replay pending visual-test state.

The [restoration contract](restoration-contract.md) defines supported triggers, same-boot scope, upgrade and recovery procedures, and unresolved identity/hotplug/concurrent-writer limits. In particular, path/inode is not a generation cookie and polling is not an ordered stock hotplug hook. These limitations remain explicit; no universal exact restoration or new live-router claim is made. Package descriptions and README now describe temporary scheduling and supported recovery rather than general LED control.

## Proposed response to BKPepe (not posted)

> Thanks, I agree that ordinary LED control and persistent configuration belong to the kernel LED class and OpenWrt's existing LED service. I have narrowed the package description to a scheduled temporary override with restoration of supported pre-override runtime settings. Reapplying stock UCI is not equivalent to that baseline, particularly for runtime settings or LEDs not represented in UCI.
>
> The follow-up also adds known trigger schemas (including nested USB port selections), serialized writes, same-phase discovery, and explicit handling of restoration failures and detected external changes. Unsupported settings are left untouched. The documented guarantee is same-boot configuration restoration for supported devices; it does not promise exact waveform recovery or atomic coordination with arbitrary external writers and hotplug. Regression fixtures cover those boundaries. Would a revised contribution with this narrower scope be appropriate for the feed?
