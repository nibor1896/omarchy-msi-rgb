import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// MSI RGB bar widget: a colored dot (plus optional label) that opens the
// RGB control popup. Left click opens the panel, right click toggles the
// lights off/on, middle click cycles presets.
BarWidget {
  id: root
  moduleName: "io.github.nibor1896.msi-rgb"

  // Popup shape contract for shell.summon/hide/toggle routing.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
    else panelLoader.active = true
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
    else panelLoader.active = true
  }

  function applyDefault() {
    rgb.run(["set", "--mode", setting("defaultMode", "static"),
             "--color", setting("defaultColor", "ff0000")])
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

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
    target: "io.github.nibor1896.msi-rgb"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function off(): void { rgb.run(["off"]) }
    function on(): void { rgb.run(["on"]) }
    function setMode(mode: string): void { rgb.run(["set", "--mode", mode]) }
    function setColor(color: string): void { rgb.run(["set", "--mode", "static", "--color", color]) }
    function preset(name: string): void { rgb.run(["preset", name]) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical || !showLabel ? "" : "RGB"
    labelVisible: !root.vertical && showLabel
    hasVisualContent: true
    horizontalMargin: 8.5
    verticalPadding: 6

    readonly property bool showLabel: setting("showLabel", true)

    onPressed: function(b) {
      if (b === Qt.RightButton) rgb.currentColor === "000000" ? root.applyDefault() : rgb.run(["off"])
      else if (b === Qt.MiddleButton) rgb.run(["preset", "pride"])
      else root.togglePanel()
    }

    Rectangle {
      id: dot
      width: Math.min(Style.bar.iconSlot * 0.5, height)
      height: Math.min(parent.height * 0.5, Style.bar.iconSlot * 0.5)
      radius: width / 2
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: button.labelVisible ? -button.labelWidth / 2 - width / 2 + 2 : 0
      color: "#" + (rgb.currentColor || "808080")
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.25)
    }
  }

  RgbBridge {
    id: rgb
    bin: setting("binPath", "msi-rgb")
  }
}
