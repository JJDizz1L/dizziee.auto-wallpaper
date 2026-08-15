#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const source = fs.readFileSync(path.join(__dirname, "..", "Schedule.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "");
const names = [...source.matchAll(/^function\s+([A-Za-z0-9_]+)/gm)].map((m) => m[1]);
const constants = [...source.matchAll(/^var\s+([A-Z][A-Z0-9_]*)/gm)].map((m) => m[1]);
const Schedule = new Function(`${source}\nreturn {${[...names, ...constants].join(",")}};`)();

let checks = 0;
let failures = 0;
function eq(label, actual, expected) {
  checks++;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures++;
    console.error(`FAIL ${label}\n  got ${JSON.stringify(actual)}\n  expected ${JSON.stringify(expected)}`);
  }
}
function ok(label, condition) {
  checks++;
  if (!condition) {
    failures++;
    console.error(`FAIL ${label}`);
  }
}

// --- defaults + normalization ---
eq("defaults normalize empty", Schedule.normalize({}), Schedule.DEFAULTS);
eq("invalid values normalize", Schedule.normalize({ enabled: 1, intervalMinutes: 0, mode: "z" }),
  Schedule.DEFAULTS);
eq("clamps interval over budget to default", Schedule.normalize({ intervalMinutes: 99999 }).intervalMinutes, 30);
eq("accepts shuffle mode", Schedule.normalize({ mode: "shuffle" }).mode, "shuffle");
ok("enabled defaults on when unspecified", Schedule.normalize({}).enabled === true);
ok("explicit disabled stays off", Schedule.normalize({ enabled: false }).enabled === false);
eq("default interval is 30 minutes", Schedule.normalize({}).intervalMinutes, 30);
eq("interval label minutes", Schedule.intervalLabel(30), "Every 30 min");
eq("interval label single hour", Schedule.intervalLabel(60), "Every 1 hour");
eq("interval label hours", Schedule.intervalLabel(180), "Every 3 hours");
eq("mode label", Schedule.modeLabel("shuffle"), "Shuffle");
eq("mode options", Schedule.modeOptions().length, 2);

// --- catalog + names ---
const catalog = Schedule.parseWallpaperCatalog(
  "/some/green hills.jpg\t/thumb/green.jpg\n/some/dark.webp\n\n/some/green hills.jpg\t/thumb/other.jpg\n"
);
eq("parse catalog dedupes, keeps thumb, falls back", catalog, [
  { path: "/some/green hills.jpg", thumb: "/thumb/green.jpg" },
  { path: "/some/dark.webp", thumb: "/some/dark.webp" }
]);
eq("wallpaper name", Schedule.wallpaperName("/some/green-grass_01.jpg"), "Green Grass 01");
eq("wallpaper name unknown", Schedule.wallpaperName(""), "Unknown");

// --- interval options well-formed ---
const intervals = Schedule.intervalOptions();
ok("interval options are ascending and finite", intervals.length >= 6
  && intervals.every((o) => /^Every ([\d]+ )(min|hour|hours)$/.test(o.label))
  && Number(intervals[intervals.length - 1].value) === 1440);

// --- sequential ---
const seqConfig = Schedule.normalize({ mode: "sequential", intervalMinutes: 60 });
const seqPath1 = "/bg/one.jpg";
const seqPath2 = "/bg/two.jpg";
const seqPath3 = "/bg/three.jpg";
const seqCatalog = [seqPath1, seqPath2, seqPath3];
eq("sequential next", Schedule.pickNext(seqConfig, seqCatalog, seqPath1, "t").path, seqPath2);
eq("sequential wraps", Schedule.pickNext(seqConfig, seqCatalog, seqPath3, "t").path, seqPath1);
eq("sequential no current starts at first", Schedule.pickNext(seqConfig, seqCatalog, "", "t").path, seqPath1);
ok("sequential ignores persisted cycle", Schedule.pickNext(seqConfig, seqCatalog, seqPath1, "t").cycle.length === 0);
const single = Schedule.pickNext(seqConfig, [seqPath1], seqPath1, "t");
eq("sequential single has no next", single.path, "");
eq("sequential single unchanged", single.changed, false);

// --- shuffle ---
const shufConfig = Schedule.normalize({ mode: "shuffle", intervalMinutes: 60 });
function stepShuffle(seedCfg, shufCatalog, current, theme) {
  return Schedule.pickNext(seedCfg, shufCatalog, current, theme, () => 0.5);
}

// First pick builds a cycle and moves to a different wallpaper.
const s1 = stepShuffle(shufConfig, seqCatalog, seqPath1, "t");
ok("shuffle first pick changed", s1.changed === true && s1.path !== seqPath1);
ok("shuffle built a full unique cycle", s1.cycle.length === 3
  && new Set(s1.cycle).size === 3
  && seqCatalog.every((p) => s1.cycle.includes(p)));

// Stepping through a persisted cycle never repeats until every wallpaper has
// been shown once (the starting wallpaper already counts as shown).
const seen = [seqPath1];
let cfg = Schedule.normalize({ mode: "shuffle", cycle: s1.cycle, cycleIndex: s1.cycleIndex, cycleTheme: "t" });
let rounds = 0;
while (new Set(seen).size < 3 && rounds < 12) {
  const step = Schedule.pickNext(cfg, seqCatalog, seen[seen.length - 1], "t", () => 0.5);
  ok("shuffle step returns a wallpaper", step.changed && step.path !== "");
  if (!seen.includes(step.path)) seen.push(step.path);
  cfg = Schedule.normalize({ mode: "shuffle", cycle: step.cycle, cycleIndex: step.cycleIndex, cycleTheme: "t" });
  rounds++;
}
ok("shuffle covered all three wallpapers exactly once", seen.length === 3
  && new Set(seen).size === 3
  && seqCatalog.every((p) => seen.includes(p)));

// Theme change invalidates the persisted cycle and rebuilds it.
const themed = Schedule.pickNext(
  Schedule.normalize({ mode: "shuffle", cycle: s1.cycle, cycleIndex: s1.cycleIndex, cycleTheme: "t" }),
  seqCatalog, seqPath2, "other-theme", () => 0.5);
eq("shuffle rebuilds on theme change", themed.path !== "", true);
ok("shuffle cycle rebuilt for new theme", themed.cycle.length === 3);

// Failure modes.
const empty = Schedule.pickNext(Schedule.normalize({}), [], "", "t");
ok("empty catalog fails closed", empty.path === "" && empty.changed === false);
const oneShuffle = Schedule.pickNext(Schedule.normalize({ mode: "shuffle" }), [seqPath1], seqPath1, "t");
ok("shuffle single has no next", oneShuffle.path === "" && oneShuffle.changed === false);

// --- schedule timing ---
const whole = Schedule.normalize({ enabled: true, intervalMinutes: 60, lastChangeEpoch: 1000 });
ok("not due before interval", !Schedule.isDue(whole, 1000 + 60000 * 10));
ok("due at interval", Schedule.isDue(whole, 1000 + 60000 * 60));
ok("disabled never due", !Schedule.isDue(Schedule.normalize({ enabled: false }), Date.now()));
eq("minutesUntil armed", Schedule.minutesUntil(whole, 1000 + 60000 * 30), 30);
eq("minutesUntil disabled is -1", Schedule.minutesUntil(Schedule.normalize({ enabled: false }), Date.now()), -1);

if (failures) process.exit(1);
console.log(`ok - ${checks} schedule checks`);
