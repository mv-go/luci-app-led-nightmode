# Temporary LED override and recovery

This contract describes unreleased development `main`, not the published `v0.5.1` binaries. The kernel LED class owns hardware operations; OpenWrt UCI and its stock LED service own persistent configuration. This package temporarily overrides supported runtime settings on a schedule. Reapplying stock UCI is not equivalent to restoring a pre-night runtime snapshot, which can include LEDs not configured in UCI.

## Supported snapshots

Before writing an LED, the CLI validates its trigger and writable attributes. Supported triggers are `none`, `default-on`, `timer`, `heartbeat`, `netdev`, `usbport`, and parameterless `phy*tpt` throughput triggers. Timer delays, heartbeat inversion, known netdev device/link/speed/duplex/activity/interval settings, nested USB port selections, and multicolor `multi_intensity` are saved when exposed. Unknown triggers, unknown writable attributes and unknown attribute directories are rejected before mutation. Other supported LEDs can still enter Night; the overall command returns failure and the service reports an incomplete profile.

Read-only informational files are not replayed. Trigger attributes are restored after activation recreates them. Missing or unwritable saved attributes retain the snapshot and report failure; a matching read-only value needs no write. A dynamic trigger restores configuration and behavior, not waveform phase or its instantaneous brightness.

Snapshots have format `1`, canonical device path, inode, original trigger/brightness, supported attributes, applied target and a managed/pending transaction stage. They live in `/var/run/led-nightmode`: recovery is same-boot only. Boot takes a new baseline after the stock LED service. Existing legacy snapshots without identity cannot be automatically restored by this implementation; stop and restore using the old executable before upgrading during Night.

## Reconciliation and conflicts

Night checks every configured polling interval (15 seconds for manual/fixed; 60 seconds for sun). Already matching LEDs receive no repeated writes; newly discovered supported LEDs get one baseline. A changed target can be applied only while the previous target still matches. A missing device, changed path/inode, unexpected active trigger/brightness, or pending transaction makes reconciliation incomplete and retains the snapshot. Automatic Day/stop preserves detected external changes instead of overwriting them. Other owned LEDs can still be restored.

Path plus inode is a best-effort identity check, not a kernel generation cookie. Inode reuse, external writes that return to the expected value, and changes between checks and writes cannot be detected reliably. Polling does not synchronize with stock hotplug completion. No claim of atomic ownership or guaranteed recovery across device removal/recreation is made. A future coordinated hotplug/generation mechanism needs kernel-backed tests.

Change persistent LED configuration in this order: stop this service and verify successful restoration; apply stock LED configuration; restart this service to capture the new baseline. Do not rely on an extra `system` reload trigger: it cannot impose that order on an already applied stock change.

## Explicit recovery

`led-nightmode status` lists `recovery_pending` records, including missing LEDs. The service publishes an unknown phase plus a `recovery-pending` marker when an apply/restore fails. The rpcd status and LuCI warning retain that indication after a failed stop, including when disabled. A stopped service cannot perform background recovery.

After stopping the service, inspect its saved records and the current hardware configuration. If restoring the saved baseline is the intended action, run `led-nightmode --dry-run --force day`, then `led-nightmode --force day`. The force flag bypasses ownership/pending checks only: it does not bypass device identity, missing attributes or write errors. It is never invoked automatically. Successful service reconciliation clears its recovery marker; after manual recovery, restarting in Day refreshes that status. If the current device/configuration should instead be kept, archive and remove only the reviewed obsolete snapshot before taking a new baseline. Do not feed a stale snapshot into a replacement device.

Mutating CLI calls share a fail-fast `mkdir` lock outside the snapshot directory (`LED_LOCK_DIR`, default `${LED_STATE_DIR}.lock`). This serializes this CLI's writers, not stock or third-party writers. Normal exit and handled signals release it. After SIGKILL, review its `pid` and ensure no writer remains before removing the stale lock; it is not automatically stolen based on a potentially reused PID.

An interrupted or failed restore remains pending and requires explicit recovery. Retention is deliberately stronger than automatic retry through a state that might now belong to another writer.

## Provider reads and validation limits

Quectel `probe` and `status` only query hardware even if an interrupted visual test left `test-ledmode`. They report pending recovery on stderr; `night`, `day`, or an explicit visual test retain their existing recovery behavior.

`make test` includes the restoration regressions in `scripts/audit-led-subsystem.py`. They exercise modeled USB attribute recreation, conflicts, explicit recovery, replacement identity, late discovery, partial restoration, lock exclusion, missing LEDs and provider read purity. Shell fixtures also cover timer/netdev settings and normal service stop/reload scheduling. These are regular-file fixtures, not an execution test of a Linux LED driver. New physical or virtual-kernel validation is still required before broadening hardware guarantees. No new release or router installation is implied by a development build.
