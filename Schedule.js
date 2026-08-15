.pragma library

var DEFAULTS = {
  enabled: true,
  intervalMinutes: 30,
  mode: "sequential",
  lastChangeEpoch: 0,
  cycle: [],
  cycleIndex: 0,
  cycleTheme: ""
}

var MODE_SEQUENTIAL = "sequential"
var MODE_SHUFFLE = "shuffle"

function integer(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) && Math.floor(parsed) === parsed ? parsed : fallback
}

function interval(value, fallback) {
  var parsed = integer(value, fallback)
  return parsed >= 1 && parsed <= 1440 ? parsed : fallback
}

function mode(value, fallback) {
  return value === MODE_SHUFFLE ? MODE_SHUFFLE : MODE_SEQUENTIAL
}

function normalize(raw) {
  var source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  return {
    enabled: typeof source.enabled === "boolean" ? source.enabled : DEFAULTS.enabled,
    intervalMinutes: interval(source.intervalMinutes, DEFAULTS.intervalMinutes),
    mode: mode(source.mode, DEFAULTS.mode),
    lastChangeEpoch: integer(source.lastChangeEpoch, DEFAULTS.lastChangeEpoch),
    cycle: Array.isArray(source.cycle) ? source.cycle.slice() : [],
    cycleIndex: integer(source.cycleIndex, DEFAULTS.cycleIndex),
    cycleTheme: typeof source.cycleTheme === "string" ? source.cycleTheme : ""
  }
}

// Parse the catalog script's tab-separated rows "<path>\t<thumbnail path>"
// into an array of { path, thumb }. Blank lines are ignored; a row without a
// thumbnail column falls back to the original path.
function parseWallpaperCatalog(text) {
  var result = []
  var seen = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var fields = lines[i].split("\t")
    var path = String(fields[0] || "").trim()
    if (!path || seen[path]) continue
    seen[path] = true
    var thumb = String(fields[1] || "").trim()
    result.push({ path: path, thumb: thumb || path })
  }
  return result
}

// Turn a wallpaper path into a short, human-readable display name.
function wallpaperName(path) {
  var base = String(path || "").replace(/\\/g, "/").split("/").pop()
  base = base.replace(/\.[^.]+$/, "")
  if (!base) return "Unknown"
  base = base.replace(/[-_.]+/g, " ")
  return base.replace(/\b[a-z]/g, function(letter) { return letter.toUpperCase() })
    .replace(/\s+/g, " ").trim()
}

// Fisher-Yates shuffle. `rng` is optional to support deterministic tests.
function shuffle(values, rng) {
  var a = Array.isArray(values) ? values.slice() : []
  for (var i = a.length - 1; i > 0; i--) {
    var j = Math.floor((rng ? rng() : Math.random()) * (i + 1))
    var t = a[i]
    a[i] = a[j]
    a[j] = t
  }
  return a
}

function sameSet(left, right) {
  if (left.length !== right.length) return false
  var sortedL = left.slice().sort()
  var sortedR = right.slice().sort()
  for (var i = 0; i < sortedL.length; i++)
    if (sortedL[i] !== sortedR[i]) return false
  return true
}

// A persisted shuffle cycle stays valid only while the theme is unchanged and
// the catalog still contains exactly the same paths.
function cycleStillValid(cycle, catalog, cycleTheme, theme) {
  if (cycleTheme !== theme || !Array.isArray(cycle)) return false
  return sameSet(cycle, catalog)
}
// Compute the next wallpaper for the given catalog and current selection. Pure
// and deterministic given a fixed rng. Returns the target path ("" when there
// is nothing to change to) plus the shuffle bookkeeping that must be saved.
//
// Sequential: advance one slot past the current wallpaper, wrapping around.
// Shuffle: step a persisted, never-repeating cycle. The cycle is rebuilt when
// the theme or catalog changes, then resumes from wherever the current
// wallpaper sits so manual picks stay part of the rotation.
function pickNext(config, catalog, currentPath, theme, rng) {
  var paths = Array.isArray(catalog) ? catalog.slice() : []
  if (paths.length === 0)
    return { path: "", cycle: [], cycleIndex: 0, changed: false }

  var cycle
  var cycleIndex

  if (config.mode === MODE_SHUFFLE) {
    if (cycleStillValid(config.cycle, paths, config.cycleTheme, theme)) {
      cycle = config.cycle.slice()
      cycleIndex = config.cycleIndex || 0
    } else {
      cycle = shuffle(paths, rng)
      var idx = currentPath ? cycle.indexOf(currentPath) : -1
      cycleIndex = idx >= 0 ? idx : -1
    }

    if (cycle.length <= 1)
      return { path: "", cycle: cycle, cycleIndex: cycleIndex, changed: false }

    var nextShuffle = (cycleIndex + 1) % cycle.length
    return {
      path: cycle[nextShuffle],
      cycle: cycle,
      cycleIndex: nextShuffle,
      changed: cycle[nextShuffle] !== currentPath
    }
  }

  var at = currentPath ? paths.indexOf(currentPath) : -1
  if (paths.length <= 1)
    return { path: "", cycle: [], cycleIndex: 0, changed: false }
  var nextSeq = at >= 0 ? (at + 1) % paths.length : 0
  return {
    path: paths[nextSeq],
    cycle: [],
    cycleIndex: 0,
    changed: paths[nextSeq] !== currentPath
  }
}

// Is a scheduled change due right now?
function isDue(config, nowEpoch) {
  if (!config.enabled) return false
  var last = config.lastChangeEpoch > 0 ? config.lastChangeEpoch : 0
  var elapsed = nowEpoch - last
  if (elapsed < 0) elapsed = 0
  return elapsed >= (config.intervalMinutes || 0) * 60000
}

// Whole minutes until the next scheduled change (ceil). -1 when automation off.
function minutesUntil(config, nowEpoch) {
  if (!config.enabled) return -1
  var last = config.lastChangeEpoch > 0 ? config.lastChangeEpoch : 0
  var intervalMs = (config.intervalMinutes || 0) * 60000
  var remaining = intervalMs - (nowEpoch - last)
  if (remaining < 1) remaining = 1
  return Math.ceil(remaining / 60000)
}

function modeLabel(modeValue) {
  return modeValue === MODE_SHUFFLE ? "Shuffle" : "Sequential"
}

function intervalLabel(minutes) {
  var value = interval(minutes, 60)
  if (value < 60) return "Every " + value + " min"
  var hours = value / 60
  if (value % 60 === 0) return "Every " + hours + (hours === 1 ? " hour" : " hours")
  return "Every " + value + " min"
}

function intervalOptions() {
  var steps = [5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720, 1440]
  var options = []
  for (var i = 0; i < steps.length; i++) {
    var minutes = steps[i]
    options.push({ value: String(minutes), label: intervalLabel(minutes) })
  }
  return options
}

function modeOptions() {
  return [
    { value: MODE_SEQUENTIAL, label: "Sequential" },
    { value: MODE_SHUFFLE, label: "Shuffle" }
  ]
}

