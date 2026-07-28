#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QIcon>
#include <QPointer>
#include <QSystemTrayIcon>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include <deque>
#include <optional>
#include <vector>

class QMenu;
class QWindow;

struct Reminder
{
    qint64 id = 0;
    QDateTime due;
    QString text;
    bool missed = false;
};

class ReminderManager final : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY countChanged)
    Q_PROPERTY(int missedCount READ missedCount NOTIFY countChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingChanged)
    Q_PROPERTY(QVariantList pendingItems READ pendingItems NOTIFY pendingChanged)
    Q_PROPERTY(QString defaultDate READ defaultDate NOTIFY defaultsChanged)
    Q_PROPERTY(QString defaultTime READ defaultTime NOTIFY defaultsChanged)
    Q_PROPERTY(bool autorunEnabled READ autorunEnabled WRITE setAutorunEnabled NOTIFY autorunEnabledChanged)
    Q_PROPERTY(bool hasCurrent READ hasCurrent NOTIFY currentReminderChanged)
    Q_PROPERTY(QString currentText READ currentText NOTIFY currentReminderChanged)
    Q_PROPERTY(QString currentDueText READ currentDueText NOTIFY currentReminderChanged)
    Q_PROPERTY(bool startHidden READ startHidden CONSTANT)
    Q_PROPERTY(bool quitting READ quitting NOTIFY quittingChanged)

public:
    enum Roles
    {
        ReminderIdRole = Qt::UserRole + 1,
        ReminderTextRole,
        DueTextRole,
        RelativeTextRole,
        DueSoonRole,
        MissedRole
    };

    explicit ReminderManager(
        bool startHidden,
        QObject *parent = nullptr,
        const QString &dataDirectory = {},
        bool enableSystemIntegration = true);
    ~ReminderManager() override;

    static QIcon createAppIcon();

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    int activeCount() const;
    int missedCount() const;
    int pendingCount() const;
    QVariantList pendingItems() const;
    QString defaultDate() const;
    QString defaultTime() const;
    bool autorunEnabled() const;
    bool hasCurrent() const;
    QString currentText() const;
    QString currentDueText() const;
    bool startHidden() const;
    bool quitting() const;

    Q_INVOKABLE void addReminder(const QString &text, const QString &dateText, const QString &timeText);
    Q_INVOKABLE void removeReminder(qint64 id);
    Q_INVOKABLE void acknowledgeCurrent();
    Q_INVOKABLE void snoozeCurrent(int minutes);
    Q_INVOKABLE void closeCurrentPopup();
    Q_INVOKABLE void dismissCurrentAsMissed();
    Q_INVOKABLE void notifyHidden();
    Q_INVOKABLE void quitApplication();
    Q_INVOKABLE QVariantMap availableScreenGeometry(QWindow *window) const;
    void previewAlarm();
    void previewAlarmSequence();
    void showMainWindow();

public slots:
    void setAutorunEnabled(bool enabled);

signals:
    void countChanged();
    void pendingChanged();
    void defaultsChanged();
    void autorunEnabledChanged();
    void currentReminderChanged();
    void alarmRequested();
    void alarmDismissed();
    void restoreRequested();
    void toastRequested(const QString &message, bool isError);
    void quittingChanged();

private slots:
    void checkDue();
    void refreshRelativeTimes();
    void fallbackBeep();
    void autoMissCurrent();

private:
    void loadData();
    bool loadJson();
    bool loadLegacyData(const QString &path);
    bool saveData(bool reportErrors = true);
    bool writeData(
        const std::vector<Reminder> &items,
        const std::deque<Reminder> &dueQueue,
        const std::optional<Reminder> &current,
        bool reportErrors);
    bool writeAutomaticData(
        const std::vector<Reminder> &items,
        const std::deque<Reminder> &dueQueue,
        const std::optional<Reminder> &current);
    void sortItems();
    void showNextReminder();
    void startAlarm();
    void stopSound();
    void stopAlarm();
    void updateDefaultTime();
    void createTrayIcon();
    void createTrayMenu();
    void showStorageError(const QString &detail);
    QString formatDue(const QDateTime &due) const;
    QString formatRelative(const QDateTime &due) const;
    QString dataPath() const;
    QString legacyDataPath() const;
    QString executablePath() const;
    bool autorunCommandMatchesCurrent() const;
    std::vector<Reminder> m_items;
    std::deque<Reminder> m_dueQueue;
    std::optional<Reminder> m_current;
    qint64 m_nextId = 1;
    bool m_startHidden = false;
    bool m_quitting = false;
    bool m_hiddenToastShown = false;
    QString m_dataDirectory;
    bool m_systemIntegrationEnabled = true;
    QString m_alarmWav;
    QString m_startupStorageError;
    bool m_preserveUnreadableData = false;
    bool m_corruptBackupCreated = false;
    bool m_automaticStorageFailureReported = false;

    QTimer m_dueTimer;
    QTimer m_relativeTimer;
    QTimer m_beepTimer;
    QTimer m_soundStopTimer;
    QTimer m_autoMissTimer;
    QSystemTrayIcon m_trayIcon;
    QPointer<QMenu> m_trayMenu;
};
