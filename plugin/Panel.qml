import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// MSI RGB popup: device selector, mode grid, color swatches + hex field,
// speed slider, on/off, presets and profiles — each action just shells out
// to `msi-rgb`, the single source of truth for what the hardware supports.
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
    "ff0000", "ff7f00", "ffee00", "00ff2a", "00ffcc",
    "00aaff", "2b4dff", "8b00ff", "ff00aa", "ffffff",
    "fff2d9", "101014"
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
    contentWidth: Style.space(340)
    contentHeight: Style.space(430)

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
          x: Style.space(12)
          width: parent.width - Style.space(24)
          spacing: Style.space(10)

          // ---- Header
          Text {
            text: "MSI RGB"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.body * 1.2
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
            font.pixelSize: Style.font.body
          }

          // ---- Devices
          Column {
            visible: !rgb.noDevices
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "Devices"
              color: root.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.small
            }

            Row {
              spacing: Style.space(6)

              DevChip {
                label: "All"
                selected: root.selectedDevice === -1
                fg: root.fg
                fontFamily: root.fontFamily
                onClicked: root.selectedDevice = -1
              }

              Repeater {
                model: rgb.state && rgb.state.devices ? rgb.state.devices : []

                DevChip {
                  required property var modelData
                  label: (modelData.index + 1) + ". " + (String(modelData.name).length > 14 ? String(modelData.name).substring(0, 13) + "…" : modelData.name)
                  selected: root.selectedDevice === modelData.index
                  fg: root.fg
                  fontFamily: root.fontFamily
                  onClicked: root.selectedDevice = modelData.index
                }
              }
            }
          }

          // ---- Modes
          Column {
            visible: !rgb.noDevices
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "Mode"
              color: root.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.small
            }

            Grid {
              width: parent.width
              columns: 3
              spacing: Style.space(6)

              Repeater {
                model: root.modes

                ModeChip {
                  required property string modelData
                  label: modelData
                  selected: root.mode === modelData
                  fg: root.fg
                  fontFamily: root.fontFamily
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

            Text {
              text: "Color"
              color: root.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.small
            }

            Grid {
              width: parent.width
              columns: 6
              spacing: Style.space(6)

              Repeater {
                model: root.swatches

                Rectangle {
                  required property string modelData
                  width: Style.space(30)
                  height: Style.space(30)
                  radius: Style.space(8)
                  color: "#" + modelData
                  border.width: root.color === modelData ? 2 : 1
                  border.color: root.color === modelData ? root.fg : Qt.rgba(0, 0, 0, 0.3)

                  MouseArea {
                    anchors.fill: parent
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
                width: Style.space(30)
                height: Style.space(30)
                radius: Style.space(8)
                color: "#" + root.color
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
              }

              Rectangle {
                width: hexInput.implicitWidth + Style.space(20)
                height: Style.space(34)
                radius: Style.space(8)
                color: Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: hexInput.activeFocus ? root.fg : Qt.rgba(1, 1, 1, 0.15)

                TextInput {
                  id: hexInput
                  anchors.centerIn: parent
                  width: Style.space(140)
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  text: root.color
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
          }

          // ---- Speed
          Column {
            visible: !rgb.noDevices && root.mode !== "off" && root.mode !== "static"
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "Speed: " + root.speed
              color: root.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.small
            }

            Row {
              spacing: Style.space(6)

              Repeater {
                model: [0, 1, 2, 3, 4]

                ModeChip {
                  required property var modelData
                  label: String(modelData)
                  selected: root.speed === modelData
                  fg: root.fg
                  fontFamily: root.fontFamily
                  onClicked: {
                    root.speed = modelData
                    root.apply()
                  }
                }
              }
            }
          }

          // ---- Presets
          Column {
            visible: !rgb.noDevices
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "Presets"
              color: root.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.small
            }

            Row {
              spacing: Style.space(6)

              Repeater {
                model: root.presets

                ModeChip {
                  required property string modelData
                  label: modelData
                  selected: false
                  fg: root.fg
                  fontFamily: root.fontFamily
                  onClicked: rgb.run(["preset", modelData])
                }
              }
            }
          }

          // ---- Off / On
          Row {
            visible: !rgb.noDevices
            spacing: Style.space(8)

            ModeChip {
              label: "Lights off"
              selected: false
              fg: root.fg
              fontFamily: root.fontFamily
              onClicked: rgb.run(["off"])
            }

            ModeChip {
              label: "Lights on"
              selected: false
              fg: root.fg
              fontFamily: root.fontFamily
              onClicked: rgb.run(["on", root.color])
            }
          }

          Text {
            visible: rgb.busy
            text: "…"
            color: root.fg
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.small
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
