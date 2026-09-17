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
    property int fontSize: 15
    signal clicked()

    implicitWidth: labelText.implicitWidth + 20
    implicitHeight: 33
    radius: 6
    opacity: enabled ? 1 : 0.4

    // Real filled variants (primary/danger/subtle) get a raised, glossy
    // gradient instead of a flat fill - Akash's feedback (8 Sept 2026):
    // buttons "feel cheap" flat. neutral/outlineDanger/flat stay flat on
    // purpose - they're meant to read as unselected/quiet, a gloss there
    // would fight that.
    readonly property color _base: {
        if (variant === "primary") return WorkspaceState.activeColor()
        if (variant === "danger") return Theme.critical
        if (variant === "subtle") return Theme.surfaceRaised
        return Theme.panel // neutral | outlineDanger | flat
    }
    readonly property bool _glossy: variant === "primary" || variant === "danger" || variant === "subtle"

    // Real tactile feedback (Akash, 17 Sept 2026: buttons should "work
    // smooth with mouse" and "give a 3D feel" - the gloss above already
    // reads as raised at rest, but nothing responded to the mouse at all).
    // Hover lifts the button (scale up + brighter gloss); press flattens
    // it back down into the panel (scale down + darker) - the same
    // physical metaphor a real button gives. Plain scale+gradient shift,
    // no GraphicalEffects dependency needed.
    scale: buttonMouse.pressed ? 0.96 : (buttonMouse.containsMouse ? 1.03 : 1.0)
    Behavior on scale { enabled: !Theme.reducedMotion; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    gradient: Gradient {
        GradientStop {
            position: 0.0
            color: root._glossy
                ? Qt.lighter(root._base, buttonMouse.pressed ? 1.05 : (buttonMouse.containsMouse ? 1.35 : 1.22))
                : (buttonMouse.containsMouse ? Qt.rgba(Theme.panelInk.r, Theme.panelInk.g, Theme.panelInk.b, 0.08) : root._base)
        }
        GradientStop {
            position: 1.0
            color: root._glossy ? Qt.darker(root._base, buttonMouse.pressed ? 1.18 : 1.08) : root._base
        }
    }
    border.width: (variant === "neutral" || variant === "outlineDanger") ? 1 : 0
    border.color: variant === "outlineDanger" ? Theme.critical : Theme.panelInk

    Text {
        id: labelText
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: root.fontSize
        font.family: Theme.uiFont
        color: {
            if (root.variant === "primary" || root.variant === "danger") return "#ffffff"
            if (root.variant === "outlineDanger") return Theme.critical
            return Theme.panelInk // neutral | subtle | flat
        }
    }
    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
