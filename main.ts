// Milo's Mole Dig — make.fun roblox-game-01 entry (Node 22, stdlib only).
//
// The game lives in this directory as a Rojo project: `rojo build
// default.project.json --output game.rbxl` turns src/ into the place file,
// and this program hands the entry in. It copies the place, the Luau sources,
// the screenshots and PLAY.json into the output directory, then writes
// /output/dossier.json with the kit's vendored library — the same library the
// scorer runs again on what we hand in, so the two must agree byte for byte.
//
// Run it outside the grader with MAKEFUN_OUTPUT_DIR standing in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
//
// What the user still has to do by hand (Roblox Studio does not run on this
// Linux box): open the Rojo project in Studio, play-test it, take 3-4
// screenshots of the start, the climb and the win screen into screenshots/,
// publish the place as Public, and fill PLAY.json with the real place and
// universe ids. Until then the screenshots and entry-link checks stay open.

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

mkdirSync(out, { recursive: true });
mkdirSync(join(out, 'screenshots'), { recursive: true });

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true });

if (existsSync(join(here, 'screenshots'))) {
  cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true });
}

// The caps are the scorer's own (reference/gate.json): text_max_bytes shapes
// the dossier text; the rest refuse an entry the scorer would refuse — more
// than 4 screenshots, one over 256 KiB, a place past 500,000 instances, or
// scripts past 8 MiB of source / 1,048,576 path characters in all.
const dossier = buildDossier(out, {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
});
writeFileSync(join(out, 'dossier.json'), dossier);

const shots = readdirSync(join(out, 'screenshots')).filter((n) => !n.startsWith('.'));
console.log(`handed in: game.rbxl + ${shots.length} screenshot(s) + PLAY.json + dossier.json`);

// The entry is not submittable until a human has published the place and
// captured real screenshots: say so out loud instead of failing silently.
const play = JSON.parse(readFileSync(join(out, 'PLAY.json'), 'utf8')) as { place_id: number };
if (play.place_id === 0) console.log('NOTE: PLAY.json still has the starter zeros — publish the place and fill in the real ids.');
if (shots.length < 3) console.log(`NOTE: only ${shots.length} screenshot(s) — the gate needs 3 or 4 real Studio captures.`);
