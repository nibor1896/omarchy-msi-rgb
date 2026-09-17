import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// MSI RGB bar widget: a lightbulb glyph tinted with the current lighting
// color. Left click opens the control popup, right click toggles the lights
// off/back to the default, middle click applies the pride preset.
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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Nerd Font lightbulb (nf-fa-lightbulb_o)
    text: "\uf0eb"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "MSI RGB"
    // Glyph tinted with the live lighting color; falls back to the
    // foreground when no color has been read yet.
    foreground: rgb.currentColor && rgb.currentColor !== "808080"
      ? "#" + rgb.currentColor
      : (root.bar ? root.bar.barForeground : Color.foreground)
    useActiveColor: false

    onPressed: function(b) {
      if (b === Qt.RightButton) rgb.currentColor === "000000" ? root.applyDefault() : rgb.run(["off"])
      else if (b === Qt.MiddleButton) rgb.run(["preset", "pride"])
      else root.togglePanel()
    }
  }

  RgbBridge {
    id: rgb
    bin: setting("binPath", "msi-rgb")
  }
}
