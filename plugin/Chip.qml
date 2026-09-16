import QtQuick
import qs.Commons

// Base pill-shaped chip: label, selected state, click signal.
Rectangle {
  id: root

  property string label: ""
  property bool selected: false
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  signal clicked()

  width: labelItem.implicitWidth + Style.space(20)
  height: Style.space(30)
  radius: height / 2
  color: selected ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
  border.width: selected ? 1 : 0
  border.color: root.fg

  Text {
    id: labelItem
    anchors.centerIn: parent
    text: root.label
    color: root.fg
    opacity: root.selected ? 1 : 0.85
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
