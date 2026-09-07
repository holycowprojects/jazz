// Task 27g: shared component library. The "rounded rectangle + centered
// text + MouseArea" action-button pattern - was hand-repeated ~35 times
// across Settings.qml (Refresh/Clear/Scan/Connect/Disconnect/Remove/Pair/
// Forget/Save/Reset/Cancel/Mute/Keep/Revert, etc.) before this existed,
// each copy re-deciding its own colors instead of using one of a few real
// variants. width/height/radius default to the most common size already
// in use and can be overridden per instance like any QML property.
import QtQuick
import "../"

Rectangle {
    id: root
    property string label: ""
    // primary (active workspace's accent color, white text) | danger
    // (critical bg, white text) | outlineDanger (panel bg, critical
    // border+text) | neutral (panel bg, panelInk border+text) | subtle
    // (surfaceRaised, no border, panelInk text) | flat (panel bg, no
    // border, panelInk text - the unselected state of a selectable pill
    // group, e.g. Agents' policy buttons)
    property string variant: "primary"
    property int fontSize: 10
    signal clicked()

    implicitWidth: labelText.implicitWidth + 20
    implicitHeight: 22
    radius: 4
    opacity: enabled ? 1 : 0.4
    color: {
        if (variant === "primary") return WorkspaceState.activeColor()
        if (variant === "danger") return Theme.critical
        if (variant === "subtle") return Theme.surfaceRaised
        return Theme.panel // neutral | outlineDanger | flat
    }
    border.width: (variant === "neutral" || variant === "outlineDanger") ? 1 : 0
    border.color: variant === "outlineDanger" ? Theme.critical : Theme.panelInk

    Text {
        id: labelText
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: root.fontSize
        color: {
            if (root.variant === "primary" || root.variant === "danger") return "#ffffff"
            if (root.variant === "outlineDanger") return Theme.critical
            return Theme.panelInk // neutral | subtle | flat
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
