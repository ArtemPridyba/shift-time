#!/usr/bin/env node
// Checks the web build in a real browser (task Д9, 27.11.2026): serves
// build/web, opens it in Playwright Chromium, walks main menu → Levels → every
// level of the list, and in each level holds Shift, releases it, presses R and
// Esc. Writes a screenshot of every step, the console of the page and a short
// report (time to the menu, file sizes, frames per second of the page).
// Optionally plays a solution of game/tests/solutions/ by its segments in real
// time (keys held for ticks / 60 s) and checks that the level list then marks
// the level as passed.
//
//   node tools/web_check.js                    # every level, build/web
//   node tools/web_check.js --solution level_01
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
// Seconds between Enter on a level and its first tick: the screen fades to
// black (fade_seconds of data/menu.json), then the level starts under the title card.
const startDelay = Number(arg('--start-delay', '0.6'));

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

// Holds the solution's actions segment by segment, on an absolute clock so
// the delays of the browser do not add up.
async function playSolution(page, segments, shot) {
	const held = new Set();
	const start = Date.now();
	let ticks = 0;
	for (const seg of segments) {
		const want = new Set((seg.actions || []).map((a) => KEYS[a]).filter(Boolean));
		for (const code of held) if (!want.has(code)) { await page.keyboard.up(code); held.delete(code); }
		for (const code of want) if (!held.has(code)) { await page.keyboard.down(code); held.add(code); }
		ticks += Number(seg.ticks);
		const wait = start + ticks * 1000 / 60 - Date.now();
		if (wait > 0) await sleep(wait);
		if (shot) await shot(`sol_t${String(ticks).padStart(5, '0')}`);
	}
	for (const code of held) await page.keyboard.up(code);
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
	const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'].concat(args.includes('--autoplay') ? ['--autoplay-policy=no-user-gesture-required'] : ['--autoplay-policy=user-gesture-required']), ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] });
	const page = await browser.newPage({ viewport: { width: Number(arg('--width', '1280')), height: Number(arg('--height', '720')) } });
	// Sound probe: Web Audio is wrapped before the game starts, so the report
	// says whether the context runs and how many sounds really started
	// (Godot plays samples as AudioBufferSourceNode on the web).
	await page.addInitScript(() => {
		const a = (window.__audio = { contexts: [], starts: 0, decoded: 0, decodeErrors: 0, worklets: 0 });
		const Base = window.AudioContext;
		if (!Base) return;
		window.AudioContext = class extends Base {
			constructor(...args) { super(...args); a.contexts.push(this); }
		};
		const start = AudioBufferSourceNode.prototype.start;
		AudioBufferSourceNode.prototype.start = function (...args) { a.starts++; return start.apply(this, args); };
		const decode = BaseAudioContext.prototype.decodeAudioData;
		BaseAudioContext.prototype.decodeAudioData = function (...args) {
			const p = decode.apply(this, args);
			p.then(() => a.decoded++, () => a.decodeErrors++);
			return p;
		};
		const add = AudioWorklet.prototype.addModule;
		AudioWorklet.prototype.addModule = function (...args) { a.worklets++; return add.apply(this, args); };
	});
	const audio = async (label) => {
		const r = await page.evaluate(() => {
			const a = window.__audio || { contexts: [] };
			return { states: a.contexts.map((c) => c.state), starts: a.starts, decoded: a.decoded, decodeErrors: a.decodeErrors, worklets: a.worklets };
		});
		note(`audio ${label}: contexts [${r.states.join(', ')}], worklets ${r.worklets}, decoded ${r.decoded}, decode errors ${r.decodeErrors}, sounds started ${r.starts}`);
	};
	const consoleLines = [];
	page.on('console', (m) => consoleLines.push(`[${m.type()}] ${m.text()}`));
	page.on('pageerror', (e) => consoleLines.push(`[pageerror] ${e.message}`));
	page.on('requestfailed', (r) => consoleLines.push(`[requestfailed] ${r.url()} ${r.failure() && r.failure().errorText}`));

	const shot = async (name) => page.screenshot({ path: path.join(outDir, `${name}.png`) });
	const t0 = Date.now();
	await page.goto(`http://127.0.0.1:${port}/index.html`);
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
	await audio('before the first click');
	await page.click('canvas');
	await sleep(500);
	await audio('after the first click');
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
		const sol = JSON.parse(fs.readFileSync(path.join(root, 'game/tests/solutions', solution.replace(/\.json$/, '') + '.json'), 'utf8'));
		const index = list.findIndex((e) => e.id === sol.level);
		await openList();
		await openLevel(index);
		await sleep(startDelay * 1000);
		const s = Date.now();
		await playSolution(page, sol.segments, args.includes('--steps') ? shot : null);
		note(`solution ${solution}: played ${((Date.now() - s) / 1000).toFixed(1)} s`);
		await shot(`sol_${solution}_end`);
		await sleep(4000); // the passage to the next level
		await shot(`sol_${solution}_after`);
		await tap(page, 'Escape');
		await toList();
		await shot(`sol_${solution}_list`);
	} else {
		await openList();
	}
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
		await audio(`after ${id}`);
	}
	await tap(page, 'Escape');
	await sleep(1500);
	await shot('99_menu_again');

	fs.writeFileSync(path.join(outDir, 'console.txt'), consoleLines.join('\n') + '\n');
	const bad = consoleLines.filter((l) => /^\[(error|warning|pageerror|requestfailed)\]/.test(l));
	note(`console: ${consoleLines.length} lines, ${bad.length} errors or warnings`);
	for (const l of bad.slice(0, 40)) note(`  ${l}`);
	fs.writeFileSync(path.join(outDir, 'report.txt'), log.join('\n') + '\n');
	await browser.close();
	server.close();
}

main().catch((e) => { console.error(e); process.exit(1); });
