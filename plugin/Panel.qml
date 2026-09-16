import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// MSI RGB popup, built from the Omarchy panel kit: PanelSectionHeader +
// PanelSeparator rhythm, kit Button/Dropdown/TextField controls. Every
// action shells out to `msi-rgb`, the single source of truth for what the
// hardware supports.
Panel {
  id: root
  moduleName: "io.github.nibor1896.msi-rgb"
  ipcTarget: "io.github.nibor1896.msi-rgb"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Selected device: -1 means "all devices".
  property int selectedDevice: -1
  property string mode: "static"
  property string color: "ff0000"
  property int speed: 2

  readonly property var modes: [
    "static", "off", "breathing", "pulse", "blink", "flashing",
    "rainbow", "rainbow-wave", "color-cycle", "color-shift",
    "marquee", "waterfall", "lightning", "fire"
  ]

  readonly property var swatches: [
    "ff0000", "ff7f00", "ffee00", "00ff2a", "00ffcc", "00aaff",
    "2b4dff", "8b00ff", "ff00aa", "ffffff", "fff2d9", "101014"
  ]

  readonly property var presets: [
    "stealth", "ambient", "blood", "ocean", "pride", "fire", "matrix"
  ]

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    rgb.refresh()
    panel.open = true
  }

  function close() {
    panel.open = false
  }

  function toggle() {
    opened ? close() : open()
  }

  function deviceArg() {
    return selectedDevice < 0 ? "all" : String(selectedDevice)
  }

  function apply() {
    if (mode === "off") rgb.run(["off"])
    else rgb.run(["set", "-d", deviceArg(), "-m", mode, "-c", color, "-s", String(speed)])
  }

  implicitWidth: panel.implicitWidth
  implicitHeight: panel.implicitHeight

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: Style.space(320)
    contentHeight: Style.space(470)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + Style.space(24)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          x: Style.space(16)
          width: parent.width - Style.space(32)
          spacing: Style.space(8)

          // ---- Header
          Text {
            text: "MSI RGB"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
          }

          Text {
            visible: rgb.noDevices
            width: parent.width
            wrapMode: Text.Wrap
            text: "No RGB devices found.\n\nInstall and set up OpenRGB first:\n  omarchy pkg add openrgb\n  msi-rgb install-udev\n\nThen log out and back in."
            color: root.fg
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: 12
          }

          // ---- Devices
          Column {
            visible: !rgb.noDevices
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              foreground: root.fg
              fontFamily: root.fontFamily
              text: "DEVICE"
            }

            Dropdown {
              width: parent.width
              foreground: root.fg
              fontFamily: root.fontFamily
              value: root.selectedDevice < 0 ? "all" : String(root.selectedDevice)
              options: {
                var opts = [{ value: "all", label: "All devices" }]
                var devices = rgb.state && rgb.state.devices ? rgb.state.devices : []
                for (var i = 0; i < devices.length; i++)
                  opts.push({ value: String(devices[i].index), label: devices[i].index + ". " + devices[i].name })
                return opts
              }
              onChanged: function(value) {
                root.selectedDevice = value === "all" ? -1 : parseInt(value)
              }
            }
          }

          PanelSeparator {
            visible: !rgb.noDevices
            width: parent.width
            foreground: root.fg
          }

          // ---- Mode
          Column {
            visible: !rgb.noDevices
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              foreground: root.fg
              fontFamily: root.fontFamily
              text: "MODE"
            }

            Grid {
              width: parent.width
              columns: 3
              spacing: Style.space(6)

              Repeater {
                model: root.modes

                Button {
                  required property string modelData
                  width: (parent.width - Style.space(12)) / 3
                  text: modelData
                  selected: root.mode === modelData
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  fontSize: 11
                  leftAlign: true
                  onClicked: {
                    root.mode = modelData
                    root.apply()
                  }
                }
              }
            }
          }

          // ---- Color
          Column {
            visible: !rgb.noDevices && root.mode !== "off"
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              foreground: root.fg
              fontFamily: root.fontFamily
              text: "COLOR"
            }

            Grid {
              width: parent.width
              columns: 6
              spacing: Style.space(6)

              Repeater {
                model: root.swatches

                Rectangle {
                  required property string modelData
                  width: Style.space(28)
                  height: Style.space(28)
                  radius: Style.space(8)
                  color: "#" + modelData
                  border.width: root.color === modelData ? 2 : 1
                  border.color: root.color === modelData ? root.fg : Qt.rgba(0, 0, 0, 0.3)

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.color = modelData
                      root.apply()
                    }
                  }
                }
              }
            }

            Row {
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(28)
                height: Style.space(28)
                radius: Style.space(8)
                color: "#" + root.color
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
              }

              TextField {
                width: Style.space(150)
                foreground: root.fg
                text: root.color
                font.family: root.fontFamily
                font.pixelSize: 12
                validator: RegularExpressionValidator { regularExpression: /[0-9A-Fa-f]{0,6}/ }
                onAccepted: {
                  if (text.length === 6) {
                    root.color = text.toLowerCase()
                    root.apply()
                  }
                }
              }
            }
          }

          // ---- Speed
          Column {
            visible: !rgb.noDevices && root.mode !== "off" && root.mode !== "static"
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              foreground: root.fg
              fontFamily: root.fontFamily
              text: "SPEED"
            }

            Row {
              spacing: Style.space(6)

              Repeater {
                model: [0, 1, 2, 3, 4]

                Button {
                  required property var modelData
                  text: String(modelData)
                  selected: root.speed === modelData
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  fontSize: 11
                  onClicked: {
                    root.speed = modelData
                    root.apply()
                  }
                }
              }
            }
          }

          PanelSeparator {
            visible: !rgb.noDevices
            width: parent.width
            foreground: root.fg
          }

          // ---- Presets
          Column {
            visible: !rgb.noDevices
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              foreground: root.fg
              fontFamily: root.fontFamily
              text: "PRESETS"
            }

            Grid {
              width: parent.width
              columns: 4
              spacing: Style.space(6)

              Repeater {
                model: root.presets

                Button {
                  required property string modelData
                  width: (parent.width - Style.space(18)) / 4
                  text: modelData
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  fontSize: 11
                  leftAlign: true
                  onClicked: rgb.run(["preset", modelData])
                }
              }
            }
          }

          // ---- Off / On
          Row {
            visible: !rgb.noDevices
            spacing: Style.space(8)

            Button {
              text: "Lights off"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: 11
              onClicked: rgb.run(["off"])
            }

            Button {
              text: "Lights on"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: 11
              onClicked: rgb.run(["on", root.color])
            }
          }
        }
      }
    }
  }

  RgbBridge {
    id: rgb
    bin: setting("binPath", "msi-rgb")
  }
}
