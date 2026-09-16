import QtQuick
import Quickshell.Io

// Bridge between the QML plugin and the `msi-rgb` backend CLI.
// Every action spawns one short-lived process; the last command's output is
// kept for the UI. `state` is the parsed `msi-rgb status` JSON, refreshed
// after every command and on construction.
QtObject {
  id: root

  property string bin: "msi-rgb"
  property var state: null
  property string lastOutput: ""
  property bool busy: false

  readonly property string currentColor: {
    if (!state || !state.devices || state.devices.length === 0) return "808080"
    var c = state.devices[0].colors
    return c && c.length > 0 ? normalize(c[0]) : "808080"
  }

  // True when no devices are detected — used by the UI to show a hint
  // instead of controls that cannot do anything.
  readonly property bool noDevices: !state || !state.devices || state.devices.length === 0

  function normalize(hex) {
    var s = String(hex).replace(/[^0-9A-Fa-f]/g, "")
    return s.length >= 6 ? s.substring(0, 6).toLowerCase() : "808080"
  }

  function run(args) {
    root.busy = true
    proc.command = [root.bin].concat(args)
    proc.running = true
  }

  function refresh() {
    root.run(["status"])
  }

  function handleOutput(text) {
    root.lastOutput = text
    try {
      var parsed = JSON.parse(text)
      if (parsed && parsed.devices !== undefined) root.state = parsed
    } catch (e) {
      // not JSON — keep previous state
    }
    root.busy = false
  }

  property Process proc: Process {
    command: [root.bin, "status"]

    stdout: StdioCollector {
      onStreamFinished: root.handleOutput(this.text)
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (!root.busy) return
        root.lastOutput = this.text
        root.busy = false
      }
    }
  }

  Component.onCompleted: root.refresh()
}
