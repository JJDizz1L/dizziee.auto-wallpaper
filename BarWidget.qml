import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Schedule.js" as Schedule

BarWidget {
  id: root
  moduleName: "acrogenesis.theme-scheduler"

  readonly property var scheduler: bar && bar.shell
    ? bar.shell.serviceFor(root.moduleName) : null
  readonly property bool ready: scheduler !== null
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // Item does not derive implicit size from children. Without forwarding the
  // button's size, Omarchy creates a live but zero-width bar slot: IPC can open
  // the panel, yet there is nothing on the bar to click.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function applyNow() { if (ready) scheduler.applyNow() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
    target.service = root.scheduler
  }

  onBarChanged: injectPanel()
  onSchedulerChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function applyNow(): void { root.applyNow() }
    function enable(): void { if (root.ready) root.scheduler.setEnabled(true) }
    function disable(): void { if (root.ready) root.scheduler.setEnabled(false) }
    function status(): string {
      if (!root.ready) return "service unavailable"
      return "enabled=" + root.scheduler.enabled
        + " current=" + root.scheduler.currentTheme
        + " desired=" + root.scheduler.desiredTheme
        + " next=\"" + root.scheduler.nextSwitchText + "\""
        + (root.scheduler.lastError ? " error=\"" + root.scheduler.lastError + "\"" : "")
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.ready && root.scheduler.period === "day" ? "☀" : "☾"
    dimmed: !root.ready || !root.scheduler.enabled
    active: root.ready && root.scheduler.lastError !== ""
    tooltipText: !root.ready ? "Theme Scheduler unavailable"
      : (root.scheduler.enabled ? root.scheduler.nextSwitchText : "Theme Scheduler is off")
    onPressed: function(code) {
      if (code === Qt.MiddleButton) root.applyNow()
      else root.toggle()
    }
  }
}
