// Task 27g: shared component library. The on/off pill switch pattern -
// was hand-repeated identically 4 times (Appearance's dark-mode toggle,
// Accessibility's reduce-motion toggle, Network's Wi-Fi radio, Bluetooth's
// power toggle) before this existed. Deliberately dumb: exposes `checked`
// + a `toggled()` signal only, the caller decides what actually flips -
// matches how each of those 4 call sites does something different
// (a plain property flip, a function call, or both).
import QtQuick
import "../"

Rectangle {
    id: root
    property bool checked: false
    signal toggled()

    width: 57; height: 30; radius: 15
    color: checked ? WorkspaceState.activeColor() : Theme.panelInk
    opacity: checked ? 1 : 0.25

    Rectangle {
        width: 24; height: 24; radius: 12; color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 2 : 2
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled()
    }
}
