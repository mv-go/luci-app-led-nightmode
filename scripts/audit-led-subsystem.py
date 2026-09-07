"""Audit probes, not production tests. Regular-file sysfs fixtures only."""
import os, pathlib, shutil, subprocess, tempfile, time
project = pathlib.Path(__file__).resolve().parents[1]
cli = project/'core/root/usr/sbin/led-nightmode'
service = project/'core/root/usr/libexec/led-nightmode-service'
def put(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(str(value)+'\n')
def led(root, name, trigger='none', brightness=170):
    p=root/name;p.mkdir(parents=True,exist_ok=True)
    put(p/'brightness',brightness);put(p/'max_brightness',255)
    put(p/'trigger',' '.join(f'[{t}]' if t==trigger else t for t in ['none','usbport','netdev','timer']))
    return p
def env(root):
    return dict(os.environ, LED_SYSFS_ROOT=str(root/'leds'),LED_STATE_DIR=str(root/'state'),LED_SYSFS_EMULATE='1',LED_NIGHTMODE_BIN=str(cli),LED_NIGHTMODE_SCHEDULE_BIN=str(service),LED_NIGHTMODE_RUNTIME_DIR=str(root/'runtime'),LED_SCHEDULE_INTERVAL='0.05')
def run(e,cmd):
    return subprocess.run([str(cli),cmd],env=e,capture_output=True,text=True)
with tempfile.TemporaryDirectory(prefix='led-audit-probes-') as tmp:
    base=pathlib.Path(tmp)
    r=base/'usb';p=led(r/'leds','test','usbport');e=env(r)
    put(p/'ports/usb1-port1',1)
    assert run(e,'night').returncode==0
    assert not (r/'state/test/attributes/ports').exists()
    # Model usbport deactivate/activate rebuilding ports with DT defaults.
    put(p/'ports/usb1-port1',0)
    assert run(e,'day').returncode==0
    assert (p/'ports/usb1-port1').read_text().strip()=='0'
    assert not (r/'state/test').exists()
    print('CONFIRMED: nested usbport selection is not saved; day reports success and deletes snapshot despite loss')
    r=base/'config';p=led(r/'leds','test',brightness=170);e=env(r)
    assert run(e,'night').returncode==0
    put(p/'brightness',70)
    assert run(e,'day').returncode==0
    assert (p/'brightness').read_text().strip()=='170'
    print('CONFIRMED: external runtime/config-apply write (70) is overwritten by pre-night snapshot (170)')
    r=base/'reboot';p=led(r/'leds','test',brightness=170);e=env(r)
    assert run(e,'night').returncode==0
    shutil.rmtree(r/'state')  # Model /var/run loss and driver reboot default.
    put(p/'brightness',42)
    assert run(e,'day').returncode==0
    assert (p/'brightness').read_text().strip()=='42'
    print('CONFIRMED: no pre-reboot exact recovery after volatile state loss; current boot state remains')
    r=base/'same-name';p=led(r/'leds','test',brightness=170);e=env(r)
    assert run(e,'night').returncode==0
    shutil.rmtree(p);p=led(r/'leds','test',brightness=42)
    assert run(e,'day').returncode==0
    assert (p/'brightness').read_text().strip()=='170'
    print('CONFIRMED: same-name replacement receives the previous device snapshot')
    r=base/'hotplug';p=led(r/'leds','old',brightness=170);e=env(r)
    process=subprocess.Popen([str(service),'night','0'],env=e,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
    try:
        deadline=time.monotonic()+10
        while not (r/'runtime/phase').exists():
            assert process.poll() is None
            assert time.monotonic()<deadline
            time.sleep(.02)
        q=led(r/'leds','new',brightness=90)
        time.sleep(.5)
        assert (q/'brightness').read_text().strip()=='90'
        assert not (r/'state/new').exists()
        assert (r/'runtime/phase').read_text().strip()=='night'
        print('CONFIRMED: daemon stays Night but does not discover new LED over multiple schedule polls')
        put(p/'brightness',70)
        time.sleep(.5)
        assert (p/'brightness').read_text().strip()=='70'
        print('CONFIRMED: daemon stays Night but does not reconcile external brightness changes')
    finally:
        process.terminate();_,err=process.communicate(timeout=10)
        assert process.returncode==0,err
    assert (p/'brightness').read_text().strip()=='170'
    print('PASS: ordinary service stop still restores its saved LED')
    r=base/'provider';put(r/'state/test-ledmode','0,0');put(r/'modem','0,1')
    provider=project/'providers/quectel-qnwcfg-ledmode/root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode'
    e=dict(os.environ,LED_PROVIDER_STATE_DIR=str(r/'state'),LED_PROVIDER_LOCK_DIR=str(r/'lock'),LED_QUECTEL_EMULATE_FILE=str(r/'modem'))
    result=subprocess.run([str(provider),'probe'],env=e,capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    assert (r/'modem').read_text().strip()=='0,0'
    print('CONFIRMED: provider probe restores pending visual-test state and therefore can write hardware')
