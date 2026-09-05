import QtQuick

// Generic popup nav: any Item under `content` with `kbNavTarget: true` (+ `kbActivate()`) is auto-discovered in document order.
//
// To wire a new bar item into kb-nav:
//   - widget: kbAvailable, kbFocused, kbActivate()
//   - if it has a popup: a KbNavScope{content: ...} exposed as kbNavScope
//   - popup controls: kbNavTarget: true + kbActivate() (kbAdjust(delta) for sliders)
//   - Bar.qml: add the widget's id to BarKbNav's candidates
QtObject {
    id: root

    property Item content: null
    property var focusedItem: null

    function _collect() {
        var out = []
        if (root.content) _walk(root.content, out)
        return out
    }

    function _walk(node, out) {
        var kids = node.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.kbNavTarget === true && c.visible) out.push(c)
            _walk(c, out)
        }
    }

    readonly property bool hasItems: _collect().length > 0

    function reset() {
        var items = _collect()
        root.focusedItem = items.length > 0 ? items[0] : null
    }

    function clear() {
        root.focusedItem = null
    }

    function move(delta) {
        var items = _collect()
        if (items.length === 0) { root.focusedItem = null; return }
        var idx = items.indexOf(root.focusedItem)
        var newIndex = (Math.max(idx, 0) + delta + items.length) % items.length
        root.focusedItem = items[newIndex]
    }

    function activate() {
        if (root.focusedItem && root.focusedItem.kbActivate) root.focusedItem.kbActivate()
    }

    function adjust(delta) {
        if (root.focusedItem && root.focusedItem.kbAdjust) root.focusedItem.kbAdjust(delta)
    }
}
