// Task 27g: shared component library. The small-caps bold label used at
// the top of (almost) every Settings tab - was hand-repeated ~30 times
// across Settings.qml before this existed.
import QtQuick
import "../"

Text {
    color: Theme.textSecondary
    font.pixelSize: 16
    font.bold: true
}
