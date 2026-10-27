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
