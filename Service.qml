import QtQuick
import Quickshell
import Quickshell.Io
import "Schedule.js" as Schedule

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy/auto-wallpaper"
  readonly property string configPath: configDir + "/config.json"
  readonly property string themeNamePath: home + "/.local/state/omarchy/current/theme.name"
  readonly property string currentBgLink: home + "/.local/state/omarchy/current/background"
  readonly property string catalogScriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("WallpaperCatalog.sh")).replace(/^file:\/\//, ""))

  // Watched config (mirrors Schedule.DEFAULTS). `enabled` and `intervalMinutes`
  // are literal so the shipped defaults (on, 30-min) always apply for fresh
  // installs and aren't lost to a stale cached Schedule library or a
  // theme-change write that runs before the config file has loaded.
  property bool loaded: false
  property bool enabled: true
  property int intervalMinutes: 30
  property string mode: Schedule.DEFAULTS.mode
  property double lastChangeEpoch: Schedule.DEFAULTS.lastChangeEpoch
  property var cycle: []
  property int cycleIndex: 0
  property string cycleTheme: ""

  // Live theme + wallpaper state.
  property string currentTheme: ""
  property string currentThemeDisplay: "Unknown"
  property var catalogPaths: []
  property var wallpaperList: []
  property string currentWallpaper: ""
  property double nowEpoch: 0

  // Action state.
  property bool busy: false
  property string pendingWallpaper: ""
  property var pendingNext: null
  property string lastError: ""
  property string lastAction: ""

  readonly property bool shuffle: root.mode === Schedule.MODE_SHUFFLE

  // Disk cache of wallpaper catalogs, keyed by theme and kept to the 3 most
  // recently seen: first paint after shell start renders instantly while the
  // background re-list verifies freshness.
  property var catalogCache: ({})

  readonly property string catalogCachePath: {
    var base = Quickshell.env("XDG_CACHE_HOME")
    if (!base) base = Quickshell.env("HOME") + "/.cache"
    return base + "/omarchy/dizziee.auto-wallpaper-catalog.json"
  }

  function applyCatalogCache() {
    var entry = root.catalogCache[root.currentTheme]
    if (!entry || !Array.isArray(entry.items) || entry.items.length === 0) return
    var paths = []
    var list = []
    for (var i = 0; i < entry.items.length; i++) {
      var item = entry.items[i]
      if (!item || !item.path) continue
      paths.push(item.path)
      list.push({
        path: item.path,
        thumb: item.thumb || item.path,
        name: item.name || Schedule.wallpaperName(item.path)
      })
    }
    if (paths.length === 0) return
    root.catalogPaths = paths
    root.wallpaperList = list
    Qt.callLater(root.reconcile)
  }

  function writeCatalogCache() {
    if (!root.currentTheme || root.catalogPaths.length === 0) return
    var items = []
    for (var i = 0; i < root.wallpaperList.length; i++) {
      var w = root.wallpaperList[i]
      if (w && w.path) items.push({ path: w.path, thumb: w.thumb || w.path, name: w.name })
    }
    if (items.length === 0) return
    var next = {}
    for (var k in root.catalogCache) next[k] = root.catalogCache[k]
    next[root.currentTheme] = { at: Date.now(), items: items }
    var keys = Object.keys(next)
    if (keys.length > 3) {
      keys.sort(function(a, b) { return (next[a].at || 0) - (next[b].at || 0) })
      for (var d = 0; d < keys.length - 3; d++) delete next[keys[d]]
    }
    root.catalogCache = next
    try { catalogCacheFile.setText(JSON.stringify({ themes: next })) } catch (e) {}
  }

  function currentConfig() {
    return {
      enabled: root.enabled,
      intervalMinutes: root.intervalMinutes,
      mode: root.mode,
      lastChangeEpoch: root.lastChangeEpoch,
      cycle: root.cycle,
      cycleIndex: root.cycleIndex,
      cycleTheme: root.cycleTheme
    }
  }

  // Public-facing state for the panel and bar.
  function currentWallpaperDisplay() {
    return Schedule.wallpaperName(root.currentWallpaper)
  }

  function applyConfig(text) {
    var parsed = {}
    try { parsed = text && text.trim() ? JSON.parse(text) : {} }
    catch (error) { root.lastError = "Invalid config.json: " + error }
    var config = Schedule.normalize(parsed)
    // A brand-new config has lastChangeEpoch 0; without this, the very first
    // load would be "due" immediately and switch the wallpaper right after
    // install. Start the clock now so the first change waits one full interval.
    if (config.enabled && config.lastChangeEpoch <= 0) config.lastChangeEpoch = Date.now()
    root.enabled = config.enabled
    root.intervalMinutes = config.intervalMinutes
    root.mode = config.mode
    root.lastChangeEpoch = config.lastChangeEpoch
    root.cycle = config.cycle
    root.cycleIndex = config.cycleIndex
    root.cycleTheme = config.cycleTheme
    root.loaded = true
    root.nowEpoch = Date.now()
    Qt.callLater(root.reconcile)
  }

  function saveConfig(patch) {
    var config = root.currentConfig()
    for (var key in patch) config[key] = patch[key]
    config = Schedule.normalize(config)
    var text = JSON.stringify(config, null, 2) + "\n"
    configFile.setText(text)
    root.applyConfig(text)
  }

  function setEnabled(value) {
    root.saveConfig({ enabled: value === true })
    if (value === true) Qt.callLater(root.applyNext)
    else root.lastAction = "Automatic switching disabled"
  }

  function updateSchedule(patch) {
    root.saveConfig(patch)
    root.lastAction = "Schedule saved"
  }

  // Cheap vs. expensive listing. The default path only reads wallpaper
  // paths/thumbnails from disk (needed for scheduling) and performs no cache
  // generation. Thumbnail generation (vips) is deferred until the panel is
  // actually opened so an idle/closed plugin spends ~no resources.
  function refreshCatalog(ensureThumbs) {
    if (ensureThumbs === true) {
      if (!cacheProc.running) cacheProc.running = true
      return
    }
    if (!catalogProc.running) catalogProc.running = true
  }

  function updateCurrent() {
    if (!currentProc.running) currentProc.running = true
  }

  function peekNext() {
    if (!root.enabled) return ""
    var result = Schedule.pickNext(root.currentConfig(), root.catalogPaths,
                                    root.currentWallpaper, root.currentTheme, Math.random)
    return result.path
  }

  function nextText() {
    if (!root.enabled) return "Automatic switching is off"
    var target = root.peekNext()
    if (!target) return "No other wallpaper to show"
    var minutes = Schedule.minutesUntil(root.currentConfig(), root.nowEpoch)
    var prefix = minutes > 0 ? minutes + " min" : "now"
    return "Next in " + prefix + " · " + Schedule.wallpaperName(target)
  }

  function statusText() {
    return "Theme: " + root.currentThemeDisplay
      + " · " + root.catalogPaths.length + " wallpaper"
      + (root.catalogPaths.length === 1 ? "" : "s") + " · "
      + Schedule.modeLabel(root.mode)
  }

  function applyNext() {
    if (root.busy) return
    var result = Schedule.pickNext(root.currentConfig(), root.catalogPaths,
                                    root.currentWallpaper, root.currentTheme, Math.random)
    if (result.changed && result.path) {
      root.pendingWallpaper = result.path
      root.switchTo(result.path, result)
    } else {
      root.lastAction = root.catalogPaths.length > 0
        ? "Already showing the only wallpaper" : "No wallpapers for this theme"
      root.saveConfig({ lastChangeEpoch: Date.now() })
    }
  }

  function setWallpaper(path) {
    if (root.busy || !path) return
    root.switchTo(path, null)
  }

  function switchTo(path, nextResult) {
    var target = String(path || "").trim()
    if (!target) {
      root.lastError = "No wallpaper selected."
      return
    }
    root.pendingWallpaper = target
    root.pendingNext = nextResult
    root.lastError = ""
    setProc.command = ["omarchy-theme-bg-set", target]
    root.busy = true
    setProc.running = true
  }

  function reconcile() {
    if (!root.loaded || root.busy) {
      root.armScheduleTimer()
      return
    }
    root.nowEpoch = Date.now()
    if (!root.enabled) {
      root.armScheduleTimer()
      return
    }
    if (Schedule.isDue(root.currentConfig(), root.nowEpoch)) root.applyNext()
    root.armScheduleTimer()
  }

  function msUntilDue() {
    if (!root.enabled) return -1
    var intervalMs = (root.intervalMinutes || 0) * 60000
    var last = root.lastChangeEpoch > 0 ? root.lastChangeEpoch : 0
    return intervalMs - (Date.now() - last)
  }

  // Wake exactly when the next change is due instead of every minute; a
  // disabled or not-yet-loaded service never wakes. Config edits, theme
  // changes and completed switches all flow back through reconcile(), so the
  // arm stays correct without any other call sites.
  function armScheduleTimer() {
    if (!root.loaded || !root.enabled) {
      scheduleTimer.running = false
      return
    }
    var remaining = root.msUntilDue()
    if (!(remaining > 0)) remaining = 1
    // Floor avoids a hot loop if the clock jumps; the cap bounds one-shot
    // waits for long intervals (up to 24h).
    scheduleTimer.interval = Math.max(10000, Math.min(remaining, 86400000))
    scheduleTimer.restart()
  }

  function onThemeChanged(slug) {
    var theme = String(slug || "").trim()
    root.currentTheme = theme
    root.currentThemeDisplay = Schedule.wallpaperName(theme) || "Unknown"
    // Instant paint from disk while the background re-list runs.
    root.applyCatalogCache()
    // Don't persist on a theme event that races ahead of the config file
    // loading; otherwise in-memory defaults could be written out first and
    // appear to "disable" (or otherwise clobber) saved settings.
    if (!root.loaded) return
    // New theme, new wallpaper set: let the user see it before any scheduled
    // switch, and let pickNext rebuild the shuffle cycle on the next change.
    root.saveConfig({ lastChangeEpoch: Date.now(), cycle: [], cycleTheme: "" })
    root.lastAction = "Theme changed to " + root.currentThemeDisplay
    // Warm thumbnails too: if the panel is open while the theme changes, the
    // grid must not fall back to full-resolution previews.
    root.refreshCatalog(true)
  }

  function onSetExited(exitCode) {
    root.busy = false
    var applied = root.pendingWallpaper
    if (exitCode === 0) {
      root.currentWallpaper = applied
      // Start the next schedule interval and keep the shuffle cycle aligned
      // with whichever wallpaper we just showed.
      var next = root.pendingNext
      var patch = { lastChangeEpoch: Date.now(), cycleTheme: root.currentTheme }
      if (next) {
        patch.cycle = next.cycle
        patch.cycleIndex = next.cycleIndex
      }
      root.saveConfig(patch)
      // Guarded lookup: if the service tree was torn down mid-switch (e.g. a
      // hot reload landing between setProc start and exit), the child is gone
      // and an unguarded read would abort the rest of this handler below.
      var currentReader = root.currentProc
      if (currentReader && !currentReader.running) currentReader.running = true
      root.lastAction = "Wallpaper set to " + Schedule.wallpaperName(applied)
      root.lastError = ""
    } else {
      root.lastError = String(setError.text || "Wallpaper change failed").trim()
    }
    root.pendingWallpaper = ""
    root.pendingNext = null
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
    onFileChanged: reload()
  }

  FileView {
    id: themeNameFile
    path: root.themeNamePath
    watchChanges: true
    printErrors: false
    onLoaded: root.onThemeChanged(text())
    onLoadFailed: root.onThemeChanged("")
    onFileChanged: reload()
  }

  Process {
    id: configDirProcess
    command: ["mkdir", "-p", root.configDir]
  }

  Process {
    id: cacheProc
    command: ["omarchy-theme-bg-cache"]
    onExited: function(exitCode) {
      // Run the list either way; missing thumbnails fall back to the original.
      if (!catalogProc.running) catalogProc.running = true
    }
  }

  Process {
    id: catalogProc
    command: ["bash", root.catalogScriptPath]
    stdout: StdioCollector {
      id: catalogOutput
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: catalogError
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(catalogError.text || "Could not list wallpapers").trim()
        return
      }
      var parsed = Schedule.parseWallpaperCatalog(catalogOutput.text)
      var paths = []
      var list = []
      for (var i = 0; i < parsed.length; i++) {
        var entry = parsed[i]
        if (!entry.path) continue
        paths.push(entry.path)
        list.push({ path: entry.path, thumb: entry.thumb, name: Schedule.wallpaperName(entry.path) })
      }
      root.catalogPaths = paths
      root.wallpaperList = list
      root.writeCatalogCache()
      Qt.callLater(root.reconcile)
    }
  }

  Process {
    id: currentProc
    command: ["readlink", "-f", root.currentBgLink]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text || "").trim()
        root.currentWallpaper = path !== root.currentWallpaper ? path : root.currentWallpaper
      }
    }
  }

  Process {
    id: setProc
    stderr: StdioCollector {
      id: setError
      waitForEnd: true
    }
    onExited: function(exitCode) { root.onSetExited(exitCode) }
  }

  Timer {
    id: scheduleTimer
    interval: 60000
    running: false
    repeat: true
    // Armed by reconcile() to fire exactly when the next change is due;
    // never runs while disabled or unloaded.
    onTriggered: root.reconcile()
  }

  FileView {
    id: catalogCacheFile
    path: root.catalogCachePath
    watchChanges: false
    printErrors: false
    onLoaded: {
      try { root.catalogCache = JSON.parse(String(text() || "{}")).themes || {} } catch (e) {}
      root.applyCatalogCache()
    }
  }

  Component.onCompleted: {
    root.nowEpoch = Date.now()
    configDirProcess.running = true
    root.updateCurrent()
    root.refreshCatalog()
  }
}

