import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dizziee.auto-wallpaper"

  readonly property var service: bar && bar.shell
    ? bar.shell.serviceFor(root.moduleName) : null
  readonly property bool ready: service !== null
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool showError: ready && service.lastError !== ""

  // BarWidget does not derive implicit size from children; forward the
  // button's size so a live, clickable slot is created.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function applyNow() { if (ready) service.applyNext() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
    target.service = root.service
  }

  onBarChanged: injectPanel()
  onServiceChanged: injectPanel()

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
    function next(): void { root.applyNow() }
    function enable(): void { if (root.ready) root.service.setEnabled(true) }
    function disable(): void { if (root.ready) root.service.setEnabled(false) }
    function status(): string {
      if (!root.ready) return "service unavailable"
      return "enabled=" + root.service.enabled
        + " theme=" + root.service.currentThemeDisplay
        + " count=" + root.service.catalogPaths.length
        + " current=\"" + root.service.currentWallpaperDisplay() + "\""
        + " next=\"" + root.service.nextText() + "\""
        + (root.service.lastError ? " error=\"" + root.service.lastError + "\"" : "")
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰉊"
    dimmed: !root.ready || !root.service.enabled
    active: root.showError
    tooltipText: !root.ready ? "Auto Wallpaper unavailable"
      : (root.service.enabled ? root.service.nextText() : "Auto Wallpaper is off")
    onPressed: function(code) {
      if (code === Qt.MiddleButton) root.applyNow()
      else root.toggle()
    }
  }
}
