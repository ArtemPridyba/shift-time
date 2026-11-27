#!/usr/bin/env node
// Checks the web build in a real browser (task Д9, 27.11.2026): serves
// build/web, opens it in Playwright Chromium, walks main menu → Levels → every
// level of the list, and in each level holds Shift, releases it, presses R and
// Esc. Writes a screenshot of every step, the console of the page and a short
// report (time to the menu, file sizes, frames per second of the page).
// With --solution it instead opens the page as index.html?solution=NAME: the
// game itself plays game/tests/solutions/ tick by tick of the physics
// (autoload SolutionReplay, D203), and the check waits for its results in
// window.solutionReplay, with a screenshot every --every seconds.
//
//   node tools/web_check.js                    # every level, build/web
//   node tools/web_check.js --solution chapter # levels 01–05 one after another
//   node tools/web_check.js --solution level_03 --timeout 900
//   node tools/web_check.js --levels 3 --out build/web_check
//
// The build is single-threaded, so no COOP/COEP headers are needed. The
// browser renders WebGL in software (SwiftShader): the frames per second are
// written down but say little about a real computer.
'use strict';
const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const arg = (name, fallback) => {
	const i = args.indexOf(name);
	return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
};
const buildDir = path.resolve(arg('--build', path.join(root, 'build/web')));
const outDir = path.resolve(arg('--out', path.join(root, 'build/web_check')));
const solution = arg('--solution', '');
const port = Number(arg('--port', '8060'));
// The replay: give up after this many seconds, screenshot every this many.
const timeout = Number(arg('--timeout', '1800'));
const every = Number(arg('--every', '30'));

// Keys of game/project.godot, by physical code.
const KEYS = {
	move_left: 'KeyA', move_right: 'KeyD', jump: 'Space', interact: 'KeyE',
	use_item: 'KeyF', rewind: 'ShiftLeft', reset_level: 'KeyR', pause: 'Escape',
};
const MIME = {
	'.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
	'.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml',
	'.json': 'application/json', '.ico': 'image/x-icon',
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = [];
const note = (line) => { console.log(line); log.push(line); };

function serve() {
	const server = http.createServer((req, res) => {
		const file = path.join(buildDir, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
		if (!file.startsWith(buildDir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
			res.writeHead(404);
			res.end();
			return;
		}
		res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
		fs.createReadStream(file).pipe(res);
	});
	return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

async function tap(page, code, ms = 120) {
	await page.keyboard.down(code);
	await sleep(ms);
	await page.keyboard.up(code);
	await sleep(250);
}

async function fps(page, ms = 2000) {
	return page.evaluate((ms) => new Promise((resolve) => {
		let frames = 0;
		const start = performance.now();
		const step = () => {
			frames++;
			if (performance.now() - start < ms) requestAnimationFrame(step);
			else resolve(frames * 1000 / (performance.now() - start));
		};
		requestAnimationFrame(step);
	}), ms);
}

// The game plays the solution itself (?solution=NAME); this waits for the
// results it keeps in window.solutionReplay and screenshots along the way.
async function replay(page, shot, consoleLines) {
	const start = Date.now();
	let state = null;
	let next = 0;
	while ((Date.now() - start) / 1000 < timeout) {
		state = await page.evaluate(() => window.solutionReplay || null);
		const s = (Date.now() - start) / 1000;
		if (s >= next) {
			await shot(`sol_${String(Math.round(s)).padStart(4, '0')}s`);
			next += every;
		}
		if (state && !state.running) break;
		await sleep(2000);
	}
	note(`replay ${solution}: ${((Date.now() - start) / 1000).toFixed(0)} s`);
	for (const line of consoleLines.filter((l) => l.includes('SOLUTION '))) note(`  ${line}`);
	if (!state || state.running) note(`replay ${solution}: did not finish in ${timeout} s`);
	await shot('sol_end');
	return state;
}

// Writes the console and the report; lists errors and warnings.
function finish(consoleLines) {
	fs.writeFileSync(path.join(outDir, 'console.txt'), consoleLines.join('\n') + '\n');
	const bad = consoleLines.filter((l) => /^\[(error|warning|pageerror|requestfailed)\]/.test(l));
	note(`console: ${consoleLines.length} lines, ${bad.length} errors or warnings`);
	for (const l of bad.slice(0, 40)) note(`  ${l}`);
	fs.writeFileSync(path.join(outDir, 'report.txt'), log.join('\n') + '\n');
}

async function main() {
	if (!fs.existsSync(path.join(buildDir, 'index.html'))) {
		console.error(`no build in ${buildDir}: run the web export first (CLAUDE.md, «Commands»)`);
		process.exit(1);
	}
	fs.mkdirSync(outDir, { recursive: true });
	for (const f of fs.readdirSync(buildDir).sort()) {
		note(`file ${f}: ${(fs.statSync(path.join(buildDir, f)).size / 1048576).toFixed(2)} MB`);
	}
	const levels = JSON.parse(fs.readFileSync(path.join(root, 'game/data/levels.json'), 'utf8'));
	const list = (Array.isArray(levels) ? levels : levels.levels || []).filter((e) => e && e.id);
	const count = Math.min(Number(arg('--levels', String(list.length))), list.length);

	const server = await serve();
	const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
	const page = await browser.newPage({ viewport: { width: Number(arg('--width', '1280')), height: Number(arg('--height', '720')) } });
	const consoleLines = [];
	const opened = Date.now();
	page.on('console', (m) => {
		const text = m.text();
		// The replay's results with the time since the page opened.
		consoleLines.push(text.startsWith('SOLUTION ') ? `[${m.type()}] ${text} (${((Date.now() - opened) / 1000).toFixed(0)} s)` : `[${m.type()}] ${text}`);
	});
	page.on('pageerror', (e) => consoleLines.push(`[pageerror] ${e.message}`));
	page.on('requestfailed', (r) => consoleLines.push(`[requestfailed] ${r.url()} ${r.failure() && r.failure().errorText}`));

	const shot = async (name) => page.screenshot({ path: path.join(outDir, `${name}.png`) });
	const t0 = Date.now();
	const query = solution ? `?solution=${encodeURIComponent(solution)}` : '';
	await page.goto(`http://127.0.0.1:${port}/index.html${query}`);
	// Godot removes its status overlay once the engine has started.
	try {
		await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 120000 });
	} catch (e) {
		await shot('00_stuck');
		fs.writeFileSync(path.join(outDir, 'console.txt'), consoleLines.join('\n') + '\n');
		throw e;
	}
	note(`engine started: ${((Date.now() - t0) / 1000).toFixed(1)} s`);
	await sleep(1500);
	note(`menu shown: ${((Date.now() - t0) / 1000).toFixed(1)} s`);
	await page.click('canvas');
	await shot('00_menu');
	note(`fps on the menu: ${(await fps(page)).toFixed(1)}`);

	const openList = async () => {
		await tap(page, 'ArrowDown'); // Start → Levels
		await tap(page, 'Enter');
		await sleep(1200);
	};
	const openLevel = async (index) => {
		for (let i = 0; i < index; i++) await tap(page, 'ArrowDown');
		await tap(page, 'Enter');
	};
	const toList = async () => {
		// Pause menu: Continue, Restart level, Levels, Main menu.
		await tap(page, 'ArrowDown');
		await tap(page, 'ArrowDown');
		await tap(page, 'Enter');
		await sleep(1500);
	};

	if (solution) {
		const state = await replay(page, shot, consoleLines);
		const passed = state ? state.results.filter((r) => r.reached).length : 0;
		note(`replay ${solution}: ${passed} of ${state ? state.results.length : 0} levels reached the exit`);
		finish(consoleLines);
		await browser.close();
		server.close();
		process.exit(state && !state.running && passed === state.results.length && passed > 0 ? 0 : 1);
	}
	await openList();
	await shot('01_levels');
	for (let i = 0; i < count; i++) {
		const id = list[i].id;
		const before = consoleLines.length;
		await openLevel(i);
		await sleep(3500); // fade, title card, fade
		await shot(`${id}_a_start`);
		note(`${id}: fps ${(await fps(page)).toFixed(1)}`);
		await page.keyboard.down('ShiftLeft');
		await sleep(2500);
		await shot(`${id}_b_shift`);
		await sleep(500);
		await page.keyboard.up('ShiftLeft');
		await sleep(1500);
		await shot(`${id}_c_released`);
		await tap(page, 'KeyR');
		await sleep(1500);
		await shot(`${id}_d_reset`);
		await tap(page, 'Escape');
		await sleep(500);
		await shot(`${id}_e_pause`);
		await toList();
		note(`${id}: ${consoleLines.length - before} console lines`);
	}
	await tap(page, 'Escape');
	await sleep(1500);
	await shot('99_menu_again');

	finish(consoleLines);
	await browser.close();
	server.close();
}

main().catch((e) => { console.error(e); process.exit(1); });
