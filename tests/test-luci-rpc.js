'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'htdocs/luci-static/resources/view/led-nightmode.js'), 'utf8');
const acl = JSON.parse(fs.readFileSync(path.join(root, 'root/usr/share/rpcd/acl.d/luci-app-led-nightmode.json'), 'utf8'))['luci-app-led-nightmode'];
const calls = [];
let stockInventory = {
	'binary': { max_brightness: 1 },
	'multilevel': { max_brightness: 255 },
	'zero': { max_brightness: 0 },
	'unknown': { max_brightness: null }
};
let failInventory = false;
const rpc = {
	declare: spec => () => {
		calls.push(`${spec.object}.${spec.method}`);
		if (spec.object === 'luci' && spec.method === 'getLEDs')
			return failInventory ? Promise.reject(new Error('Access denied')) : Promise.resolve(stockInventory);
		if (spec.method === 'status') return Promise.resolve({ enabled: true });
		if (spec.method === 'drivers') return Promise.resolve({ drivers: [] });
		throw new Error(`Unexpected RPC: ${spec.object}.${spec.method}`);
	}
};
const view = { extend: app => app };
// Expose private presentation helpers only in this test harness.
const instrumented = source.replace('return view.extend({',
	'Object.assign(view, { ledCapabilities, renderBrightnessCapabilities });\nreturn view.extend({');
String.prototype.format = function(...args) {
	let i = 0;
	return this.replace(/%s/g, () => args[i++]);
};
const app = new Function('rpc', 'L', 'view', '_', 'E', instrumented)(
	rpc, { resolveDefault: (promise, fallback) => promise.catch(() => fallback) },
	view, text => text, (tag, attrs, children) => ({ tag, attrs, children }));

(async () => {
	const loaded = await app.load();
	assert.deepEqual(calls, ['luci.led-nightmode.status', 'luci.led-nightmode.drivers', 'luci.getLEDs']);
	assert.deepEqual(view.ledCapabilities(loaded[2]), [
		{ name: 'binary', max_brightness: 1, brightness_model: 'binary' },
		{ name: 'multilevel', max_brightness: 255, brightness_model: 'unverified-multilevel' },
		{ name: 'unknown', max_brightness: null, brightness_model: null },
		{ name: 'zero', max_brightness: 0, brightness_model: 'binary' }
	]);
	const rendered = JSON.stringify(view.renderBrightnessCapabilities(view.ledCapabilities(loaded[2])));
	assert.ok(rendered.includes('0–0'), 'zero maximum must not become unknown');
	assert.ok(rendered.includes('physical dimming unverified'));
	assert.ok(rendered.includes('0–?'));
	for (const malformed of [null, [], 'invalid'])
		assert.deepEqual(view.ledCapabilities(malformed), []);
	for (const maximum of [-1, 1.5, '255', undefined])
		assert.equal(view.ledCapabilities({ test: { max_brightness: maximum } })[0].brightness_model, null);
	const inherited = Object.create({ phantom: { max_brightness: 255 } });
	inherited.real = { max_brightness: 1 };
	assert.equal(view.ledCapabilities(inherited).length, 1);

	stockInventory = {};
	assert.deepEqual(view.ledCapabilities((await app.load())[2]), []);
	failInventory = true;
	const failed = await app.load();
	assert.deepEqual(failed[0], { enabled: true }, 'inventory failure must not hide service status');
	assert.ok(JSON.stringify(view.renderBrightnessCapabilities(view.ledCapabilities(failed[2])))
		.includes('Keeping brightness at 0 is the safe choice'));

	assert.deepEqual(acl.read.ubus, {
		'luci.led-nightmode': ['drivers', 'status'],
		'luci': ['getLEDs']
	});
	assert.deepEqual(acl.write.ubus, { 'luci.led-nightmode': ['probe', 'set_manual', 'test'] });
	console.log('All LuCI RPC integration tests passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
