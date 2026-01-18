import QtQuick

MouseArea {
    signal hoverChanged(bool hovering)
    z: 1000
    anchors.fill: parent
    hoverEnabled: true
    propagateComposedEvents: true
    acceptedButtons: Qt.NoButton
    onContainsMouseChanged: hoverChanged(containsMouse)
}
