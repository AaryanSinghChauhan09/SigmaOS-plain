import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 980
    height: 720
    minimumWidth: 480
    minimumHeight: 320
    visible: true
    title: (doc.modified ? "● " : "") + doc.fileName + " — " + qsTr("Text Editor")
    color: theme.background
    // The chrome (banner, dialogs, labels) at the desktop's text size too.
    font.pixelSize: theme.textSize

    Material.theme: theme.light ? Material.Light : Material.Dark
    Material.accent: theme.accent
    Material.foreground: theme.foreground
    Material.background: theme.background
    Material.roundedScale: theme.radius

    property bool helpVisible: false
    // The files beside the text: hidden until asked for, unless Plain was
    // opened on a folder. Not remembered, so as $EDITOR it's one file.
    property bool sidebarVisible: false
    // What to do once the unsaved-changes question is answered: "close",
    // "open", or "openPath" for the file picked in the sidebar.
    property string pendingAction: ""
    property string pendingPath: ""
    // Set once the user agreed to lose changes, so closing doesn't ask again.
    property bool discardConfirmed: false

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    Settings {
        id: settings
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/plain/settings.conf"
        // Px above or below the desktop's text size, so the editor keeps
        // following Omarchy's Text size slider after Ctrl+Plus or Ctrl+Minus.
        property int zoom: 0
        property bool wrap: true
    }

    readonly property int textSize: Math.max(8, Math.min(48, theme.textSize + settings.zoom))

    // An untitled file is named in the save dialog first, and finishes in
    // onSaveSelected or onCancelled.
    function save() {
        Qt.inputMethod.commit()
        if (doc.path.length === 0)
            picker.saveFile("")
        else
            afterSave(doc.save())
    }

    // A save asked for while closing or opening another file goes on to do
    // that once it succeeds. Whatever happened, nothing waits on it after.
    function afterSave(saved) {
        const action = pendingAction
        pendingAction = ""
        if (saved && action.length > 0)
            finish(action)
    }

    function saveAs() {
        if (!doc.editable && !doc.locked)
            return
        Qt.inputMethod.commit()
        picker.saveFile(doc.path)
    }

    // Close or open-another, asking first about unsaved changes.
    function request(action) {
        if (doc.modified && !discardConfirmed) {
            pendingAction = action
            unsaved.open()
            return
        }
        finish(action)
    }

    function finish(action) {
        pendingAction = ""
        if (action === "close") {
            discardConfirmed = true
            win.close()
        } else if (action === "open") {
            picker.openFile(doc.path.length > 0 ? folderOf(doc.path) : files.root)
        } else if (action === "openPath") {
            discardConfirmed = false
            doc.open(pendingPath)
            editor.goToLine(1)
        }
    }

    function folderOf(path) { return path.substring(0, path.lastIndexOf("/")) || "/" }

    // A file picked in the sidebar, asking first about unsaved changes.
    function openPath(path) {
        if (path === doc.path) {
            editor.focusText()
            return
        }
        pendingPath = path
        request("openPath")
    }

    // Shows the files of the folder Plain was opened on, or else the open
    // file's, with the open file picked out.
    readonly property string home: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")

    // A path the way the footer shows it, with the home folder as ~.
    function displayPath(path) { return path.startsWith(home + "/") ? "~" + path.substring(home.length) : path === home ? "~" : path }

    function showSidebar(focusTree) {
        if (files.root.length === 0)
            files.root = doc.path.length > 0 ? folderOf(doc.path) : home
        sidebarVisible = true
        sidebar.reveal(doc.path)
        if (focusTree)
            sidebar.focusTree()
    }

    function hideSidebar() {
        sidebarVisible = false
        editor.focusText()
    }

    onClosing: function(close) {
        if (doc.modified && !discardConfirmed) {
            close.accepted = false
            request("close")
        }
    }

    Shortcut { sequence: "Ctrl+S"; context: Qt.ApplicationShortcut; onActivated: win.save() }
    Shortcut { sequence: "Ctrl+Shift+S"; context: Qt.ApplicationShortcut; onActivated: win.saveAs() }
    Shortcut { sequence: "Ctrl+O"; context: Qt.ApplicationShortcut; onActivated: win.request("open") }
    Shortcut { sequences: ["Ctrl+W", "Ctrl+Q"]; context: Qt.ApplicationShortcut; onActivated: win.request("close") }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; onActivated: findBar.show(false) }
    Shortcut { sequence: "Ctrl+H"; context: Qt.ApplicationShortcut; onActivated: findBar.show(true) }
    Shortcut { sequences: ["F3", StandardKey.FindNext]; context: Qt.ApplicationShortcut; onActivated: findBar.next(false) }
    Shortcut { sequences: ["Shift+F3", StandardKey.FindPrevious]; context: Qt.ApplicationShortcut; onActivated: findBar.next(true) }
    Shortcut { sequence: "Ctrl+G"; context: Qt.ApplicationShortcut; onActivated: goToLine.open() }
    Shortcut { sequence: "Ctrl+/"; context: Qt.ApplicationShortcut; enabled: doc.editable; onActivated: editor.toggleComment() }
    Shortcut { sequence: "Alt+Z"; context: Qt.ApplicationShortcut; onActivated: settings.wrap = !settings.wrap }
    // Each key once: listing StandardKey.ZoomIn/ZoomOut as well registers
    // Ctrl++ and Ctrl+- twice, which Qt treats as ambiguous and ignores.
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; context: Qt.ApplicationShortcut; onActivated: if (win.textSize < 48) settings.zoom += 1 }
    Shortcut { sequence: "Ctrl+-"; context: Qt.ApplicationShortcut; onActivated: if (win.textSize > 8) settings.zoom -= 1 }
    Shortcut { sequence: "Ctrl+0"; context: Qt.ApplicationShortcut; onActivated: settings.zoom = 0 }
    // The keys go with the files: shown, they're in the tree on the open
    // file; hidden, they're back in the text. Ctrl+Tab hops between the two
    // to keep the files open while editing, and Escape in the tree goes
    // back to the text.
    Shortcut { sequence: "Ctrl+B"; context: Qt.ApplicationShortcut; onActivated: win.sidebarVisible ? win.hideSidebar() : win.showSidebar(true) }
    Shortcut {
        sequence: "Ctrl+Tab"
        context: Qt.ApplicationShortcut
        enabled: win.sidebarVisible
        onActivated: sidebar.treeFocused ? editor.focusText() : sidebar.focusTree()
    }
    // With the files showing, a new file named in place where they're at;
    // otherwise another window, since this one holds one file.
    Shortcut {
        sequence: "Ctrl+N"
        context: Qt.ApplicationShortcut
        onActivated: win.sidebarVisible ? namePrompt.ask(false) : launcher.newWindow()
    }
    Shortcut {
        sequence: "Ctrl+Shift+N"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!win.sidebarVisible)
                win.showSidebar(false)
            namePrompt.ask(true)
        }
    }
    Shortcut { sequences: ["F1", "Ctrl+?"]; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: win.helpVisible; onActivated: win.helpVisible = false }

    Connections {
        target: picker
        function onOpenSelected(url) {
            win.discardConfirmed = false
            doc.openUrl(url)
            editor.goToLine(1)
        }
        function onSaveSelected(url) { win.afterSave(doc.saveAsUrl(url)) }
        function onCancelled() { win.afterSave(false) }
        function onFailed(message) {
            pickerError.text = message
            win.afterSave(false)
        }
    }

    Component.onCompleted: {
        doc.attach(editor.area)
        if (startPath.length > 0)
            doc.open(startPath)
        editor.goToLine(Math.max(1, startLine))
        if (startFolder.length > 0) {
            files.root = startFolder
            showSidebar(true)
        }
    }

    // Right-to-left languages mirror the chrome; the text keeps its own
    // direction line by line.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Sidebar {
                id: sidebar
                objectName: "sidebar"
                visible: win.sidebarVisible
                Layout.fillHeight: true
                Layout.preferredWidth: preferredWidth
                onOpenRequested: function(path) { win.openPath(path) }
                onDeleteRequested: function(row) { deleteConfirm.ask(row) }
                onHideRequested: win.hideSidebar()
                onDone: editor.focusText()
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Banner {
                    Layout.fillWidth: true
                    onSaveAsRequested: win.saveAs()
                    onDone: editor.focusText()
                }

                Label {
                    id: pickerError
                    Layout.fillWidth: true
                    Layout.margins: 10
                    visible: text.length > 0
                    color: theme.red
                    wrapMode: Text.Wrap
                    MouseArea { anchors.fill: parent; onClicked: pickerError.text = "" }
                }

                FindBar {
                    id: findBar
                    Layout.fillWidth: true
                    editor: editor
                }

                EditorView {
                    id: editor
                    objectName: "editorView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fontSize: win.textSize
                    wrap: settings.wrap
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: true

                    // Opened on a folder, nothing is open until a file is
                    // picked. Plain without a file is an untitled document
                    // to type in, so it says nothing there.
                    Label {
                        anchors.centerIn: parent
                        visible: startFolder.length > 0 && win.sidebarVisible && doc.path.length === 0 && editor.area.length === 0
                        text: qsTr("Pick a file")
                        color: theme.secondaryForeground
                        opacity: 0.7
                    }
                }

                Footer {
                    Layout.fillWidth: true
                    sidebarButton: !win.sidebarVisible
                    onSidebarRequested: win.showSidebar(true)
                    onSaveRequested: win.save()
                    onOpenRequested: win.request("open")
                    onHelpRequested: win.helpVisible = !win.helpVisible
                }
            }
        }

        HelpOverlay {
            anchors.fill: parent
            visible: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }

    GoToLine {
        id: goToLine
        anchors.centerIn: parent
        onAccepted: function(line) { editor.goToLine(line) }
        onClosed: editor.focusText()
    }

    // A new file or folder's name, asked in the middle like Delete's
    // question, for where the sidebar's keys are. A file opens once made.
    Popup {
        id: namePrompt
        anchors.centerIn: parent
        width: Math.min(440, win.width - 48)
        modal: true
        focus: true
        padding: 22
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
        // There and gone at once: Plain animates nothing.
        enter: Transition {}
        exit: Transition {}

        property bool folder: false
        property string inFolder: ""
        property string error: ""
        // Where the keys go back to: the new folder in the files, the new
        // file's text, or where they were.
        property var returnFocus: null
        property string made: ""

        function ask(folder) {
            namePrompt.folder = folder
            returnFocus = win.activeFocusItem
            made = ""
            inFolder = sidebar.newItemFolder()
            error = ""
            nameField.text = ""
            open()
        }

        function create() {
            const made = files.create(inFolder, nameField.text, folder)
            if (made.error) {
                error = made.error
                nameField.forceActiveFocus()
                return
            }
            namePrompt.made = made.path
            close()
        }

        onOpened: nameField.forceActiveFocus()
        onClosed: {
            if (made.length === 0) {
                if (returnFocus)
                    returnFocus.forceActiveFocus()
                return
            }
            sidebar.reveal(made)
            if (folder)
                sidebar.focusTree()
            else
                win.openPath(made)
        }

        background: DialogBackground {}

        contentItem: ColumnLayout {
            spacing: 12
            Label {
                text: namePrompt.folder ? qsTr("New folder") : qsTr("New file")
                color: theme.brightForeground
                font.pixelSize: Math.round(theme.textSize * 1.333)
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("In %1").arg(win.displayPath(namePrompt.inFolder))
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                color: theme.secondaryForeground
            }
            // The find bar's field: Material's TextField floats its label.
            FindField {
                id: nameField
                objectName: "newName"
                Layout.fillWidth: true
                placeholder: namePrompt.folder ? qsTr("Folder name") : qsTr("File name")
                onTextEdited: namePrompt.error = ""
                Keys.onReturnPressed: namePrompt.create()
                Keys.onEnterPressed: namePrompt.create()
            }
            Label {
                Layout.fillWidth: true
                visible: namePrompt.error.length > 0
                text: namePrompt.error
                textFormat: Text.PlainText
                color: theme.red
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 6
                spacing: 8
                DialogButton {
                    text: qsTr("Cancel")
                    onClicked: namePrompt.close()
                }
                DialogButton {
                    primary: true
                    text: qsTr("Create")
                    onClicked: namePrompt.create()
                }
            }
        }
    }

    // Delete from the sidebar: what goes, and that it goes to the trash.
    // Escape cancels; C and D pick, with or without Alt, and Enter deletes.
    Popup {
        id: deleteConfirm
        anchors.centerIn: parent
        width: Math.min(440, win.width - 48)
        modal: true
        focus: true
        padding: 22
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
        // There and gone at once: Plain animates nothing.
        enter: Transition {}
        exit: Transition {}

        property int row: -1
        property string path: ""
        property string name: ""
        property bool folder: false
        // The open file goes with it, so its unsaved changes would too.
        readonly property bool holdsOpenFile: path.length > 0 && (doc.path === path || doc.path.startsWith(path + "/"))

        function ask(row) {
            deleteConfirm.row = row
            path = files.pathAt(row)
            name = path.substring(path.lastIndexOf("/") + 1)
            folder = files.isFolder(row)
            open()
        }

        function confirm() {
            close()
            const affectsDoc = holdsOpenFile
            const error = files.trash(row)
            if (error.length > 0) {
                pickerError.text = qsTr("Couldn't delete %1: %2").arg(name).arg(error)
            } else if (affectsDoc) {
                doc.close()
                win.discardConfirmed = false
            }
        }

        onOpened: deleteButton.forceActiveFocus()
        onClosed: sidebar.focusTree()

        Shortcut { sequences: ["C", "Alt+C"]; enabled: deleteConfirm.opened; onActivated: deleteConfirm.close() }
        Shortcut { sequences: ["D", "Alt+D"]; enabled: deleteConfirm.opened; onActivated: deleteConfirm.confirm() }

        background: DialogBackground {}

        contentItem: ColumnLayout {
            spacing: 12
            Label {
                Layout.fillWidth: true
                text: qsTr("Delete %1?").arg(deleteConfirm.name)
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                color: theme.brightForeground
                font.pixelSize: Math.round(theme.textSize * 1.333)
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: (deleteConfirm.folder
                       ? qsTr("The folder and everything in it will be moved to the trash.")
                       : qsTr("The file will be moved to the trash."))
                      + (deleteConfirm.holdsOpenFile && doc.modified ? " " + qsTr("Unsaved changes to %1 will be lost.").arg(doc.fileName) : "")
                color: theme.foreground
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 14
                spacing: 8
                DialogButton {
                    id: deleteCancelButton
                    text: qsTr("Cancel")
                    formattedText: qsTr("<u>C</u>ancel")
                    KeyNavigation.tab: deleteButton
                    onClicked: deleteConfirm.close()
                }
                DialogButton {
                    id: deleteButton
                    primary: true
                    text: qsTr("Delete")
                    formattedText: qsTr("<u>D</u>elete")
                    KeyNavigation.tab: deleteCancelButton
                    onClicked: deleteConfirm.confirm()
                }
            }
        }
    }

    // Unsaved changes: Cancel, Discard, Save, laid out like Omawrite's.
    // Escape cancels; C, D and S pick, with or without Alt. There is nothing to
    // type into here, so the bare letter is enough.
    Popup {
        id: unsaved
        anchors.centerIn: parent
        width: Math.min(440, win.width - 48)
        modal: true
        focus: true
        padding: 22
        onOpened: saveButton.forceActiveFocus()
        // Closed by Escape or a click outside, rather than a choice: nothing
        // waits any more. A choice is only cleared here, since the popup
        // finishes closing after the choice's own work has started.
        onClosed: {
            if (win.pendingAction.length > 0 && !choosing) {
                win.pendingAction = ""
                editor.focusText()
            }
            choosing = false
        }
        property bool choosing: false
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
        // There and gone at once: Plain animates nothing.
        enter: Transition {}
        exit: Transition {}

        function choose(choice) {
            choosing = true
            close()
            if (choice === "save") {
                // A failed save leaves the banner up and the window open.
                win.save()
            } else if (choice === "discard") {
                win.discardConfirmed = win.pendingAction === "close"
                win.finish(win.pendingAction)
            } else {
                win.pendingAction = ""
                editor.focusText()
            }
        }

        Shortcut { sequences: ["C", "Alt+C"]; enabled: unsaved.opened; onActivated: unsaved.choose("cancel") }
        Shortcut { sequences: ["D", "Alt+D"]; enabled: unsaved.opened; onActivated: unsaved.choose("discard") }
        Shortcut { sequences: ["S", "Alt+S"]; enabled: unsaved.opened; onActivated: unsaved.choose("save") }

        background: DialogBackground {}

        contentItem: ColumnLayout {
            spacing: 12
            Label {
                text: qsTr("Unsaved changes")
                color: theme.brightForeground
                font.pixelSize: Math.round(theme.textSize * 1.333)
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: win.pendingAction === "open" || win.pendingAction === "openPath"
                    ? qsTr("Save changes to %1 before opening another file?").arg(doc.fileName)
                    : qsTr("Save changes to %1 before closing?").arg(doc.fileName)
                color: theme.foreground
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 14
                spacing: 8
                DialogButton {
                    id: cancelButton
                    text: qsTr("Cancel")
                    formattedText: qsTr("<u>C</u>ancel")
                    KeyNavigation.tab: discardButton
                    onClicked: unsaved.choose("cancel")
                }
                DialogButton {
                    id: discardButton
                    text: qsTr("Discard")
                    formattedText: qsTr("<u>D</u>iscard")
                    KeyNavigation.tab: saveButton
                    onClicked: unsaved.choose("discard")
                }
                DialogButton {
                    id: saveButton
                    primary: true
                    text: qsTr("Save")
                    formattedText: qsTr("<u>S</u>ave")
                    KeyNavigation.tab: cancelButton
                    onClicked: unsaved.choose("save")
                }
            }
        }
    }
}
