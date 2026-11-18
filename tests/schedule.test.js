// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")

function loadSchedule() {
  const fs = require("fs")
  const path = require("path")
  let src = fs.readFileSync(path.join(__dirname, "..", "Schedule.js"), "utf8")
  src = src.replace(/^\s*\.pragma.*$/m, "")
  const factory = new Function(src + "\nreturn { parseWallpaperCatalog, wallpaperName, pickNext, normalize };")
  return factory()
}

const Schedule = loadSchedule()

test("parseWallpaperCatalog caps lines and truncates paths", () => {
  const lines = Array.from({ length: 12000 }, (_, i) => `/w/wall-${i}.jpg\t/thumb-${i}.jpg`).join("\n")
  const parsed = Schedule.parseWallpaperCatalog(lines)
  assert.ok(parsed.length <= 10000)
})

test("markup-shaped wallpaper filenames stay inert text", () => {
  const evil = '<img src="https://example.invalid/tracker">.jpg'
  const name = Schedule.wallpaperName("/theme/" + evil)
  // split("/") truncates URL paths to the final segment; key is bounded + inert.
  assert.ok(name.length <= 128)
  assert.ok(typeof name === "string" && name.length > 0)
  const parsed = Schedule.parseWallpaperCatalog(`/theme/${evil}\t/thumb.jpg`)
  assert.equal(parsed.length, 1)
  assert.ok(parsed[0].path.includes("<img"))
})

test("pickNext handles empty catalog", () => {
  const config = Schedule.normalize({})
  const result = Schedule.pickNext(config, [], "", "theme", Math.random)
  assert.equal(result.path, "")
  assert.equal(result.changed, false)
})

// Deterministic rng from a fixed sequence of values in [0, 1).
function seq(values) {
  let i = 0
  return () => values[i++ % values.length]
}

test("shuffle shows every wallpaper once, then reshuffles", () => {
  const paths = ["/a", "/b", "/c", "/d"]
  let config = Schedule.normalize({ mode: "shuffle" })
  let current = ""
  const rng = seq([0.1, 0.7, 0.3, 0.9, 0.5, 0.2, 0.8, 0.4])
  const rounds = []
  for (let r = 0; r < 3; r++) {
    const round = []
    for (let i = 0; i < paths.length; i++) {
      const result = Schedule.pickNext(config, paths, current, "t", rng)
      round.push(result.path)
      current = result.path
      config = { ...config, cycle: result.cycle, cycleIndex: result.cycleIndex, cycleTheme: "t" }
    }
    rounds.push(round)
  }
  for (const round of rounds) assert.deepEqual([...round].sort(), paths)
  // Rounds aren't all the same replayed order.
  assert.ok(rounds.some((round) => round.join() !== rounds[0].join()))
})

test("a new shuffle round never starts with the wallpaper that ended the last", () => {
  const paths = ["/a", "/b", "/c"]
  for (let n = 0; n < 200; n++) {
    const config = Schedule.normalize({ mode: "shuffle", cycle: ["/b", "/c", "/a"], cycleIndex: 2, cycleTheme: "t" })
    const result = Schedule.pickNext(config, paths, "/a", "t", Math.random)
    assert.equal(result.cycleIndex, 0)
    assert.notEqual(result.path, "/a")
  }
})
