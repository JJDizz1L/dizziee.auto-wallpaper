import QtQuick
import Quickshell
import Quickshell.Io
import "Schedule.js" as Schedule

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy/theme-scheduler"
  readonly property string configPath: configDir + "/config.json"
  readonly property string currentThemePath: home + "/.local/state/omarchy/current/theme.name"
  readonly property string themeCatalogScriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("ThemeCatalog.sh")).replace(/^file:\/\//, ""))

  property bool loaded: false
  property bool enabled: false
  property string dayTheme: Schedule.DEFAULTS.dayTheme
  property string nightTheme: Schedule.DEFAULTS.nightTheme
  property int dayStart: Schedule.DEFAULTS.dayStart
  property int nightStart: Schedule.DEFAULTS.nightStart
  property string lastHandledBoundary: ""

  property var themes: []
  readonly property var dayThemeOptions: Schedule.themeOptions(themes, Schedule.RANDOM_LIGHT)
  readonly property var nightThemeOptions: Schedule.themeOptions(themes, Schedule.RANDOM_DARK)
  property string currentTheme: "Unknown"
  property date now: new Date()
  property bool switchBusy: false
  property string pendingTheme: ""
  property string pendingBoundary: ""
  property string lastError: ""
  property string lastAction: ""

  readonly property string period: Schedule.periodAt(now, currentConfig())
  readonly property string desiredSelection: Schedule.desiredTheme(now, currentConfig())
  readonly property string desiredTheme: Schedule.selectionLabel(desiredSelection)
  readonly property string nextSwitchText: Schedule.nextSwitchText(now, currentConfig())

  function currentConfig() {
    return {
      enabled: root.enabled,
      dayTheme: root.dayTheme,
      nightTheme: root.nightTheme,
      dayStart: root.dayStart,
      nightStart: root.nightStart,
      lastHandledBoundary: root.lastHandledBoundary
    }
  }

  function applyConfig(text) {
    var parsed = {}
    try { parsed = text && text.trim() ? JSON.parse(text) : {} }
    catch (error) { root.lastError = "Invalid config.json: " + error }
    var config = Schedule.normalize(parsed)
    root.enabled = config.enabled
    root.dayTheme = config.dayTheme
    root.nightTheme = config.nightTheme
    root.dayStart = config.dayStart
    root.nightStart = config.nightStart
    root.lastHandledBoundary = config.lastHandledBoundary
    root.loaded = true
    root.now = new Date()
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
    saveConfig({ enabled: value === true })
    if (value === true) Qt.callLater(root.applyNow)
    else root.lastAction = "Automatic switching disabled"
  }

  function updateSchedule(patch) {
    saveConfig(patch)
    root.lastAction = "Schedule saved"
  }

  function refreshThemes() {
    if (!themeListProcess.running) themeListProcess.running = true
  }

  function reconcile() {
    if (!root.loaded || !root.enabled || root.switchBusy) return
    root.now = new Date()
    var boundary = Schedule.boundaryToken(root.now, root.currentConfig())
    if (boundary === root.lastHandledBoundary) return
    switchSelection(root.desiredSelection, boundary)
  }

  function applyNow() {
    if (!root.loaded || root.switchBusy) return
    root.now = new Date()
    switchSelection(root.desiredSelection,
                    Schedule.boundaryToken(root.now, root.currentConfig()))
  }

  function switchSelection(selection, boundary) {
    var target = Schedule.resolveTheme(selection, root.themes,
                                       root.currentTheme, Math.random())
    if (!target) {
      var mode = Schedule.randomMode(selection)
      root.lastError = "No " + mode + " themes declare a mode in colors.toml."
      return
    }
    switchTo(target, boundary)
  }

  function switchTo(theme, boundary) {
    var target = String(theme || "").trim()
    if (!target) {
      root.lastError = "No theme is configured for the current period."
      return
    }

    root.pendingTheme = target
    root.pendingBoundary = boundary
    root.lastError = ""

    if (root.currentTheme.toLowerCase() === target.toLowerCase()) {
      root.lastHandledBoundary = boundary
      saveConfig({ lastHandledBoundary: boundary })
      root.lastAction = target + " is already active"
      return
    }

    switchProcess.command = ["omarchy", "theme", "set", target]
    root.switchBusy = true
    switchProcess.running = true
  }

  property Process configDirProcess: Process {
    command: ["mkdir", "-p", root.configDir]
  }

  property FileView configFile: FileView {
    path: root.configPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
    onFileChanged: reload()
  }

  property FileView currentThemeFile: FileView {
    path: root.currentThemePath
    watchChanges: true
    printErrors: false
    onLoaded: root.currentTheme = Schedule.displayTheme(text())
    onLoadFailed: root.currentTheme = "Unknown"
    onFileChanged: reload()
  }

  property Process themeListProcess: Process {
    command: ["bash", root.themeCatalogScriptPath]
    stdout: StdioCollector {
      id: themeListOutput
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: themeListError
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(themeListError.text || "Could not list themes").trim()
        return
      }
      root.themes = Schedule.parseThemeCatalog(themeListOutput.text)
      Qt.callLater(root.reconcile)
    }
  }

  property Process switchProcess: Process {
    stderr: StdioCollector {
      id: switchError
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.switchBusy = false
      if (exitCode === 0) {
        var applied = root.pendingTheme
        root.lastHandledBoundary = root.pendingBoundary
        root.currentTheme = applied
        root.saveConfig({ lastHandledBoundary: root.pendingBoundary })
        root.lastAction = "Switched to " + applied
        root.lastError = ""
        currentThemeFile.reload()
      } else {
        root.lastError = String(switchError.text || "Theme switch failed").trim()
      }
      root.pendingTheme = ""
      root.pendingBoundary = ""
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      root.now = date
      root.reconcile()
    }
  }

  Component.onCompleted: {
    root.configDirProcess.running = true
    root.refreshThemes()
  }
}
