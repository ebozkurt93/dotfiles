import Quickshell
import Quickshell.Io
import QtQuick

// JSON-line client for hyprmoncfgd's Unix-socket IPC; pushes live status via `subscribe` instead of polling the CLI.
Item {
    id: root
    property var status: null
    property bool connected: sock.connected
    property var _pending: ({})
    property int _nextId: 1

    function reconnect() {
        sock.connected = false
        sock.connected = true
    }

    function call(method, params, callback) {
        var id = String(root._nextId++)
        if (callback) root._pending[id] = callback
        var req = { type: "request", protocol_version: 1, id: id, method: method }
        if (params !== undefined) req.params = params
        sock.write(JSON.stringify(req) + "\n")
        sock.flush()
    }

    function _handleLine(line) {
        if (!line) return
        var msg
        try {
            msg = JSON.parse(line)
        } catch (e) {
            return
        }
        if (msg.type === "event" && msg.event === "status") {
            root.status = msg.data
        } else if (msg.type === "response" && msg.id !== undefined && root._pending[msg.id]) {
            var cb = root._pending[msg.id]
            delete root._pending[msg.id]
            cb(msg.error ? null : msg.result, msg.error || null)
        }
    }

    Socket {
        id: sock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprmoncfgd.sock"
        connected: true
        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root._handleLine(data) }
        }
        onConnectedChanged: {
            if (sock.connected) {
                root.call("subscribe", undefined, function(result) { root.status = result })
            } else {
                root.status = null
            }
        }
    }
}
