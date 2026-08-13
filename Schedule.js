.pragma library

var DEFAULTS = {
  enabled: false,
  dayTheme: "Flexoki Light",
  nightTheme: "Matte Black",
  dayStart: 420,
  nightStart: 1140,
  lastHandledBoundary: ""
}

function integer(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) && Math.floor(parsed) === parsed ? parsed : fallback
}

function minute(value, fallback) {
  var parsed = integer(value, fallback)
  return parsed >= 0 && parsed < 1440 ? parsed : fallback
}

function themeName(value, fallback) {
  var name = typeof value === "string" ? value.trim() : ""
  return name.length ? name : fallback
}

function normalize(raw) {
  var source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  var dayStart = minute(source.dayStart, DEFAULTS.dayStart)
  var nightStart = minute(source.nightStart, DEFAULTS.nightStart)
  if (dayStart === nightStart) nightStart = (dayStart + 720) % 1440

  return {
    enabled: source.enabled === true,
    dayTheme: themeName(source.dayTheme, DEFAULTS.dayTheme),
    nightTheme: themeName(source.nightTheme, DEFAULTS.nightTheme),
    dayStart: dayStart,
    nightStart: nightStart,
    lastHandledBoundary: typeof source.lastHandledBoundary === "string"
      ? source.lastHandledBoundary : ""
  }
}

function pad(value) {
  return String(value).padStart(2, "0")
}

function timeLabel(minutes) {
  var value = minute(minutes, 0)
  return pad(Math.floor(value / 60)) + ":" + pad(value % 60)
}

function minuteOfDay(date) {
  return date.getHours() * 60 + date.getMinutes()
}

function isDayAt(minutes, dayStart, nightStart) {
  if (dayStart < nightStart) return minutes >= dayStart && minutes < nightStart
  return minutes >= dayStart || minutes < nightStart
}

function periodAt(date, config) {
  var normalized = normalize(config)
  return isDayAt(minuteOfDay(date), normalized.dayStart, normalized.nightStart)
    ? "day" : "night"
}

function desiredTheme(date, config) {
  var normalized = normalize(config)
  return periodAt(date, normalized) === "day"
    ? normalized.dayTheme : normalized.nightTheme
}

function localDateKey(date) {
  return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
}

function boundaryDate(date, config) {
  var normalized = normalize(config)
  var period = periodAt(date, normalized)
  var start = period === "day" ? normalized.dayStart : normalized.nightStart
  var boundary = new Date(date.getFullYear(), date.getMonth(), date.getDate(),
                          Math.floor(start / 60), start % 60, 0, 0)
  if (boundary.getTime() > date.getTime()) boundary.setDate(boundary.getDate() - 1)
  return boundary
}

function boundaryToken(date, config) {
  var normalized = normalize(config)
  var period = periodAt(date, normalized)
  var start = period === "day" ? normalized.dayStart : normalized.nightStart
  return localDateKey(boundaryDate(date, normalized)) + "@" + period + "@" + start
}

function nextBoundary(date, config) {
  var normalized = normalize(config)
  var period = periodAt(date, normalized)
  var start = period === "day" ? normalized.nightStart : normalized.dayStart
  var next = new Date(date.getFullYear(), date.getMonth(), date.getDate(),
                      Math.floor(start / 60), start % 60, 0, 0)
  if (next.getTime() <= date.getTime()) next.setDate(next.getDate() + 1)
  return next
}

function nextSwitchText(date, config) {
  var normalized = normalize(config)
  if (!normalized.enabled) return "Automation is off"
  var next = nextBoundary(date, normalized)
  var nextTheme = periodAt(date, normalized) === "day"
    ? normalized.nightTheme : normalized.dayTheme
  var dayOffset = new Date(next.getFullYear(), next.getMonth(), next.getDate()).getTime()
    - new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
  var prefix = dayOffset >= 86400000 ? "Tomorrow at " : "Today at "
  return prefix + timeLabel(next.getHours() * 60 + next.getMinutes()) + " · " + nextTheme
}

function timeOptions(step) {
  var interval = integer(step, 15)
  if (interval <= 0 || interval > 720) interval = 15
  var options = []
  for (var value = 0; value < 1440; value += interval)
    options.push({ value: String(value), label: timeLabel(value) })
  return options
}

function displayTheme(value) {
  var text = String(value || "").trim().replace(/-/g, " ")
  if (!text) return "Unknown"
  return text.replace(/(^|\s)([a-z])/g, function(_, space, letter) {
    return space + letter.toUpperCase()
  })
}
