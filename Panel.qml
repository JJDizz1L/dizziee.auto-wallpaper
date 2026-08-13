import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Schedule.js" as Schedule

Panel {
  id: root
  moduleName: "acrogenesis.theme-scheduler"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var timeOptions: Schedule.timeOptions(15)
  readonly property bool dropdownOpen: dayThemePicker.popupOpen
    || nightThemePicker.popupOpen || dayTimePicker.popupOpen || nightTimePicker.popupOpen

  function open() {
    if (service) {
      service.now = new Date()
      service.refreshThemes()
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
      blocked: root.dropdownOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if ((text === "a" || text === "A") && root.service) root.service.applyNow()
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
            title: "Theme Scheduler"
            meta: !root.service ? "Service unavailable"
              : (root.service.enabled ? root.service.nextSwitchText : "Automatic switching is off")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: root.service && root.service.period === "day" ? "󰖨" : "󰖔"
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Toggle {
            width: parent.width
            label: "Automatic switching"
            description: "Use local time and catch up after sleep or restart."
            checked: root.service ? root.service.enabled : false
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.service !== null
            onClicked: if (root.service) root.service.setEnabled(!root.service.enabled)
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          PanelSectionHeader {
            text: "DAY"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            SearchableDropdown {
              id: dayThemePicker
              width: parent.width - dayTimePicker.width - parent.spacing
              label: "Theme"
              value: root.service ? root.service.dayTheme : ""
              options: root.service ? root.service.themes : []
              placeholderText: "Search themes..."
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) { if (root.service) root.service.updateSchedule({ dayTheme: value }) }
            }

            Dropdown {
              id: dayTimePicker
              width: Style.space(110)
              label: "Starts"
              value: root.service ? String(root.service.dayStart) : "420"
              options: root.timeOptions
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) { if (root.service) root.service.updateSchedule({ dayStart: Number(value) }) }
            }
          }

          PanelSectionHeader {
            text: "NIGHT"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            SearchableDropdown {
              id: nightThemePicker
              width: parent.width - nightTimePicker.width - parent.spacing
              label: "Theme"
              value: root.service ? root.service.nightTheme : ""
              options: root.service ? root.service.themes : []
              placeholderText: "Search themes..."
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) { if (root.service) root.service.updateSchedule({ nightTheme: value }) }
            }

            Dropdown {
              id: nightTimePicker
              width: Style.space(110)
              label: "Starts"
              value: root.service ? String(root.service.nightStart) : "1140"
              options: root.timeOptions
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) { if (root.service) root.service.updateSchedule({ nightStart: Number(value) }) }
            }
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(5)

            Text {
              width: parent.width
              text: root.service ? "Current: " + root.service.currentTheme
                + " · Scheduled: " + root.service.desiredTheme : ""
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

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
          }

          Button {
            width: parent.width
            text: root.service && root.service.switchBusy ? "Applying…" : "Apply scheduled theme now"
            iconText: "󰑐"
            bordered: true
            focusable: true
            enabled: root.service && !root.service.switchBusy
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: if (root.service) root.service.applyNow()
          }

          Text {
            width: parent.width
            text: "Manual theme choices remain in place until the next scheduled boundary. Middle-click the bar icon to apply immediately."
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
