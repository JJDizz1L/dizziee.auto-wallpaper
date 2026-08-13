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

const config = Schedule.normalize({
  enabled: true,
  dayTheme: "White",
  nightTheme: "Tokyo Night",
  dayStart: 420,
  nightStart: 1140
});

eq("day begins inclusively", Schedule.periodAt(new Date(2026, 7, 12, 7, 0), config), "day");
eq("night begins inclusively", Schedule.periodAt(new Date(2026, 7, 12, 19, 0), config), "night");
eq("desired day theme", Schedule.desiredTheme(new Date(2026, 7, 12, 12, 0), config), "White");
eq("desired night theme", Schedule.desiredTheme(new Date(2026, 7, 12, 23, 0), config), "Tokyo Night");
eq("day boundary token", Schedule.boundaryToken(new Date(2026, 7, 12, 8, 0), config), "2026-08-12@day@420");
eq("pre-dawn night uses previous boundary", Schedule.boundaryToken(new Date(2026, 7, 12, 2, 0), config), "2026-08-11@night@1140");
eq("next night boundary", Schedule.nextBoundary(new Date(2026, 7, 12, 12, 0), config), new Date(2026, 7, 12, 19, 0));
eq("next day boundary", Schedule.nextBoundary(new Date(2026, 7, 12, 23, 0), config), new Date(2026, 7, 13, 7, 0));

const overnight = Schedule.normalize({ dayStart: 1200, nightStart: 360 });
eq("overnight day before midnight", Schedule.periodAt(new Date(2026, 7, 12, 23, 0), overnight), "day");
eq("overnight day after midnight", Schedule.periodAt(new Date(2026, 7, 13, 2, 0), overnight), "day");
eq("overnight night", Schedule.periodAt(new Date(2026, 7, 13, 10, 0), overnight), "night");
eq("overnight token crosses date", Schedule.boundaryToken(new Date(2026, 7, 13, 2, 0), overnight), "2026-08-12@day@1200");

eq("invalid values normalize", Schedule.normalize({ enabled: 1, dayStart: -1, nightStart: "x" }), Schedule.DEFAULTS);
eq("equal starts are separated", Schedule.normalize({ dayStart: 60, nightStart: 60 }).nightStart, 780);
eq("quarter-hour options", Schedule.timeOptions(15).length, 96);
eq("time label", Schedule.timeLabel(65), "01:05");
eq("slug display", Schedule.displayTheme("catppuccin-latte\n"), "Catppuccin Latte");

if (failures) process.exit(1);
console.log(`ok - ${checks} schedule checks`);
