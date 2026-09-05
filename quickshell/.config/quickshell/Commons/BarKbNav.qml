import QtQuick

// Keyboard-nav engine for the bar: owns which icon is focused and dispatches
// arrow/Enter/Escape to it. Bar.qml just supplies `candidates` and forwards
// key events here; the actual Exclusive keyboard grab stays on Bar.qml's own
// PanelWindow since WlrLayershell attaches to a window, not a QtObject.
QtObject {
    id: root

    property var candidates: []
    readonly property var items: root.candidates.filter(function(i) { return i.kbAvailable })
    property int index: -1
    property bool active: false

    function _applyFocusHighlight() {
        var focused = root.active ? root.items[root.index] : null
        for (var i = 0; i < root.candidates.length; i++) {
            root.candidates[i].kbFocused = root.candidates[i] === focused
        }
    }

    function open() {
        if (root.items.length === 0) return
        root.active = true
        if (root.index < 0 || root.index >= root.items.length) root.index = 0
        root._applyFocusHighlight()
    }

    function close() {
        for (var i = 0; i < root.candidates.length; i++) {
            var item = root.candidates[i]
            if (item.popupOpen !== undefined) item.popupOpen = false
            item.kbFocused = false
        }
        root.active = false
    }

    function move(delta) {
        if (root.items.length === 0) return
        var item = root.items[root.index]
        if (item && item.popupOpen !== undefined) item.popupOpen = false
        root.index = (root.index + delta + root.items.length) % root.items.length
        root._applyFocusHighlight()
    }

    function toggleExpand() {
        var item = root.items[root.index]
        if (!item) return
        if (item.popupOpen) item.popupOpen = false
        else item.kbActivate()
    }

    function handleKey(event) {
        if (!root.active) return
        var item = root.items[root.index]
        var expanded = !!(item && item.popupOpen)
        var scope = expanded ? item.kbNavScope : null

        if (scope && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
            scope.move(event.key === Qt.Key_Down ? 1 : -1)
            event.accepted = true
            return
        }
        if (scope && event.key === Qt.Key_Return) {
            scope.activate()
            event.accepted = true
            return
        }
        // Adjusts a slider if focused, else navigates like Up/Down; never falls through to move() (would collapse the popup).
        if (expanded && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            if (scope) {
                var delta = event.key === Qt.Key_Right ? 1 : -1
                if (scope.focusedItem && scope.focusedItem.kbAdjust) scope.adjust(delta)
                else scope.move(delta)
            }
            event.accepted = true
            return
        }

        switch (event.key) {
        case Qt.Key_Left:
            root.move(-1)
            event.accepted = true
            break
        case Qt.Key_Right:
            root.move(1)
            event.accepted = true
            break
        case Qt.Key_Return:
            root.toggleExpand()
            event.accepted = true
            break
        case Qt.Key_Escape:
            if (expanded) item.popupOpen = false
            else root.close()
            event.accepted = true
            break
        }
    }
}
