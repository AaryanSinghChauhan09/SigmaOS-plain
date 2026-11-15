#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QSet>
#include <QTimer>
#include <QVector>

// The sidebar's folder, as the rows a list shows: each open folder's
// contents follow it one level deeper. Folders come first, then files, both
// alphabetical; dotfiles are left out. Open folders are watched, so a file
// created or removed elsewhere shows up without asking.
class FileTree : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString root READ root WRITE setRoot NOTIFY rootChanged)

public:
    enum Role { NameRole = Qt::UserRole + 1, PathRole, DepthRole, FolderRole, ExpandedRole };

    explicit FileTree(QObject *parent = nullptr);

    QString root() const { return m_root; }
    void setRoot(const QString &root);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void toggle(int row);
    Q_INVOKABLE void expand(int row);
    Q_INVOKABLE void collapse(int row);
    // Opens the folders down to a path under the root, and returns its row,
    // or -1 when it isn't in the tree.
    Q_INVOKABLE int reveal(const QString &path);
    Q_INVOKABLE int indexOf(const QString &path) const;
    // The row of the folder a row sits in, or -1 at the top.
    Q_INVOKABLE int parentOf(int row) const;
    Q_INVOKABLE bool isFolder(int row) const;
    Q_INVOKABLE bool isExpanded(int row) const;
    Q_INVOKABLE QString pathAt(int row) const;
    // The first row from `from` on, around past the end, whose name starts
    // with `prefix` in any case; -1 when none does.
    Q_INVOKABLE int find(const QString &prefix, int from) const;
    // Moves a file or folder in the tree to the trash, so a delete can be
    // undone from the file manager. Empty when it went, or why it didn't.
    Q_INVOKABLE QString trash(const QString &path);
    // Moves a file or folder in the tree into another folder, and returns
    // {path} where it went or {error}: something there already has its
    // name, or a folder can't go inside itself.
    Q_INVOKABLE QVariantMap move(const QString &path, const QString &folder);

    // Where a new file or folder goes from a row: into the folder at it, or
    // beside the file at it, or the root with no row.
    Q_INVOKABLE QString folderAt(int row) const;
    // Makes an empty file or a folder by that name there, and returns
    // {path} or {error}. Never over anything already there.
    Q_INVOKABLE QVariantMap create(const QString &folder, const QString &name, bool isFolder);
    // Why a name can't be used in a folder, or empty when it can.
    Q_INVOKABLE QString nameProblem(const QString &folder, const QString &name) const;

signals:
    void rootChanged();
    // After a folder changed on disk and the rows were rebuilt.
    void refreshed();

private:
    struct Entry {
        QString name;
        QString path;
        int depth = 0;
        bool folder = false;
    };

    // A folder's rows, with those of its open folders after each.
    QVector<Entry> rowsUnder(const QString &folder, int depth) const;
    void rebuild();
    // Under the root, as a clean absolute path; the root itself isn't.
    bool inTree(const QString &clean) const;
    void rewatch();

    QString m_root;
    QVector<Entry> m_rows;
    QSet<QString> m_expanded;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
