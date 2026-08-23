'use strict';
'require form';
'require poll';
'require rpc';
'require ui';
'require view';

const callStatus = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'status'
});

const callDrivers = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'drivers'
});

const callSetManual = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'set_manual',
	params: [ 'phase' ]
});

const callProbe = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'probe',
	params: [ 'driver', 'device', 'instance' ]
});

function phaseLabel(phase) {
	switch (phase) {
	case 'day':
		return _('Day');
	case 'night':
		return _('Night');
	default:
		return _('Unknown');
	}
}

function modeLabel(mode) {
	switch (mode) {
	case 'manual':
		return _('Manual');
	case 'fixed':
		return _('Daily schedule');
	case 'sun':
		return _('Sunrise and sunset');
	default:
		return _('Unknown');
	}
}

function setStatusText(root, name, value) {
	const node = root.querySelector('[data-status="%s"]'.format(name));
	if (node)
		node.textContent = value;
}

function updateStatus(root, status) {
	status = status || {};
	setStatusText(root, 'effective', phaseLabel(status.effective_phase));
	setStatusText(root, 'desired', phaseLabel(status.desired_phase));
	setStatusText(root, 'mode', modeLabel(status.mode));
	setStatusText(root, 'service', status.running ? _('Running') : _('Stopped'));
	setStatusText(root, 'enabled', status.enabled ? _('Enabled') : _('Disabled'));

	const warning = root.querySelector('[data-status="warning"]');
	if (warning) {
		warning.hidden = Boolean(status.enabled && status.running && status.schedule_valid);
		warning.textContent = !status.enabled
			? _('Night mode is disabled. Saving a schedule will not change any LEDs until you enable the service.')
			: (!status.schedule_valid
				? _('The saved schedule is incomplete or invalid. Check the settings below.')
				: _('The service is enabled but is not running.'));
	}
}

function validateTime(sectionId, value) {
	return /^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/.test(value || '')
		? true
		: _('Enter time as HH:MM, for example 23:00.');
}

function coordinateValidator(minimum, maximum) {
	return function(sectionId, value) {
		if (!/^-?[0-9]+(?:\.[0-9]+)?$/.test(value || ''))
			return _('Enter a decimal coordinate, for example 41.7151.');

		const number = Number(value);
		return (number >= minimum && number <= maximum)
			? true
			: _('Value must be between %d and %d.').format(minimum, maximum);
	};
}

return view.extend({
	load: function() {
		return Promise.all([
			L.resolveDefault(callStatus(), {}),
			L.resolveDefault(callDrivers(), { drivers: [] })
		]);
	},

	render: function(data) {
		const initialStatus = data[0] || {};
		const installedDrivers = Array.isArray(data[1] && data[1].drivers)
			? data[1].drivers
			: [];
		let m, s, o;

		m = new form.Map('led-nightmode', _('LED Night Mode'),
			_('Turn router indicators off at night and restore their exact previous state during the day.'));

		const statusNode = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Current state')),
			E('div', {
				'class': 'alert-message warning',
				'data-status': 'warning',
				'hidden': true
			}),
			E('table', { 'class': 'table' }, [
				E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left', 'width': '40%' }, _('LED state now')),
					E('td', { 'class': 'td left' }, E('strong', { 'data-status': 'effective' }, phaseLabel(initialStatus.effective_phase)))
				]),
				E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left' }, _('Schedule wants')),
					E('td', { 'class': 'td left', 'data-status': 'desired' }, phaseLabel(initialStatus.desired_phase))
				]),
				E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left' }, _('Schedule mode')),
					E('td', { 'class': 'td left', 'data-status': 'mode' }, modeLabel(initialStatus.mode))
				]),
				E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left' }, _('Service')),
					E('td', { 'class': 'td left' }, [
						E('span', { 'data-status': 'enabled' }),
						' · ',
						E('span', { 'data-status': 'service' })
					])
				])
			]),
			E('div', { 'class': 'right', 'style': 'margin-top: 1em' }, [
				E('button', {
					'class': 'cbi-button cbi-button-neutral',
					'type': 'button',
					'click': (event) => this.handleManualPhase(statusNode, 'day', event)
				}, _('Switch to day now')),
				' ',
				E('button', {
					'class': 'cbi-button cbi-button-neutral',
					'type': 'button',
					'click': (event) => this.handleManualPhase(statusNode, 'night', event)
				}, _('Switch to night now'))
			])
		]);
		updateStatus(statusNode, initialStatus);

		s = m.section(form.NamedSection, '_status');
		s.render = function() {
			return statusNode;
		};

		s = m.section(form.NamedSection, 'main', 'core', _('General settings'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable LED night mode'),
			_('A fresh installation stays disabled until you turn this on.'));
		o.rmempty = false;

		o = s.option(form.Value, 'night_brightness', _('Night brightness'),
			_('Use 0 to switch LEDs off. Set a non-zero value only after calibrating your hardware: many LEDs are binary even when they report several brightness levels.'));
		o.default = '0';
		o.datatype = 'uinteger';
		o.rmempty = false;

		s = m.section(form.NamedSection, 'schedule', 'schedule', _('Schedule'));
		s.addremove = false;

		const modeOption = s.option(form.ListValue, 'mode', _('Mode'));
		modeOption.value('manual', _('Manual'));
		modeOption.value('fixed', _('Daily schedule'));
		modeOption.value('sun', _('Sunrise and sunset'));
		modeOption.default = 'manual';
		modeOption.rmempty = false;

		o = s.option(form.ListValue, 'phase', _('Manual LED state'));
		o.ucioption = 'phase';
		o.ucisection = 'main';
		o.value('day', _('Day — restore normal indicators'));
		o.value('night', _('Night — apply night brightness'));
		o.depends('mode', 'manual');
		o.rmempty = false;
		this.scheduleMap = m;
		this.modeOption = modeOption;
		this.manualPhaseOption = o;

		const nightStartOption = s.option(form.Value, 'night_start', _('Night starts'));
		nightStartOption.placeholder = '23:00';
		nightStartOption.default = '23:00';
		nightStartOption.validate = validateTime;
		nightStartOption.depends('mode', 'fixed');
		nightStartOption.rmempty = false;

		o = s.option(form.Value, 'day_start', _('Day starts'));
		o.placeholder = '07:00';
		o.default = '07:00';
		o.depends('mode', 'fixed');
		o.rmempty = false;
		o.validate = function(sectionId, value) {
			const valid = validateTime(sectionId, value);
			if (valid !== true)
				return valid;
			return value !== nightStartOption.formvalue(sectionId)
				? true
				: _('Day and night start times must be different.');
		};

		o = s.option(form.Value, 'latitude', _('Latitude'),
			_('Signed decimal degrees from −90 to 90.'));
		o.placeholder = '41.7151';
		o.depends('mode', 'sun');
		o.rmempty = false;
		o.validate = coordinateValidator(-90, 90);

		o = s.option(form.Value, 'longitude', _('Longitude'),
			_('Signed decimal degrees from −180 to 180.'));
		o.placeholder = '44.8271';
		o.depends('mode', 'sun');
		o.rmempty = false;
		o.validate = coordinateValidator(-180, 180);

		o = s.option(form.ListValue, 'twilight', _('Sun boundary'),
			_('Civil twilight usually gives a more natural indoor night-mode transition than the exact horizon crossing.'));
		o.value('daylight', _('Sunrise and sunset'));
		o.value('civil', _('Civil twilight'));
		o.value('nautical', _('Nautical twilight'));
		o.value('astronomical', _('Astronomical twilight'));
		o.default = 'daylight';
		o.depends('mode', 'sun');
		o.rmempty = false;

		s = m.section(form.TypedSection, 'provider', _('External indicators'),
			_('Optional drivers control indicators that do not appear in Linux LED sysfs, such as an LTE light managed by a modem. Nothing is auto-detected or scanned.'));
		s.anonymous = false;
		s.addremove = true;
		s.sectiontitle = function(sectionId) {
			return _('External indicator: %s').format(sectionId);
		};

		const providerEnabledOption = s.option(form.Flag, 'enabled', _('Enable this indicator'));
		providerEnabledOption.rmempty = false;

		const driverOption = s.option(form.Value, 'driver', _('Driver'));
		installedDrivers.forEach(function(driver) {
			driverOption.value(driver, driver);
		});
		driverOption.placeholder = installedDrivers.length ? installedDrivers[0] : _('No provider driver installed');
		driverOption.validate = function(sectionId, value) {
			if (providerEnabledOption.formvalue(sectionId) === '1' && !value)
				return _('Select an installed provider driver.');
			return !value || /^[A-Za-z0-9_-]+$/.test(value)
				? true
				: _('Driver names may contain only letters, numbers, underscores, and hyphens.');
		};

		const deviceOption = s.option(form.Value, 'device', _('Device or endpoint'));
		deviceOption.placeholder = '/dev/ttyUSB3';
		deviceOption.validate = function(sectionId, value) {
			return providerEnabledOption.formvalue(sectionId) !== '1' || value
				? true
				: _('Enter the explicit device or endpoint required by this driver.');
		};

		o = s.option(form.Button, '_probe', _('Connection test'),
			_('Runs the selected driver’s read-only capability check. It does not change the indicator.'));
		o.inputtitle = _('Test connection');
		o.inputstyle = 'apply';
		o.onclick = function(event, sectionId) {
			const button = event.currentTarget;
			const driver = driverOption.formvalue(sectionId);
			const device = deviceOption.formvalue(sectionId);
			if (!driver || !device) {
				ui.addNotification(null, E('p', {}, _('Select a driver and enter its device before testing.')), 'warning');
				return;
			}

			button.disabled = true;
			return L.resolveDefault(callProbe(driver, device, sectionId), {
				success: false,
				message: _('The connection test failed.')
			}).then(function(result) {
				ui.addNotification(null, E('p', {}, result.success
					? _('Connection succeeded. This driver supports the configured endpoint.')
					: (result.message || _('The connection test failed.'))), result.success ? 'info' : 'error');
				button.disabled = false;
			});
		};

		poll.add(function() {
			return L.resolveDefault(callStatus(), {}).then(function(status) {
				updateStatus(statusNode, status);
			});
		}, 5);

		return m.render();
	},

	handleManualPhase: function(statusNode, phase, event) {
		const button = event.currentTarget;
		const modeElement = this.modeOption && this.modeOption.getUIElement('schedule');
		const phaseElement = this.manualPhaseOption && this.manualPhaseOption.getUIElement('schedule');
		const scheduleMap = this.scheduleMap;
		button.disabled = true;
		return L.resolveDefault(callSetManual(phase), {
			success: false,
			message: _('Could not change the LED state.')
		}).then(function(result) {
			if (!result.success) {
				ui.addNotification(null, E('p', {}, result.message || _('Could not change the LED state.')), 'error');
				button.disabled = false;
				return;
			}

			if (modeElement)
				modeElement.setValue('manual');
			if (phaseElement)
				phaseElement.setValue(phase);
			if (scheduleMap)
				scheduleMap.checkDepends();
			ui.addNotification(null, E('p', {}, _('The schedule is now manual and the requested LED state has been applied.')), 'info');
			return L.resolveDefault(callStatus(), {}).then(function(status) {
				updateStatus(statusNode, status);
				button.disabled = false;
			});
		});
	}
});
