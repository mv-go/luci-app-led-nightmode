"""Restoration regressions: regular-file fixtures, not execution in a kernel."""
import os
import pathlib
import subprocess
import tempfile
import time

project = pathlib.Path(__file__).resolve().parents[1]
cli = project / 'core/root/usr/sbin/led-nightmode'
service = project / 'core/root/usr/libexec/led-nightmode-service'
provider = project / 'providers/quectel-qnwcfg-ledmode/root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode'


def put(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(str(value) + '\n')


def value(path):
    return path.read_text().strip()


def led(root, name='test', trigger='none', brightness=170):
    path = root / 'leds' / name
    path.mkdir(parents=True)
    put(path / 'brightness', brightness)
    put(path / 'max_brightness', 255)
    put(path / 'trigger', ' '.join(f'[{t}]' if t == trigger else t
                                  for t in ['none', 'usbport', 'netdev', 'timer', 'pattern']))
    return path


def env(root):
    return dict(os.environ, LED_SYSFS_ROOT=str(root / 'leds'),
                LED_STATE_DIR=str(root / 'state'), LED_SYSFS_EMULATE='1',
                LED_NIGHTMODE_BIN=str(cli), LED_NIGHTMODE_SCHEDULE_BIN=str(service),
                LED_NIGHTMODE_RUNTIME_DIR=str(root / 'runtime'), LED_SCHEDULE_INTERVAL='0.05')


def run(environment, *args):
    return subprocess.run([str(cli), *args], env=environment, capture_output=True, text=True)


def wait_until(predicate, process):
    deadline = time.monotonic() + 10
    while not predicate():
        assert process.poll() is None
        assert time.monotonic() < deadline, 'timed out waiting for service reconciliation'
        time.sleep(.02)


with tempfile.TemporaryDirectory(prefix='led-regressions-') as tmp:
    base = pathlib.Path(tmp)
    root = base / 'usb'
    path = led(root, trigger='usbport')
    environment = env(root)
    put(path / 'ports/usb1-port1', 1)
    assert run(environment, 'night').returncode == 0
    assert value(root / 'state/test/attributes/ports/usb1-port1') == '1'
    # Model trigger deactivation and reactivation rebuilding USB ports with defaults.
    put(path / 'ports/usb1-port1', 0)
    assert run(environment, 'day').returncode == 0
    assert value(path / 'ports/usb1-port1') == '1'
    assert not (root / 'state/test').exists()
    print('PASS: nested USB port selection restored after modeled attribute recreation')

    root = base / 'conflict'
    path = led(root)
    environment = env(root)
    assert run(environment, 'night').returncode == 0
    put(path / 'brightness', 70)
    assert run(environment, 'night').returncode != 0
    assert run(environment, 'day').returncode != 0
    assert value(path / 'brightness') == '70'
    assert 'recovery_pending' in run(environment, 'status').stdout
    assert run(environment, 'day', '--force').returncode == 0
    assert value(path / 'brightness') == '170'
    print('PASS: foreign state preserved; explicit recovery restores the reviewed baseline')

    root = base / 'same-name'
    path = led(root)
    environment = env(root)
    assert run(environment, 'night').returncode == 0
    # Keep the old directory alive so the fixture guarantees a different inode.
    path.rename(root / 'detached')
    path = led(root, brightness=42)
    assert run(environment, 'day').returncode != 0
    assert run(environment, 'day', '--force').returncode != 0
    assert value(path / 'brightness') == '42'
    print('PASS: replacement identity rejects stale snapshot even with forced recovery')

    root = base / 'hotplug'
    path = led(root, name='old')
    environment = env(root)
    process = subprocess.Popen([str(service), 'night', '0'], env=environment,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    try:
        wait_until(lambda: (root / 'runtime/phase').exists(), process)
        late = led(root, name='new', brightness=90)
        wait_until(lambda: value(late / 'brightness') == '0', process)
        wait_until(lambda: (root / 'state/new/target').exists(), process)
        put(path / 'brightness', 70)
        wait_until(lambda: (root / 'runtime/recovery-pending').exists(), process)
        assert value(root / 'runtime/phase') == 'unknown'
        assert value(path / 'brightness') == '70'
    finally:
        process.terminate()
        _, errors = process.communicate(timeout=10)
    assert process.returncode != 0, errors
    assert value(path / 'brightness') == '70'
    assert value(late / 'brightness') == '90'
    assert (root / 'runtime/recovery-pending').exists()
    print('PASS: same-phase arrival reconciled; conflicts visible and preserved during stop')

    root = base / 'provider'
    put(root / 'state/test-ledmode', '0,0')
    put(root / 'modem', '0,1')
    environment = dict(os.environ, LED_PROVIDER_STATE_DIR=str(root / 'state'),
                       LED_PROVIDER_LOCK_DIR=str(root / 'lock'),
                       LED_QUECTEL_EMULATE_FILE=str(root / 'modem'))
    for command in ['probe', 'status']:
        result = subprocess.run([str(provider), command], env=environment, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        assert 'recovery pending' in result.stderr
        assert value(root / 'modem') == '0,1'
        assert (root / 'state/test-ledmode').exists()
    result = subprocess.run([str(provider), 'day'], env=environment, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert value(root / 'modem') == '0,0'
    print('PASS: probe/status do not restore pending test; mutating day does')

    for trigger, attribute in [('none', 'custom_action'), ('pattern', None)]:
        root = base / ('unsupported-' + trigger)
        path = led(root, trigger=trigger)
        environment = env(root)
        if attribute:
            put(path / attribute, 1)
        assert run(environment, 'night').returncode != 0
        assert value(path / 'brightness') == '170'
        assert not (root / 'state/test').exists()
    print('PASS: unknown trigger and writable ABI rejected before mutation')

    root = base / 'partial'
    path = led(root, trigger='usbport')
    environment = env(root)
    put(path / 'ports/usb1-port1', 1)
    assert run(environment, 'night').returncode == 0
    (path / 'ports/usb1-port1').unlink()
    assert run(environment, 'day').returncode != 0
    assert (root / 'state/test').exists()
    put(path / 'ports/usb1-port1', 0)
    assert run(environment, 'day').returncode != 0
    assert run(environment, 'day', '--force').returncode == 0
    assert value(path / 'ports/usb1-port1') == '1'
    print('PASS: partial restore retains snapshot and needs explicit retry')

    root = base / 'lock'
    path = led(root)
    environment = env(root)
    (root / 'state.lock').mkdir()
    assert run(environment, 'night').returncode != 0
    assert value(path / 'brightness') == '170'
    assert run(environment, 'list').returncode == 0
    (root / 'state.lock').rmdir()
    assert run(environment, 'night').returncode == 0
    assert not (root / 'state.lock').exists()
    path.rename(root / 'detached')
    assert run(environment, 'night').returncode != 0
    assert 'recovery_pending' in run(environment, 'status').stdout
    print('PASS: lock excludes mutations; missing managed LED remains visible')

    for trigger, attributes in [('timer', {'delay_on': 73, 'delay_off': 91}),
                                ('heartbeat', {'invert': 1}),
                                ('none', {'multi_intensity': '10 20 30'})]:
        root = base / ('settings-' + trigger)
        path = led(root, trigger=trigger)
        if trigger == 'heartbeat':
            put(path / 'trigger', 'none [heartbeat]')
        environment = env(root)
        for name, setting in attributes.items():
            put(path / name, setting)
        assert run(environment, 'night').returncode == 0
        for name in attributes:
            put(path / name, 0)
        assert run(environment, 'day').returncode == 0
        for name, setting in attributes.items():
            assert value(path / name) == str(setting)
    print('PASS: timer, heartbeat and multicolor settings restored')

    root = base / 'target-change'
    path = led(root)
    environment = env(root)
    assert run(environment, 'night').returncode == 0
    assert run(dict(environment, LED_NIGHT_BRIGHTNESS='7'), 'night').returncode == 0
    assert value(path / 'brightness') == '7'
    assert value(root / 'state/test/brightness') == '170'
    assert run(environment, 'day').returncode == 0
    assert value(path / 'brightness') == '170'
    print('PASS: deliberate target change preserves original baseline')
