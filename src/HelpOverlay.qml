import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Every shortcut, one keypress away (F1).
Rectangle {
    id: overlay

    signal dismissed()

    color: Qt.rgba(0, 0, 0, 0.55)

    property var shortcuts: [
        ["Ctrl + S", qsTr("Save")],
        ["Ctrl + Shift + S", qsTr("Save as")],
        ["Ctrl + O", qsTr("Open")],
        ["Ctrl + N", qsTr("New file, or new window")],
        ["Ctrl + Shift + N", qsTr("New folder")],
        ["Ctrl + B", qsTr("Show or hide files")],
        ["Ctrl + Tab", qsTr("Between files and text")],
        ["F2", qsTr("Rename in files")],
        ["Delete", qsTr("Delete from files")],
        ["Alt + Enter", qsTr("Rename, duplicate or delete in files")],
        ["Ctrl + Z / Ctrl + Shift + Z", qsTr("Undo / redo")],
        ["Ctrl + F", qsTr("Find")],
        ["Ctrl + H", qsTr("Find and replace (in files: hidden files)")],
        ["Enter / Shift + Enter", qsTr("Next / previous match")],
        ["Ctrl + Enter", qsTr("Replace all")],
        ["Ctrl + G", qsTr("Go to line")],
        ["Ctrl + /", qsTr("Comment or uncomment")],
        ["Tab / Shift + Tab", qsTr("Indent / outdent")],
        ["Alt + Z", qsTr("Word wrap")],
        ["Ctrl + Plus / Ctrl + Minus", qsTr("Text size")],
        ["Ctrl + W", qsTr("Close")],
        ["F1", qsTr("Show these shortcuts")]
    ]

    MouseArea { anchors.fill: parent; onClicked: overlay.dismissed() }

    DialogBackground {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 560)
        // As tall as the list, or as the window allows, with the rest a
        // scroll away.
        height: Math.min(parent.height - 48, title.implicitHeight + content.spacing + grid.implicitHeight + 56)

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Label { id: title; text: qsTr("Keyboard shortcuts"); color: theme.brightForeground; font.pixelSize: Math.round(theme.textSize * 1.333); font.weight: Font.DemiBold }

            Flickable {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: grid.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: list.visibleArea.heightRatio < 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }

            GridLayout {
                id: grid
                width: list.width
                columns: 2
                rowSpacing: 10
                columnSpacing: 28
                Repeater {
                    model: overlay.shortcuts
                    delegate: Label {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 0
                        text: modelData[0]
                        color: theme.accent
                    }
                }
                Repeater {
                    model: overlay.shortcuts
                    delegate: Label {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 1
                        Layout.fillWidth: true
                        text: modelData[1]
                        color: theme.foreground
                    }
                }
            }
            }
        }
    }
}
