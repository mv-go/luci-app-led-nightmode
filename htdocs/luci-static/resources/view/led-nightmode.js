'use strict';
'require form';
'require led-nightmode.zone-coordinates as zoneCoordinates';
'require poll';
'require rpc';
'require ui';
'require uci';
'require view';

const callStatus = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'status'
});

const callDrivers = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'drivers'
});

const callLeds = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'leds'
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

const callTest = rpc.declare({
	object: 'luci.led-nightmode',
	method: 'test',
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

function brightnessModelLabel(model) {
	return model === 'binary'
		? _('Binary — off or on')
		: (model === 'unverified-multilevel'
			? _('Multiple values reported — physical dimming unverified')
			: _('Unknown'));
}

function renderBrightnessCapabilities(leds) {
	const rows = (leds || []).map(function(led) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'data-title': _('LED') }, led.name || _('Unknown')),
			E('td', { 'class': 'td left', 'data-title': _('Reported range') },
				'0–%s'.format(led.max_brightness || '?')),
			E('td', { 'class': 'td left', 'data-title': _('Brightness behaviour') },
				brightnessModelLabel(led.brightness_model))
		]);
	});

	return E('div', { 'class': 'cbi-section' }, [
		E('h3', {}, _('Detected LED brightness capabilities')),
		E('p', {}, _('These are driver-reported ranges, not proof that intermediate values physically dim an LED. Custom values are clamped separately for every LED.')),
		rows.length ? E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th left' }, _('LED')),
				E('th', { 'class': 'th left' }, _('Reported range')),
				E('th', { 'class': 'th left' }, _('Brightness behaviour'))
			])
		].concat(rows)) : E('div', { 'class': 'alert-message warning' },
			_('LED capabilities could not be read. Keeping brightness at 0 is the safe choice.'))
	]);
}

return view.extend({
	load: function() {
		return Promise.all([
			L.resolveDefault(callStatus(), {}),
			L.resolveDefault(callDrivers(), { drivers: [] }),
			L.resolveDefault(callLeds(), { leds: [] })
		]);
	},

	render: function(data) {
		const initialStatus = data[0] || {};
		const installedDrivers = Array.isArray(data[1] && data[1].drivers)
			? data[1].drivers
			: [];
		const discoveredLeds = Array.isArray(data[2] && data[2].leds)
			? data[2].leds
			: [];
		const timezoneCoordinates = zoneCoordinates.lookup(initialStatus.router_zonename);
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
			E('p', { 'style': 'margin-top: 1em' },
				_('Quick actions are saved and applied immediately. They select Manual mode and do not apply other unsaved form edits.')),
			E('div', { 'class': 'right' }, [
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'type': 'button',
					'click': (event) => this.handleManualPhase(statusNode, 'day', event)
				}, _('Switch to day now')),
				' ',
				E('button', {
					'class': 'cbi-button cbi-button-action',
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

		const brightnessModeOption = s.option(form.ListValue, '_brightness_mode', _('Night profile'));
		brightnessModeOption.value('off', _('Off completely — recommended'));
		brightnessModeOption.value('custom', _('Custom raw brightness — advanced'));
		brightnessModeOption.cfgvalue = function(sectionId) {
			return Number(uci.get('led-nightmode', sectionId, 'night_brightness') || 0) > 0
				? 'custom'
				: 'off';
		};
		brightnessModeOption.write = function(sectionId, value) {
			if (value === 'off')
				return uci.set('led-nightmode', sectionId, 'night_brightness', '0');
		};
		brightnessModeOption.remove = function() {};
		brightnessModeOption.rmempty = false;

		const brightnessTargetOption = s.option(form.Value, 'night_brightness', _('Custom raw brightness target'),
			_('A non-zero sysfs value is applied only to LEDs reporting a maximum above 1. It is clamped to each LED’s individual maximum and may still behave as fully on.'));
		brightnessTargetOption.default = '1';
		brightnessTargetOption.datatype = 'uinteger';
		brightnessTargetOption.depends('_brightness_mode', 'custom');
		brightnessTargetOption.rmempty = false;
		brightnessTargetOption.validate = function(sectionId, value) {
			return Number(value) > 0
				? true
				: _('Enter a value greater than 0, or choose “Off completely”.');
		};
		brightnessModeOption.onchange = function(event, sectionId, value) {
			if (value !== 'custom' || Number(brightnessTargetOption.formvalue(sectionId)) > 0)
				return;
			const targetElement = brightnessTargetOption.getUIElement(sectionId);
			if (targetElement)
				targetElement.setValue('1');
		};

		const brightnessNode = renderBrightnessCapabilities(discoveredLeds);
		s = m.section(form.NamedSection, '_brightness_capabilities');
		s.render = function() {
			return brightnessNode;
		};

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

		const latitudeOption = s.option(form.Value, 'latitude', _('Latitude'),
			_('Signed decimal degrees from −90 to 90.'));
		latitudeOption.placeholder = '41.7151';
		latitudeOption.depends('mode', 'sun');
		latitudeOption.rmempty = false;
		latitudeOption.validate = coordinateValidator(-90, 90);
		latitudeOption.cfgvalue = function(sectionId) {
			const saved = uci.get('led-nightmode', sectionId, 'latitude');
			return saved || (timezoneCoordinates ? String(timezoneCoordinates[0]) : '');
		};

		const longitudeOption = s.option(form.Value, 'longitude', _('Longitude'),
			_('Signed decimal degrees from −180 to 180.'));
		longitudeOption.placeholder = '44.8271';
		longitudeOption.depends('mode', 'sun');
		longitudeOption.rmempty = false;
		longitudeOption.validate = coordinateValidator(-180, 180);
		longitudeOption.cfgvalue = function(sectionId) {
			const saved = uci.get('led-nightmode', sectionId, 'longitude');
			return saved || (timezoneCoordinates ? String(timezoneCoordinates[1]) : '');
		};

		o = s.option(form.DummyValue, '_location_hint', _('Approximate location'));
		o.depends('mode', 'sun');
		o.cfgvalue = function() {
			return timezoneCoordinates
				? _('Prefilled from router timezone %s using the representative IANA timezone location. Review or refine it before saving.').format(initialStatus.router_zonename)
				: _('No coordinate hint is available for the router timezone. Enter coordinates manually or use browser location over HTTPS.');
		};

		o = s.option(form.Button, '_browser_location', _('Current device location'),
			_('Ask this browser for a more precise location. Coordinates are placed into the form and are sent only to this router when you save.'));
		o.depends('mode', 'sun');
		o.inputtitle = _('Use current location');
		o.inputstyle = 'apply';
		o.onclick = function(event, sectionId) {
			const button = event.currentTarget;
			if (!window.isSecureContext || !navigator.geolocation) {
				ui.addNotification(null, E('p', {}, _('Browser location requires an HTTPS LuCI session and browser permission. You can keep the approximate timezone coordinates or enter them manually.')), 'warning');
				return;
			}

			button.disabled = true;
			return new Promise(function(resolve) {
				navigator.geolocation.getCurrentPosition(function(position) {
					const latitudeElement = latitudeOption.getUIElement(sectionId);
					const longitudeElement = longitudeOption.getUIElement(sectionId);
					if (latitudeElement)
						latitudeElement.setValue(position.coords.latitude.toFixed(4));
					if (longitudeElement)
						longitudeElement.setValue(position.coords.longitude.toFixed(4));
					ui.addNotification(null, E('p', {}, _('Precise coordinates were added to the form. Use Save & Apply to store them on the router.')), 'info');
					resolve();
				}, function(error) {
					const message = error && error.code === 1
						? _('Location permission was denied. You can keep the approximate timezone coordinates or enter them manually.')
						: _('The browser could not determine this device’s location. You can keep the approximate timezone coordinates or enter them manually.');
					ui.addNotification(null, E('p', {}, message), 'warning');
					resolve();
				}, {
					enableHighAccuracy: false,
					timeout: 10000,
					maximumAge: 300000
				});
			}).then(function() {
				button.disabled = false;
			});
		};

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

		o = s.option(form.Button, '_test', _('Indicator test'),
			_('Temporarily changes the external indicator for three seconds, then restores its exact starting state. Watch the physical indicator while the test runs.'));
		o.inputtitle = _('Test indicator');
		o.inputstyle = 'action';
		o.onclick = function(event, sectionId) {
			const button = event.currentTarget;
			const originalTitle = button.textContent;
			const driver = driverOption.formvalue(sectionId);
			const device = deviceOption.formvalue(sectionId);
			if (!driver || !device) {
				ui.addNotification(null, E('p', {}, _('Select a driver and enter its device before testing.')), 'warning');
				return;
			}

			button.disabled = true;
			button.textContent = _('Testing… watch the indicator');
			return L.resolveDefault(callTest(driver, device, sectionId), {
				success: false,
				message: _('The indicator test failed. Its driver may need manual recovery if restoration also failed.')
			}).then(function(result) {
				ui.addNotification(null, E('p', {}, result.success
					? _('The command round trip succeeded and the original state was restored. If you saw no change, this endpoint may not drive the expected physical indicator.')
					: (result.message || _('The indicator test failed.'))), result.success ? 'info' : 'error');
				button.textContent = originalTitle;
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
			ui.addNotification(null, E('p', {}, _('Manual mode and the requested LED state were saved and applied. Other unsaved form edits were not applied.')), 'info');
			return L.resolveDefault(callStatus(), {}).then(function(status) {
				updateStatus(statusNode, status);
				button.disabled = false;
			});
		});
	}
});
