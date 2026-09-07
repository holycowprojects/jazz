// Task 27g: shared component library. The sidebar-item / list-row pattern
// (label + selected-state highlight + optional trailing marker + click) -
// was hand-repeated for the Settings sidebar's 18 sections before this
// existed.
import QtQuick
import "../"

Rectangle {
    id: root
    property string label: ""
    property bool selected: false
    property bool showMarker: false
    signal clicked()

    width: parent ? parent.width : 160
    height: 30; radius: 6
    color: selected ? WorkspaceState.activeColor() : "#00000000"

    Text {
        anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.selected ? "#ffffff" : Theme.panelInk
        font.pixelSize: 12
    }
    Text {
        visible: root.showMarker
        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        text: "•"; color: Theme.textSecondary; font.pixelSize: 12
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
