import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Schedule.js" as Schedule

Panel {
  id: root
  moduleName: "dizziee.auto-wallpaper"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var intervalOptions: Schedule.intervalOptions()
  readonly property var modeOptions: Schedule.modeOptions()

  // Square wallpaper preview geometry. Cells are exactly cellSize x cellSize
  // with a wrapping grid driven by the content width.
  readonly property real cellSize: Style.space(72)
  readonly property real cellSpacing: Style.space(8)
  readonly property int gridColumns: Math.max(1, Math.floor(
    ((content ? content.width : 0) + root.cellSpacing) / (root.cellSize + root.cellSpacing)))
  readonly property int gridRows: Math.ceil(
    (root.service ? root.service.wallpaperList.length : 0) / root.gridColumns)
  readonly property real gridHeight: root.gridRows * root.cellSize
    + (root.gridRows > 1 ? (root.gridRows - 1) * root.cellSpacing : 0)

  function open() {
    if (service) {
      service.nowEpoch = new Date().getTime()
      // Only when opened: refresh current wallpaper + warm Omarchy thumbnails.
      service.updateCurrent()
      service.refreshCatalog(true)
    }
    controller.show()
  }

  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if ((text === "a" || text === "A") && root.service) root.service.applyNext()
        else if ((text === "e" || text === "E") && root.service)
          root.service.setEnabled(!root.service.enabled)
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: content
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            Layout.fillWidth: true
            title: "Auto Wallpaper"
            meta: !root.service ? "Service unavailable" : root.service.nextText()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰉊"
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

          PanelSectionHeader {
            Layout.fillWidth: true
            text: "WALLPAPERS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          Text {
            Layout.fillWidth: true
            text: root.service ? root.service.statusText() : ""
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: root.gridHeight
            spacing: root.cellSpacing

            Repeater {
              model: root.service ? root.service.wallpaperList : []

              delegate: Rectangle {
                id: cell
                required property var modelData
                readonly property bool isCurrent: root.service
                  && root.service.currentWallpaper === modelData.path
                width: root.cellSize
                height: root.cellSize
                color: root.foreground
                clip: true

                Image {
                  anchors.fill: parent
                  // Only decode when the panel is open; use Omarchy's cached
                  // thumbnail + a small sourceSize so the decode is tiny.
                  // cache:false so the decoded pixmap is dropped on close
                  // (re-decode on reopen is trivial for 240px thumbnails).
                  source: root.opened ? Util.fileUrl(modelData.thumb) : ""
                  sourceSize: Qt.size(240, 240)
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: false
                  smooth: true
                }

                // Dim the non-current cells for contrast.
                Rectangle {
                  anchors.fill: parent
                  color: Util.alpha(root.foreground, cell.isCurrent ? 0 : 0.22)
                }

                // Current border drawn ON TOP so the image can't hide it.
                Rectangle {
                  anchors.fill: parent
                  color: "transparent"
                  border.color: cell.isCurrent ? root.foreground : root.dim
                  border.width: cell.isCurrent ? 2 : 1
                }

                ToolTip.visible: cellMouse.containsMouse
                ToolTip.text: modelData.name
                ToolTip.delay: 500

                MouseArea {
                  id: cellMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.service) root.service.setWallpaper(modelData.path)
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Click a wallpaper to set it now. The current one is highlighted with a border."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

          PanelSectionHeader {
            Layout.fillWidth: true
            text: "SCHEDULE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            Layout.fillWidth: true
            label: "Automatic switching"
            description: "Cycles the active theme's wallpapers on an interval."
            checked: root.service ? root.service.enabled : false
            foreground: root.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
            enabled: root.service !== null
            onClicked: if (root.service) root.service.setEnabled(!root.service.enabled)
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Dropdown {
              Layout.fillWidth: true
              label: "Interval"
              value: root.service ? String(root.service.intervalMinutes) : "30"
              options: root.intervalOptions
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) {
                if (root.service) root.service.updateSchedule({ intervalMinutes: Number(value) })
              }
            }

            Dropdown {
              Layout.fillWidth: true
              label: "Order"
              value: root.service ? root.service.mode : "sequential"
              options: root.modeOptions
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) {
                if (root.service) root.service.updateSchedule({ mode: value })
              }
            }
          }

          Button {
            Layout.fillWidth: true
            text: root.service && root.service.busy ? "Applying…" : "Apply next wallpaper now"
            iconText: "󰑐"
            bordered: true
            focusable: true
            enabled: root.service && !root.service.busy
            foreground: root.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
            onClicked: if (root.service) root.service.applyNext()
          }

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

          Text {
            Layout.fillWidth: true
            visible: root.service && (root.service.lastError !== "" || root.service.lastAction !== "")
            text: root.service && root.service.lastError !== ""
              ? root.service.lastError : (root.service ? root.service.lastAction : "")
            textFormat: Text.PlainText
            color: root.service && root.service.lastError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            Layout.fillWidth: true
            text: "Manual choices and scheduled changes share the same rotation. "
              + (root.service && root.service.shuffle
                  ? "Shuffle plays every wallpaper once before repeating."
                  : "Sequential order advances by one wallpaper each interval.")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}

