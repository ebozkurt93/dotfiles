import Quickshell.Io
import QtQuick

Process {
    id: jsonProcess
    property string buffer: ""
    property string label: "process"
    signal parsed(var data)
    signal failed()

    stdout: SplitParser {
        onRead: function(data) { jsonProcess.buffer += data + "\n" }
    }
    onStarted: jsonProcess.buffer = ""
    onExited: function(exitCode, exitStatus) {
        if (exitCode !== 0 || exitStatus !== 0) {
            jsonProcess.failed()
            return
        }
        try {
            jsonProcess.parsed(JSON.parse(jsonProcess.buffer))
        } catch (e) {
            console.warn(jsonProcess.label + " returned invalid JSON:", e)
            jsonProcess.failed()
        }
    }

    function run(cmd) {
        jsonProcess.running = false
        jsonProcess.command = cmd
        jsonProcess.running = true
    }
}
