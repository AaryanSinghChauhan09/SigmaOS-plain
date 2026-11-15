import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The files of a folder, beside the text: the folder Plain was opened on, or
// the open file's. Folders fold open in place; a file opens in the editor,
// asking first about unsaved changes as Open does. Files and folders drag
// into other folders, and new ones (Ctrl+N, Ctrl+Shift+N) go where the keys
// are. The full height of the window, with the icon that hides it
// at its foot, where the footer is.
Rectangle {
    id: sidebar

    signal openRequested(string path)
    // Delete on a row: Main asks first.
    signal deleteRequested(int row)
    signal hideRequested()
    // Escape: back to the text.
    signal done()

    // Dragged wider or narrower by its edge, for as long as Plain is open.
    property real preferredWidth: 232
    // The row the keys are on, kept by path across a refresh from disk.
    property string currentPath: ""
    readonly property bool treeFocused: list.activeFocus
    // Letters typed in the tree, to jump to the name they start; forgotten
    // after a pause.
    property string typed: ""

    color: theme.darkBackground

    function focusTree() {
        if (list.currentIndex < 0 && list.count > 0)
            list.currentIndex = 0
        list.forceActiveFocus()
    }

    // Opens the folders down to a path and puts the keys on it.
    function reveal(path) {
        const row = files.reveal(path)
        if (row >= 0) {
            list.currentIndex = row
            list.positionViewAtIndex(row, ListView.Contain)
        }
    }

    // Where a new file or folder goes: into the folder the keys are on, or
    // beside the file they're on.
    function newItemFolder() { return files.folderAt(list.currentIndex) }

    // Moves a row into a folder; the open file follows, edits and all.
    function moveInto(row, folder) {
        const from = files.pathAt(row)
        const name = from.substring(from.lastIndexOf("/") + 1)
        const error = files.move(row, folder)
        if (error.length > 0) {
            moveError.text = error
            moveError.visible = true
            return
        }
        const to = folder + "/" + name
        if (from !== to && (doc.path === from || doc.path.startsWith(from + "/")))
            doc.relocate(to + doc.path.substring(from.length))
        reveal(to)
    }

    // A folder folds open or closed; a file opens. Opened with Space, the
    // keys stay in the tree to look at the next one.
    function activate(row, stay) {
        if (row < 0)
            return
        list.currentIndex = row
        if (files.isFolder(row)) {
            files.toggle(row)
            focusTree()
        } else {
            sidebar.openRequested(files.pathAt(row))
            if (stay)
                Qt.callLater(focusTree)
        }
    }

    function jumpTo(text) {
        typed = typed + text.toLowerCase()
        typingPause.restart()
        // A first letter looks past the row the keys are on, so pressing it
        // again steps through the names it starts.
        const start = typed.length === 1 ? list.currentIndex + 1 : list.currentIndex
        const row = files.find(typed, start)
        if (row >= 0) {
            list.currentIndex = row
            list.positionViewAtIndex(row, ListView.Contain)
        }
    }

    Timer { id: typingPause; interval: 800; onTriggered: sidebar.typed = "" }

    Connections {
        target: doc
        function onFileChanged() { if (sidebar.visible) sidebar.reveal(doc.path) }
    }

    Connections {
        target: files
        function onRefreshed() {
            const row = files.indexOf(sidebar.currentPath)
            list.currentIndex = row >= 0 ? row : Math.min(list.currentIndex, list.count - 1)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: list
            objectName: "fileList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            topMargin: 13
            bottomMargin: 8
            clip: true
            model: files
            currentIndex: -1
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: sidebar.currentPath = files.pathAt(currentIndex)

            ScrollBar.vertical: ScrollBar { policy: list.visibleArea.heightRatio < 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

            // Dropped below the rows: into the top folder.
            DropArea {
                parent: list
                anchors.fill: parent
                z: -1
                keys: ["plain-file"]
                onDropped: function(drop) { Qt.callLater(sidebar.moveInto, drop.source.row, files.root) }
            }

            Keys.onPressed: function(event) {
                const row = list.currentIndex
                if (event.key === Qt.Key_Right) {
                    // Opens a folder, then steps into it.
                    if (files.isFolder(row) && !files.isExpanded(row))
                        files.expand(row)
                    else if (files.isExpanded(row) && row + 1 < list.count)
                        list.currentIndex = row + 1
                } else if (event.key === Qt.Key_Left) {
                    // Folds a folder, then steps out to the one it's in.
                    if (files.isExpanded(row))
                        files.collapse(row)
                    else if (files.parentOf(row) >= 0)
                        list.currentIndex = files.parentOf(row)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sidebar.activate(row, false)
                } else if (event.key === Qt.Key_Space) {
                    sidebar.typed = ""
                    sidebar.activate(row, true)
                } else if (event.key === Qt.Key_Home) {
                    list.currentIndex = 0
                } else if (event.key === Qt.Key_End) {
                    list.currentIndex = list.count - 1
                } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                    const page = Math.max(1, Math.floor(list.height / Math.round(theme.textSize * 2)) - 1)
                    list.currentIndex = Math.max(0, Math.min(list.count - 1, row + (event.key === Qt.Key_PageUp ? -page : page)))
                } else if (event.text.length > 0 && event.text.trim().length > 0
                           && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    sidebar.jumpTo(event.text)
                } else if (event.key === Qt.Key_Delete && row >= 0) {
                    sidebar.deleteRequested(row)
                } else if (event.key === Qt.Key_Escape) {
                    sidebar.done()
                } else {
                    return
                }
                event.accepted = true
            }

            delegate: Item {
                id: row

                required property int index
                required property string name
                required property string path
                required property int depth
                required property bool folder
                required property bool expanded

                // Where a row dropped here goes: into a folder, or beside a file.
                readonly property string dropFolder: folder ? path : path.substring(0, path.lastIndexOf("/"))

                readonly property bool open: !folder && path === doc.path
                readonly property color ink: open ? theme.brightForeground : theme.foreground

                width: ListView.view.width
                height: Math.round(theme.textSize * 2)

                Rectangle {
                    anchors.fill: parent
                    // Where the keys are, while they're in the tree.
                    border.width: row.ListView.isCurrentItem && list.activeFocus ? 1 : 0
                    border.color: theme.accent
                    color: drop.containsDrag ? win.tint(theme.accent, 0.3)
                         : row.open ? win.tint(theme.accent, 0.22)
                         : row.ListView.isCurrentItem && list.activeFocus ? win.tint(theme.foreground, 0.08)
                         : hover.containsMouse ? win.tint(theme.foreground, 0.04)
                         : "transparent"
                }

                // The open file's edge, in the accent.
                Rectangle {
                    visible: row.open
                    anchors.left: parent.left
                    width: 2
                    height: parent.height
                    color: theme.accent
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6 + row.depth * 16
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Item {
                        width: 16
                        height: 16
                        LineIcon {
                            visible: row.folder
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            name: "chevron"
                            color: theme.secondaryForeground
                            rotation: row.expanded ? 90 : (sidebar.LayoutMirroring.enabled ? 180 : 0)
                        }
                    }

                    Item { width: 2; height: 1 }

                    LineIcon {
                        width: 15
                        height: 15
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.folder ? "folder" : "file"
                        color: row.open ? theme.accent : theme.secondaryForeground
                        opacity: row.open ? 1 : 0.8
                    }

                    Item { width: 7; height: 1 }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40 - (dot.visible ? dot.width : 0)
                        text: row.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: row.ink
                        opacity: row.open ? 1 : 0.85
                    }

                    // Unsaved, as the title's dot.
                    Label {
                        id: dot
                        visible: row.open && doc.modified
                        anchors.verticalCenter: parent.verticalCenter
                        text: "●"
                        color: theme.accent
                        font.pixelSize: Math.round(theme.textSize * 0.75)
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sidebar.activate(row.index, false)

                    // Dragged onto a folder (or a file in one) to move there.
                    drag.target: dragProxy
                    drag.threshold: 6
                    onPressed: function(mouse) {
                        const at = row.mapToItem(sidebar, 0, 0)
                        dragProxy.x = at.x
                        dragProxy.y = at.y
                        dragProxy.row = row.index
                        dragProxy.name = row.name
                        dragProxy.folder = row.folder
                        dragProxy.Drag.hotSpot.x = mouse.x
                        dragProxy.Drag.hotSpot.y = mouse.y
                    }
                    drag.onActiveChanged: if (drag.active) dragProxy.Drag.active = true
                    onReleased: {
                        if (dragProxy.Drag.active) {
                            dragProxy.Drag.drop()
                            dragProxy.Drag.active = false
                        }
                    }
                }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    keys: ["plain-file"]
                    // After the drop finishes: moving rebuilds the rows,
                    // this one and the dragged one included.
                    onDropped: function(event) {
                        event.accept()
                        Qt.callLater(sidebar.moveInto, event.source.row, row.dropFolder)
                    }
                }
            }
        }

        // The sidebar's foot, level with the footer: the icon that hides it.
        Item {
            Layout.fillWidth: true
            implicitHeight: 32

            FooterIconButton {
                objectName: "hideSidebarButton"
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                iconName: "sidebarOpen"
                iconColor: theme.secondaryForeground
                opacity: 0.7
                tooltip: qsTr("Hide files (Ctrl+B)")
                onClicked: sidebar.hideRequested()
            }
        }
    }

    // What's being dragged, following the pointer.
    Rectangle {
        id: dragProxy
        property int row: -1
        property string name: ""
        property bool folder: false
        visible: Drag.active
        z: 10
        width: proxyRow.implicitWidth + 20
        height: Math.round(theme.textSize * 2)
        radius: 3
        color: win.tint(theme.accent, 0.3)
        Drag.keys: ["plain-file"]
        Drag.source: dragProxy

        Row {
            id: proxyRow
            anchors.centerIn: parent
            spacing: 7
            LineIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 15
                height: 15
                name: dragProxy.folder ? "folder" : "file"
                color: theme.accent
            }
            Label {
                text: dragProxy.name
                textFormat: Text.PlainText
                color: theme.brightForeground
            }
        }
    }

    // Why a drop didn't move anything, until the next click.
    Label {
        id: moveError
        visible: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        anchors.bottomMargin: 40
        padding: 8
        wrapMode: Text.Wrap
        color: theme.red
        background: Rectangle { color: theme.background; radius: 3 }
        MouseArea { anchors.fill: parent; onClicked: moveError.visible = false }
        Timer { running: moveError.visible; interval: 4000; onTriggered: moveError.visible = false }
    }

    // The line between it and the text, and the edge that resizes it.
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: win.tint(theme.foreground, 0.08)
    }

    MouseArea {
        anchors.right: parent.right
        anchors.rightMargin: -3
        width: 7
        height: parent.height
        cursorShape: Qt.SplitHCursor
        property real startX: 0
        property real startWidth: 0
        onPressed: function(mouse) {
            startX = mapToItem(null, mouse.x, 0).x
            startWidth = sidebar.preferredWidth
        }
        onPositionChanged: function(mouse) {
            const moved = mapToItem(null, mouse.x, 0).x - startX
            const width = startWidth + (sidebar.LayoutMirroring.enabled ? -moved : moved)
            sidebar.preferredWidth = Math.max(140, Math.min(width, win.width - 280))
        }
    }
}
