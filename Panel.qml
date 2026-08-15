import QtQuick
import QtQuick.Controls
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

  // Square wallpaper preview geometry.
  readonly property real cellSize: Style.space(72)
  readonly property real cellSpacing: Style.space(8)

  function open() {
    if (service) {
      service.nowEpoch = new Date().getTime()
      service.refreshCatalog()
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

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
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
          PanelSeparator { width: parent.width; foreground: root.foreground }

          PanelSectionHeader {
            text: "WALLPAPERS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            text: root.service ? root.service.statusText() : ""
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Flow {
            width: parent.width
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
                radius: Style.space(6)
                border.color: cell.isCurrent ? root.foreground : root.dim
                border.width: cell.isCurrent ? 2 : 1
                color: root.foreground
                clip: true

                Image {
                  anchors.fill: parent
                  source: Util.fileUrl(cell.modelData.path)
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                  smooth: true
                }

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(6)
                  color: Util.alpha(root.foreground, cell.isCurrent ? 0 : 0.22)
                }

                ToolTip.visible: cellMouse.containsMouse
                ToolTip.text: cell.modelData.name
                ToolTip.delay: 500

                MouseArea {
                  id: cellMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.service) root.service.setWallpaper(cell.modelData.path)
                }
              }
            }
          }

          Text {
            width: parent.width
            text: "Click a wallpaper to set it now. The current one is highlighted with a border."
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          PanelSectionHeader {
            text: "SCHEDULE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            width: parent.width
            label: "Automatic switching"
            description: "Cycles the active theme's wallpapers on an interval."
            checked: root.service ? root.service.enabled : false
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.service !== null
            onClicked: if (root.service) root.service.setEnabled(!root.service.enabled)
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            Dropdown {
              id: intervalPicker
              width: Style.space(150)
              label: "Interval"
              value: root.service ? String(root.service.intervalMinutes) : "60"
              options: root.intervalOptions
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) {
                if (root.service) root.service.updateSchedule({ intervalMinutes: Number(value) })
              }
            }

            Dropdown {
              id: modePicker
              width: parent.width - intervalPicker.width - parent.spacing
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
            width: parent.width
            text: root.service && root.service.busy ? "Applying…" : "Apply next wallpaper now"
            iconText: "󰑐"
            bordered: true
            focusable: true
            enabled: root.service && !root.service.busy
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: if (root.service) root.service.applyNext()
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          Text {
            visible: root.service && (root.service.lastError !== "" || root.service.lastAction !== "")
            width: parent.width
            text: root.service && root.service.lastError !== ""
              ? root.service.lastError : (root.service ? root.service.lastAction : "")
            textFormat: Text.PlainText
            color: root.service && root.service.lastError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
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

