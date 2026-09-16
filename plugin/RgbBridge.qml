import QtQuick
import Quickshell
import Quickshell.Io

// Bridge between the QML plugin and the `msi-rgb` backend CLI.
//
// Actions are fire-and-forget via Quickshell.execDetached — every click gets
// its own process, so slow OpenRGB device scans can never swallow commands
// (a single reused Process would drop any command that arrives while the
// previous one is still running). Status refreshes come back through one
// short-lived Process whose JSON feeds `state`.
QtObject {
  id: root

  property string bin: "msi-rgb"
  property var state: null
  property string lastOutput: ""
  property bool busy: false

  readonly property string currentColor: {
    if (!state || !state.devices || state.devices.length === 0) return "808080"
    var c = state.devices[0].colors
    return c && c.length > 0 && c[0] ? normalize(c[0]) : "808080"
  }

  // True when no devices are detected — the UI shows setup instructions
  // instead of controls that cannot do anything.
  readonly property bool noDevices: !state || !state.devices || state.devices.length === 0

  function normalize(hex) {
    var s = String(hex).replace(/[^0-9A-Fa-f]/g, "")
    return s.length >= 6 ? s.substring(0, 6).toLowerCase() : "808080"
  }

  function run(args) {
    Quickshell.execDetached([root.bin].concat(args))
    // Re-read state once the command has had time to land.
    refreshLater()
  }

  function refresh() {
    if (statusProc.running) return  // one scan at a time; a dropped refresh is retried on the next action
    statusProc.command = [root.bin, "status"]
    statusProc.running = true
    root.busy = true
  }

  function refreshLater() {
    Qt.callLater(function() { refreshTimer.start() })
  }

  property Timer refreshTimer: Timer {
    interval: 1500
    onTriggered: root.refresh()
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

  property Process statusProc: Process {
    command: [root.bin, "status"]

    stdout: StdioCollector {
      onStreamFinished: root.handleOutput(this.text)
    }
    stderr: StdioCollector {
      onStreamFinished: {
        root.lastOutput = this.text
        root.busy = false
      }
    }
  }

  Component.onCompleted: root.refresh()
}
