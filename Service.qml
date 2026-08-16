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
  property int lastChangeEpoch: Schedule.DEFAULTS.lastChangeEpoch
  property var cycle: []
  property int cycleIndex: 0
  property string cycleTheme: ""

  // Live theme + wallpaper state.
  property string currentTheme: ""
  property string currentThemeDisplay: "Unknown"
  property var catalogPaths: []
  property var wallpaperList: []
  property string currentWallpaper: ""
  property int nowEpoch: 0

  // Action state.
  property bool busy: false
  property string pendingWallpaper: ""
  property var pendingNext: null
  property string lastError: ""
  property string lastAction: ""

  readonly property bool shuffle: root.mode === Schedule.MODE_SHUFFLE

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
    if (!root.loaded || root.busy) return
    root.nowEpoch = Date.now()
    if (!root.enabled) return
    if (Schedule.isDue(root.currentConfig(), root.nowEpoch)) root.applyNext()
  }
  function onThemeChanged(slug) {
    var theme = String(slug || "").trim()
    root.currentTheme = theme
    root.currentThemeDisplay = Schedule.wallpaperName(theme) || "Unknown"
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
      if (!root.currentProc.running) root.currentProc.running = true
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
    running: root.loaded
    repeat: true
    // Pure in-memory check; `reconcile` only spawns a process when a scheduled
    // change is actually due (rare), so an idle plugin pays nothing.
    onTriggered: root.reconcile()
  }

  Component.onCompleted: {
    root.nowEpoch = Date.now()
    configDirProcess.running = true
    root.updateCurrent()
    root.refreshCatalog()
  }
}

