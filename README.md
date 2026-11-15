# Plain

![Plain editing a Hyprland config](docs/screenshot.png)

Plain is Omarchy's text editor for config files: the editor you don't have to learn. Ctrl+S saves, Ctrl+Z undoes, Ctrl+F finds, and the window closes like any other. It follows the Omarchy theme, font and language, colors Lua, hyprlang/INI, TOML, JSON, YAML, shell and CSS with the theme's own palette, and does nothing else: one window, one file, no tabs, plugins or projects. A sidebar of files (Ctrl+B) is there when you want to move between the configs in one folder.

It's careful with files, because a config file is read by a program that won't forgive a surprise:

- **Saves atomically**, through a temporary file and a rename, so a crash mid-save leaves the old file whole.
- **Follows symlinks** and saves to their target, so linked configs stay linked. If a link starts pointing somewhere else while the file is open, Plain asks before saving.
- **Keeps what the file had**: LF or CRLF line endings, a UTF-8 byte-order mark, and exactly the final newline you see. Opening and saving without edits gives back the same bytes.
- **Never saves over a version you haven't seen.** Right before every save it checks the file on disk; if something else changed or deleted it, Plain asks.
- **Asks before writing in place** when replacing the file would lose something: other hard links, another owner, special permission bits, extended attributes, or a folder you can't write to.
- **Opens only text.** A file that isn't valid UTF-8 isn't opened at all, so it can't be saved back damaged.

Files that belong to root are opened read-only, with the way to edit them: `sudoedit`, which Plain works with as `$SUDO_EDITOR`.

## Use

```sh
plain ~/.config/hypr/bindings.lua
plain +42 /etc/pacman.conf     # open at line 42
plain ~/.config/hypr            # a folder opens with its files beside the text
EDITOR=plain git commit         # waits until the window closes
```

Plain runs in the foreground and exits when its window closes, so it works as `$EDITOR`, `$VISUAL` and `$SUDO_EDITOR`. It opens one file at a time.

## Files

The sidebar shows a folder's files: the folder Plain was opened on, or the open file's. It's hidden until Ctrl+B or the icon at the left of the footer shows it, and opening Plain on a folder starts with it shown. Folders come first, and the list follows the disk as files come and go. Hidden files stay out of the way until Ctrl+H in the files shows them, and show from the start when the folder is inside a hidden one, like `~/.config/hypr`.

- **Click a file, or Enter on it**, to open it. Unsaved changes are asked about first, as with Ctrl+O.
- **Keys**: Ctrl+B shows the files with the keys on the open file, and hides them again; Ctrl+Tab hops between files and text, to keep the files open while editing. In the files, Up/Down, Page Up/Down, Home and End move; Right and Left open and close folders; typing a name's first letters jumps to it; Enter opens a file and goes to the text; Escape goes back to the text.
- **Drag a file or folder onto a folder** to move it there. The open file follows, edits and all.
- **Ctrl+N** names a new file where the sidebar's keys are and opens it; **Ctrl+Shift+N** names a new folder. Without the sidebar, Ctrl+N opens a new window.
- **Delete** asks, then moves the file or folder to the trash, so it can be had back.
- **F2** renames; the open file follows, edits and all.
- **Right-click, or Alt+Enter**, for Rename, Duplicate and Delete. Duplicate puts "name copy.ext" beside it, a folder with everything in it.

## Keyboard

| Key | Action |
| --- | --- |
| Ctrl+S | Save |
| Ctrl+Shift+S | Save as |
| Ctrl+O | Open |
| Ctrl+N | New file (with files shown) or new window |
| Ctrl+Shift+N | New folder |
| Ctrl+B | Show files, with the keys in them, or hide them |
| Ctrl+Tab | Between the files and the text, while the files show |
| Delete | Move the picked file to the trash, after asking |
| F2 | Rename the picked file |
| Alt+Enter | Rename, duplicate or delete the picked file |
| Ctrl+Z / Ctrl+Shift+Z | Undo / redo |
| Ctrl+F | Find |
| Ctrl+H | Find and replace; in the files, show or hide hidden files |
| Enter / Shift+Enter | Next / previous match |
| Ctrl+G | Go to line |
| Ctrl+/ | Comment or uncomment |
| Tab / Shift+Tab | Indent / outdent |
| Alt+Z | Word wrap |
| Ctrl+Plus / Ctrl+Minus / Ctrl+0 | Text size |
| Ctrl+W | Close |
| F1 | Every shortcut |

Text starts at the desktop's text size, the one Omarchy's display panel sets (12px, the terminals' 9pt), and follows it when it changes. Ctrl+Plus and Ctrl+Minus adjust from there, and that adjustment and word wrap (on to start with; Alt+Z turns it off) are remembered in `~/.config/plain/settings.conf`. Nothing else is a setting.

## Install

Omarchy installs Plain as the `plain` package from its package repository (`omarchy-pkg-add plain`).

## Build

Plain is C++ and Qt Quick, built with CMake.

```sh
bin/build      # build/plain
bin/test       # the test suite, offscreen
```

## License

MIT.
