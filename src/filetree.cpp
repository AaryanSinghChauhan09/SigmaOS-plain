#include "filetree.h"

#include <QCollator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <algorithm>

FileTree::FileTree(QObject *parent) : QAbstractListModel(parent) {
    // Saving a file is several changes in a row (a temporary file, a rename).
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(150);
    connect(&m_debounce, &QTimer::timeout, this, &FileTree::rebuild);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_debounce, qOverload<>(&QTimer::start));
}

void FileTree::setRoot(const QString &root) {
    const QString clean = root.isEmpty() ? QString() : QDir::cleanPath(QFileInfo(root).absoluteFilePath());
    if (clean == m_root)
        return;
    m_root = clean;
    m_expanded.clear();
    rebuild();
    emit rootChanged();
}

int FileTree::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : int(m_rows.size());
}

QVariant FileTree::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    const Entry &entry = m_rows.at(index.row());
    switch (role) {
    case NameRole: return entry.name;
    case PathRole: return entry.path;
    case DepthRole: return entry.depth;
    case FolderRole: return entry.folder;
    case ExpandedRole: return entry.folder && m_expanded.contains(entry.path);
    }
    return {};
}

QHash<int, QByteArray> FileTree::roleNames() const {
    return {{NameRole, "name"}, {PathRole, "path"}, {DepthRole, "depth"},
            {FolderRole, "folder"}, {ExpandedRole, "expanded"}};
}

QVector<FileTree::Entry> FileTree::rowsUnder(const QString &folder, int depth) const {
    QFileInfoList infos = QDir(folder).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot);
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(infos.begin(), infos.end(), [&](const QFileInfo &a, const QFileInfo &b) {
        if (a.isDir() != b.isDir())
            return a.isDir();
        return collator.compare(a.fileName(), b.fileName()) < 0;
    });

    QVector<Entry> rows;
    for (const QFileInfo &info : infos) {
        const Entry entry{info.fileName(), info.absoluteFilePath(), depth, info.isDir()};
        rows << entry;
        if (entry.folder && m_expanded.contains(entry.path))
            rows << rowsUnder(entry.path, depth + 1);
    }
    return rows;
}

void FileTree::rebuild() {
    // Folders removed from disk stop being open, so they don't come back open.
    for (auto it = m_expanded.begin(); it != m_expanded.end();)
        it = QFileInfo(*it).isDir() ? std::next(it) : m_expanded.erase(it);
    beginResetModel();
    m_rows = m_root.isEmpty() ? QVector<Entry>() : rowsUnder(m_root, 0);
    endResetModel();
    rewatch();
    emit refreshed();
}

void FileTree::rewatch() {
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());
    QStringList folders;
    if (!m_root.isEmpty())
        folders << m_root;
    for (const QString &folder : m_expanded)
        folders << folder;
    if (!folders.isEmpty())
        m_watcher.addPaths(folders);
}

void FileTree::toggle(int row) {
    if (isExpanded(row))
        collapse(row);
    else
        expand(row);
}

void FileTree::expand(int row) {
    if (!isFolder(row) || isExpanded(row))
        return;
    const Entry entry = m_rows.at(row);
    m_expanded.insert(entry.path);
    const QVector<Entry> children = rowsUnder(entry.path, entry.depth + 1);
    if (!children.isEmpty()) {
        beginInsertRows({}, row + 1, row + int(children.size()));
        for (int i = 0; i < children.size(); ++i)
            m_rows.insert(row + 1 + i, children.at(i));
        endInsertRows();
    }
    const QModelIndex at = index(row);
    emit dataChanged(at, at, {ExpandedRole});
    rewatch();
}

void FileTree::collapse(int row) {
    if (!isExpanded(row))
        return;
    const int depth = m_rows.at(row).depth;
    int end = row + 1;
    while (end < m_rows.size() && m_rows.at(end).depth > depth)
        ++end;
    // Folders inside close with it, so it opens the way it was first shown.
    for (int i = row; i < end; ++i)
        m_expanded.remove(m_rows.at(i).path);
    if (end > row + 1) {
        beginRemoveRows({}, row + 1, end - 1);
        m_rows.remove(row + 1, end - row - 1);
        endRemoveRows();
    }
    const QModelIndex at = index(row);
    emit dataChanged(at, at, {ExpandedRole});
    rewatch();
}

int FileTree::reveal(const QString &path) {
    if (m_root.isEmpty() || path.isEmpty())
        return -1;
    const QString clean = QDir::cleanPath(QFileInfo(path).absoluteFilePath());
    if (!clean.startsWith(m_root + "/"))
        return -1;
    // Each folder between the root and the file, from the top down.
    const QStringList parts = clean.mid(m_root.size() + 1).split('/');
    QString folder = m_root;
    for (int i = 0; i + 1 < parts.size(); ++i) {
        folder += "/" + parts.at(i);
        const int row = indexOf(folder);
        if (row < 0)
            return -1;
        expand(row);
    }
    return indexOf(clean);
}

int FileTree::indexOf(const QString &path) const {
    const QString clean = QDir::cleanPath(QFileInfo(path).absoluteFilePath());
    for (int i = 0; i < m_rows.size(); ++i)
        if (m_rows.at(i).path == clean)
            return i;
    return -1;
}

int FileTree::parentOf(int row) const {
    if (row < 0 || row >= m_rows.size())
        return -1;
    const int depth = m_rows.at(row).depth;
    for (int i = row - 1; i >= 0; --i)
        if (m_rows.at(i).depth < depth)
            return i;
    return -1;
}

bool FileTree::isFolder(int row) const {
    return row >= 0 && row < m_rows.size() && m_rows.at(row).folder;
}

bool FileTree::isExpanded(int row) const {
    return isFolder(row) && m_expanded.contains(m_rows.at(row).path);
}

QString FileTree::pathAt(int row) const {
    return row >= 0 && row < m_rows.size() ? m_rows.at(row).path : QString();
}

QString FileTree::trash(int row) {
    const QString path = pathAt(row);
    if (path.isEmpty())
        return tr("Nothing to delete");
    QFile file(path);
    if (!file.moveToTrash())
        return file.errorString().isEmpty() ? tr("It couldn't be moved to the trash") : file.errorString();
    m_debounce.stop();
    rebuild();
    return {};
}

QString FileTree::nameProblem(const QString &folder, const QString &name) const {
    if (name.trimmed().isEmpty())
        return tr("Give it a name");
    if (name.contains('/') || name == "." || name == "..")
        return tr("A name can't be . or .. or have a / in it");
    if (QFileInfo::exists(folder + "/" + name) || QFileInfo(folder + "/" + name).isSymLink())
        return tr("%1 already exists here").arg(name);
    return {};
}

QString FileTree::move(int row, const QString &folder) {
    const QString from = pathAt(row);
    if (from.isEmpty())
        return tr("Nothing to move");
    const QString into = QDir::cleanPath(QFileInfo(folder).absoluteFilePath());
    if (!QFileInfo(into).isDir())
        return tr("%1 isn't a folder").arg(into);
    if (QFileInfo(from).absolutePath() == into)
        return {};
    if (into == from || into.startsWith(from + "/"))
        return tr("A folder can't go inside itself");
    const QString name = m_rows.at(row).name;
    if (const QString problem = nameProblem(into, name); !problem.isEmpty())
        return problem;
    // A rename, so a folder moves whole and a file keeps its links and
    // permissions. Across file systems it fails rather than half-copying.
    if (!QDir().rename(from, into + "/" + name))
        return tr("%1 couldn't be moved there").arg(name);
    if (m_expanded.remove(from))
        m_expanded.insert(into + "/" + name);
    if (into != m_root)
        m_expanded.insert(into);
    m_debounce.stop();
    rebuild();
    return {};
}

QString FileTree::folderAt(int row) const {
    if (row < 0 || row >= m_rows.size())
        return m_root;
    const Entry &entry = m_rows.at(row);
    return entry.folder ? entry.path : QFileInfo(entry.path).absolutePath();
}

QVariantMap FileTree::create(const QString &folder, const QString &name, bool isFolder) {
    if (const QString problem = nameProblem(folder, name); !problem.isEmpty())
        return {{"error", problem}};
    const QString path = QDir::cleanPath(folder + "/" + name);
    bool made;
    if (isFolder) {
        made = QDir().mkdir(path);
    } else {
        QFile file(path);
        // NewOnly, so a file that appeared since the check is never truncated.
        made = file.open(QIODevice::WriteOnly | QIODevice::NewOnly);
    }
    if (!made)
        return {{"error", tr("%1 couldn't be created here").arg(name)}};
    if (QDir::cleanPath(folder) != m_root)
        m_expanded.insert(QDir::cleanPath(folder));
    m_debounce.stop();
    rebuild();
    return {{"path", path}};
}

int FileTree::find(const QString &prefix, int from) const {
    const int count = int(m_rows.size());
    for (int i = 0; i < count; ++i) {
        const int row = ((from + i) % count + count) % count;
        if (m_rows.at(row).name.startsWith(prefix, Qt::CaseInsensitive))
            return row;
    }
    return -1;
}
