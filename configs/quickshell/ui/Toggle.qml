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
    // Real bug found live, 17 Sept 2026 (Akash: quick-settings toggles
    // "must work smooth with mouse") - checked/x used to jump instantly,
    // every other interactive element in the design already eases
    // (dock hover scale, search-box width, etc.) so this was the one
    // hold-out that felt cheap by comparison. One fix here covers every
    // caller (Appearance, Accessibility, Network, Bluetooth, and quick
    // settings' Wi-Fi/Bluetooth), since they all share this component.
    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 150 } }
    Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: 150 } }

    Rectangle {
        width: 24; height: 24; radius: 12; color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 2 : 2
        Behavior on x { enabled: !Theme.reducedMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
