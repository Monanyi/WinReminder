#include "ReminderManager.h"

#include <QApplication>
#include <QAction>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QPainter>
#include <QSaveFile>
#include <QScreen>
#include <QSettings>
#include <QWindow>
#include <QStandardPaths>
#include <QVariantMap>

#include <algorithm>

#ifdef Q_OS_WIN
#include <windows.h>
#include <mmsystem.h>
#endif

namespace
{
constexpr auto kDateFormat = "yyyy-MM-dd";
constexpr auto kTimeFormat = "HH:mm";
constexpr auto kDueFormat = "yyyy-MM-dd  HH:mm";
constexpr auto kAutorunKey = "WinReminder";
constexpr auto kRunRegistryPath =
    R"(HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run)";

QString unescapeLegacyText(const QString &input)
{
    QString output;
    output.reserve(input.size());
    for (qsizetype i = 0; i < input.size(); ++i)
    {
        if (input.at(i) == u'\\' && i + 1 < input.size())
        {
            const QChar escaped = input.at(++i);
            if (escaped == u'n')
                output += u'\n';
            else if (escaped == u't')
                output += u'\t';
            else
                output += escaped;
        }
        else
        {
            output += input.at(i);
        }
    }
    return output;
}

// 统一的列表排序规则：未错过在前（时间升序），已错过在后（时间降序）。
// 插入与整排必须共用它——若插入只按时间比较，新条目会落到“已错过”
// 区段之后，而 checkDue 只检查队头，该提醒将永远不触发。
bool reminderLessThan(const Reminder &left, const Reminder &right)
{
    if (left.missed != right.missed)
        return !left.missed;
    return left.missed ? left.due > right.due : left.due < right.due;
}

QString uniqueCorruptBackupPath(const QString &sourcePath)
{
    const QString timestamp =
        QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss-zzz"));
    const QString base =
        sourcePath + QStringLiteral(".corrupt-") + timestamp;
    QString candidate = base + QStringLiteral(".bak");
    int suffix = 2;
    while (QFileInfo::exists(candidate))
        candidate = base + QStringLiteral("-%1.bak").arg(suffix++);
    return candidate;
}
}

ReminderManager::ReminderManager(
    bool startHidden,
    QObject *parent,
    const QString &dataDirectory,
    bool enableSystemIntegration)
    : QAbstractListModel(parent),
      m_startHidden(startHidden),
      m_dataDirectory(dataDirectory),
      m_systemIntegrationEnabled(enableSystemIntegration)
{
    updateDefaultTime();
    loadData();
    if (m_systemIntegrationEnabled)
    {
        createTrayIcon();
        createTrayMenu();
    }

    if (!m_startupStorageError.isEmpty())
    {
        // loadData 在 QML 与托盘就绪之前执行，错误提示延后到事件循环再发，
        // 否则启动期的读取失败对用户完全不可见
        QTimer::singleShot(0, this, [this]
        {
            emit toastRequested(m_startupStorageError, true);
            if (m_trayIcon.isVisible())
                m_trayIcon.showMessage(
                    tr("提醒数据读取失败"),
                    m_startupStorageError,
                    QSystemTrayIcon::Critical,
                    8000);
            m_startupStorageError.clear();
        });
    }

#ifdef Q_OS_WIN
    if (m_systemIntegrationEnabled)
    {
    wchar_t windowsDirectory[MAX_PATH]{};
    if (GetWindowsDirectoryW(windowsDirectory, MAX_PATH) > 0)
    {
        const QString base = QString::fromWCharArray(windowsDirectory);
        const QStringList candidates{
            QStringLiteral("Media/Alarm01.wav"),
            QStringLiteral("Media/Ringin.wav"),
            QStringLiteral("Media/Windows Notify.wav"),
            QStringLiteral("Media/notify.wav")
        };
        for (const QString &candidate : candidates)
        {
            const QString path = QDir(base).filePath(candidate);
            if (QFileInfo::exists(path))
            {
                m_alarmWav = QDir::toNativeSeparators(path);
                break;
            }
        }
    }
    }
#endif

    m_dueTimer.setInterval(1000);
    connect(&m_dueTimer, &QTimer::timeout, this, &ReminderManager::checkDue);
    m_dueTimer.start();

    m_relativeTimer.setInterval(30000);
    connect(&m_relativeTimer, &QTimer::timeout, this, &ReminderManager::refreshRelativeTimes);
    m_relativeTimer.start();

    m_beepTimer.setInterval(2500);
    connect(&m_beepTimer, &QTimer::timeout, this, &ReminderManager::fallbackBeep);

    m_soundStopTimer.setSingleShot(true);
    m_soundStopTimer.setInterval(30000);
    connect(&m_soundStopTimer, &QTimer::timeout, this, &ReminderManager::stopSound);

    m_autoMissTimer.setSingleShot(true);
    m_autoMissTimer.setInterval(60000);
    connect(&m_autoMissTimer, &QTimer::timeout, this, &ReminderManager::autoMissCurrent);

    QTimer::singleShot(100, this, &ReminderManager::checkDue);
}

ReminderManager::~ReminderManager()
{
    saveData(false);
    stopAlarm();
}

int ReminderManager::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_items.size());
}

QVariant ReminderManager::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(m_items.size()))
        return {};

    const Reminder &reminder = m_items.at(static_cast<std::size_t>(index.row()));
    switch (role)
    {
    case ReminderIdRole:
        return reminder.id;
    case ReminderTextRole:
        return reminder.text;
    case DueTextRole:
        return formatDue(reminder.due);
    case RelativeTextRole:
        return reminder.missed ? tr("已错过") : formatRelative(reminder.due);
    case DueSoonRole:
        return !reminder.missed
               && QDateTime::currentDateTime().secsTo(reminder.due) <= 60 * 30;
    case MissedRole:
        return reminder.missed;
    default:
        return {};
    }
}

QHash<int, QByteArray> ReminderManager::roleNames() const
{
    return {
        {ReminderIdRole, "reminderId"},
        {ReminderTextRole, "reminderText"},
        {DueTextRole, "dueText"},
        {RelativeTextRole, "relativeText"},
        {DueSoonRole, "dueSoon"},
        {MissedRole, "reminderMissed"}
    };
}

int ReminderManager::count() const
{
    return static_cast<int>(m_items.size());
}

int ReminderManager::activeCount() const
{
    return static_cast<int>(std::count_if(
        m_items.begin(),
        m_items.end(),
        [](const Reminder &reminder) { return !reminder.missed; }));
}

int ReminderManager::missedCount() const
{
    return count() - activeCount();
}

int ReminderManager::pendingCount() const
{
    return static_cast<int>(m_dueQueue.size()) + (m_current ? 1 : 0);
}

QVariantList ReminderManager::pendingItems() const
{
    QVariantList result;
    result.reserve(pendingCount());

    const auto appendPending = [this, &result](
                                   const Reminder &reminder,
                                   const QString &status,
                                   bool current)
    {
        QVariantMap item;
        item.insert(QStringLiteral("reminderText"), reminder.text);
        item.insert(QStringLiteral("dueText"), formatDue(reminder.due));
        item.insert(QStringLiteral("statusText"), status);
        item.insert(QStringLiteral("current"), current);
        result.append(item);
    };

    if (m_current)
        appendPending(*m_current, tr("正在提醒"), true);
    for (const Reminder &reminder : m_dueQueue)
        appendPending(reminder, tr("等待显示"), false);

    return result;
}

QString ReminderManager::defaultDate() const
{
    return QDateTime::currentDateTime().addSecs(10 * 60).date().toString(QLatin1String(kDateFormat));
}

QString ReminderManager::defaultTime() const
{
    return QDateTime::currentDateTime().addSecs(10 * 60).time().toString(QLatin1String(kTimeFormat));
}

bool ReminderManager::autorunEnabled() const
{
    return autorunCommandMatchesCurrent();
}

bool ReminderManager::hasCurrent() const
{
    return m_current.has_value();
}

QString ReminderManager::currentText() const
{
    return m_current ? m_current->text : QString{};
}

QString ReminderManager::currentDueText() const
{
    return m_current ? formatDue(m_current->due) : QString{};
}

bool ReminderManager::startHidden() const
{
    return m_startHidden;
}

bool ReminderManager::quitting() const
{
    return m_quitting;
}

void ReminderManager::addReminder(
    const QString &text,
    const QString &dateText,
    const QString &timeText)
{
    const QString cleanedText = text.trimmed();
    if (cleanedText.isEmpty())
    {
        emit toastRequested(tr("请先写下要提醒的事。"), true);
        return;
    }

    const QDate date = QDate::fromString(dateText.trimmed(), QLatin1String(kDateFormat));
    const QTime time = QTime::fromString(timeText.trimmed(), QLatin1String(kTimeFormat));
    if (!date.isValid() || !time.isValid())
    {
        emit toastRequested(tr("日期或时间格式不正确，请使用 YYYY-MM-DD 和 HH:MM。"), true);
        return;
    }

    const QDateTime due(date, time);
    if (!due.isValid() || due <= QDateTime::currentDateTime())
    {
        emit toastRequested(tr("提醒时间必须晚于现在。"), true);
        return;
    }

    Reminder reminder{m_nextId, due, cleanedText};
    std::vector<Reminder> candidateItems = m_items;
    const auto insertAt = std::upper_bound(
        candidateItems.begin(),
        candidateItems.end(),
        reminder,
        reminderLessThan);
    const int row = static_cast<int>(std::distance(candidateItems.begin(), insertAt));
    candidateItems.insert(insertAt, reminder);

    if (!writeData(candidateItems, m_dueQueue, m_current, true))
        return;

    ++m_nextId;
    beginInsertRows(QModelIndex(), row, row);
    m_items.insert(m_items.begin() + row, std::move(reminder));
    endInsertRows();
    emit countChanged();

    updateDefaultTime();
    emit toastRequested(tr("提醒已添加"), false);
}

void ReminderManager::removeReminder(qint64 id)
{
    const auto iterator = std::find_if(
        m_items.begin(),
        m_items.end(),
        [id](const Reminder &reminder) { return reminder.id == id; });
    if (iterator == m_items.end())
        return;

    const int row = static_cast<int>(std::distance(m_items.begin(), iterator));
    std::vector<Reminder> candidateItems = m_items;
    candidateItems.erase(candidateItems.begin() + row);
    if (!writeData(candidateItems, m_dueQueue, m_current, true))
        return;

    beginRemoveRows(QModelIndex(), row, row);
    m_items.erase(iterator);
    endRemoveRows();
    emit countChanged();
    emit toastRequested(tr("提醒已删除"), false);
}

void ReminderManager::acknowledgeCurrent()
{
    if (!m_current)
        return;

    const std::optional<Reminder> noCurrent;
    if (!writeData(m_items, m_dueQueue, noCurrent, true))
        return;

    stopAlarm();
    m_current.reset();
    emit pendingChanged();
    emit currentReminderChanged();
    emit alarmDismissed();
    QTimer::singleShot(180, this, &ReminderManager::showNextReminder);
}

void ReminderManager::snoozeCurrent(int minutes)
{
    if (!m_current)
        return;

    const int safeMinutes = std::clamp(minutes, 1, 24 * 60);
    Reminder reminder = *m_current;
    reminder.id = m_nextId;
    reminder.due = QDateTime::currentDateTime().addSecs(safeMinutes * 60);

    std::vector<Reminder> candidateItems = m_items;
    const auto insertAt = std::upper_bound(
        candidateItems.begin(),
        candidateItems.end(),
        reminder,
        reminderLessThan);
    const int row = static_cast<int>(std::distance(candidateItems.begin(), insertAt));
    candidateItems.insert(insertAt, reminder);
    const std::optional<Reminder> noCurrent;
    if (!writeData(candidateItems, m_dueQueue, noCurrent, true))
        return;

    stopAlarm();
    ++m_nextId;
    m_current.reset();
    beginInsertRows(QModelIndex(), row, row);
    m_items.insert(m_items.begin() + row, std::move(reminder));
    endInsertRows();

    emit countChanged();
    emit pendingChanged();
    emit currentReminderChanged();
    emit alarmDismissed();
    emit toastRequested(tr("已推迟 %1 分钟").arg(safeMinutes), false);
    QTimer::singleShot(180, this, &ReminderManager::showNextReminder);
}

void ReminderManager::closeCurrentPopup()
{
    if (m_quitting || !m_current)
        return;
    dismissCurrentAsMissed();
}

void ReminderManager::dismissCurrentAsMissed()
{
    if (!m_current)
        return;

    Reminder reminder = *m_current;
    reminder.missed = true;

    std::vector<Reminder> candidateItems = m_items;
    const auto insertAt = std::lower_bound(
        candidateItems.begin(),
        candidateItems.end(),
        reminder,
        reminderLessThan);
    const int row = static_cast<int>(std::distance(candidateItems.begin(), insertAt));
    candidateItems.insert(insertAt, reminder);
    const std::optional<Reminder> noCurrent;
    if (!writeData(candidateItems, m_dueQueue, noCurrent, true))
        return;

    stopAlarm();
    m_current.reset();
    beginInsertRows(QModelIndex(), row, row);
    m_items.insert(m_items.begin() + row, std::move(reminder));
    endInsertRows();

    emit countChanged();
    emit pendingChanged();
    emit currentReminderChanged();
    emit alarmDismissed();
    emit toastRequested(tr("未处理的提醒已标记为错过"), false);
    QTimer::singleShot(180, this, &ReminderManager::showNextReminder);
}

void ReminderManager::notifyHidden()
{
    if (m_hiddenToastShown || !m_trayIcon.isVisible())
        return;

    m_hiddenToastShown = true;
    m_trayIcon.showMessage(
        tr("WinReminder 仍在运行"),
        tr("窗口已收进托盘，到时间会自动提醒。"),
        QSystemTrayIcon::Information,
        3500);
}

void ReminderManager::quitApplication()
{
    if (m_quitting)
        return;

    m_quitting = true;
    emit quittingChanged();
    saveData();
    stopAlarm();
    m_trayIcon.hide();
    QCoreApplication::quit();
}

QVariantMap ReminderManager::availableScreenGeometry(QWindow *window) const
{
    QScreen *screen = window ? window->screen() : nullptr;
    if (!screen)
        screen = QGuiApplication::primaryScreen();
    if (!screen)
        return {};

    const QRect available = screen->availableGeometry();
    return {
        {QStringLiteral("x"), available.x()},
        {QStringLiteral("y"), available.y()},
        {QStringLiteral("width"), available.width()},
        {QStringLiteral("height"), available.height()}
    };
}

void ReminderManager::previewAlarm()
{
    if (m_current)
        return;

    m_current = Reminder{
        -1,
        QDateTime::currentDateTime(),
        tr("站起来活动一下，喝杯水，让眼睛休息一会儿。"),
        false};
    emit pendingChanged();
    emit currentReminderChanged();
    emit alarmRequested();
}

void ReminderManager::previewAlarmSequence()
{
    if (m_current)
        return;

    const QDateTime now = QDateTime::currentDateTime();
    m_current = Reminder{
        -1,
        now,
        tr("连续提醒测试：第一条"),
        false};
    m_dueQueue.push_front(Reminder{
        -2,
        now.addSecs(1),
        tr("连续提醒测试：第二条"),
        false});
    emit pendingChanged();
    emit currentReminderChanged();
    emit alarmRequested();

    // 走与用户不处理提醒相同的状态转换，复现并防止旧窗口的
    // 延迟隐藏覆盖下一条提醒。
    QTimer::singleShot(300, this, &ReminderManager::dismissCurrentAsMissed);
}

void ReminderManager::setAutorunEnabled(bool enabled)
{
    QSettings settings(QString::fromLatin1(kRunRegistryPath), QSettings::NativeFormat);
    if (enabled)
    {
        const QString command =
            QStringLiteral("\"%1\" /tray").arg(QDir::toNativeSeparators(executablePath()));
        settings.setValue(QString::fromLatin1(kAutorunKey), command);
    }
    else
    {
        settings.remove(QString::fromLatin1(kAutorunKey));
    }
    settings.sync();

    emit autorunEnabledChanged();
    if (settings.status() != QSettings::NoError || autorunEnabled() != enabled)
    {
        emit toastRequested(tr("无法更新开机启动设置。"), true);
        return;
    }

    emit toastRequested(enabled ? tr("已开启开机启动") : tr("已关闭开机启动"), false);
}

void ReminderManager::checkDue()
{
    const QDateTime now = QDateTime::currentDateTime();
    if (!m_items.empty() && !m_items.front().missed && m_items.front().due <= now)
    {
        std::vector<Reminder> candidateItems = m_items;
        std::deque<Reminder> candidateQueue = m_dueQueue;
        while (!candidateItems.empty()
               && !candidateItems.front().missed
               && candidateItems.front().due <= now)
        {
            candidateQueue.push_back(std::move(candidateItems.front()));
            candidateItems.erase(candidateItems.begin());
        }

        if (!writeAutomaticData(candidateItems, candidateQueue, m_current))
            return;

        beginResetModel();
        m_items = std::move(candidateItems);
        m_dueQueue = std::move(candidateQueue);
        endResetModel();
        emit countChanged();
        emit pendingChanged();
    }

    showNextReminder();
}

void ReminderManager::refreshRelativeTimes()
{
    updateDefaultTime();
    if (m_items.empty())
        return;

    emit dataChanged(
        index(0, 0),
        index(static_cast<int>(m_items.size()) - 1, 0),
        {RelativeTextRole, DueSoonRole});
}

void ReminderManager::fallbackBeep()
{
#ifdef Q_OS_WIN
    MessageBeep(MB_ICONEXCLAMATION);
#endif
}

void ReminderManager::autoMissCurrent()
{
    dismissCurrentAsMissed();
}

void ReminderManager::loadData()
{
    const bool loadedJson = loadJson();
    bool migratedLegacy = false;
    if (!loadedJson)
    {
        QString legacy = legacyDataPath();
        if (!QFileInfo::exists(legacy))
        {
            const QString projectLegacy =
                QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("../reminders.dat"));
            if (QFileInfo::exists(projectLegacy))
                legacy = projectLegacy;
        }

        if (QFileInfo::exists(legacy))
            migratedLegacy = loadLegacyData(legacy);
    }

    const QDateTime startedAt = QDateTime::currentDateTime();
    bool newlyMissed = false;
    for (Reminder &reminder : m_items)
    {
        if (!reminder.missed && reminder.due <= startedAt)
        {
            reminder.missed = true;
            newlyMissed = true;
        }
    }

    sortItems();
    if (newlyMissed || migratedLegacy)
        saveData(false);
}

bool ReminderManager::loadJson()
{
    QFile file(dataPath());
    if (!file.exists())
        return false;

    if (!file.open(QIODevice::ReadOnly))
    {
        m_preserveUnreadableData = true;
        m_corruptBackupCreated = false;
        m_startupStorageError =
            tr("无法读取提醒数据：%1。为保护原文件，本次运行已停止写入提醒数据。")
                .arg(file.errorString());
        return true;
    }

    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray())
    {
        const QString reason = parseError.error != QJsonParseError::NoError
            ? parseError.errorString()
            : tr("顶层结构不是数组");
        QString detail = tr("数据文件格式损坏：%1").arg(reason);
        m_preserveUnreadableData = true;
        const QString backupPath = uniqueCorruptBackupPath(dataPath());
        m_corruptBackupCreated = QFile::copy(dataPath(), backupPath);
        if (m_corruptBackupCreated)
        {
            detail += tr("，原文件已备份为 %1；关闭程序不会覆盖损坏的原文件")
                          .arg(QFileInfo(backupPath).fileName());
        }
        else
        {
            detail += tr("，且无法创建安全备份；为保护原文件，本次运行已停止写入提醒数据");
        }
        m_startupStorageError = detail;
        return true;
    }

    for (const QJsonValue &value : document.array())
    {
        const QJsonObject object = value.toObject();
        const qint64 epoch = object.value(QStringLiteral("due")).toVariant().toLongLong();
        const QString text = object.value(QStringLiteral("text")).toString().trimmed();
        const bool missed = object.value(QStringLiteral("missed")).toBool(false);
        const QDateTime due = QDateTime::fromSecsSinceEpoch(epoch);
        if (due.isValid() && !text.isEmpty())
            m_items.push_back(Reminder{m_nextId++, due, text, missed});
    }
    return true;
}

bool ReminderManager::loadLegacyData(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;

    while (!file.atEnd())
    {
        QByteArray line = file.readLine().trimmed();
        const qsizetype tab = line.indexOf('\t');
        if (tab <= 0)
            continue;

        bool ok = false;
        const qint64 epoch = line.left(tab).toLongLong(&ok);
        const QString text = unescapeLegacyText(QString::fromUtf8(line.mid(tab + 1))).trimmed();
        const QDateTime due = QDateTime::fromSecsSinceEpoch(epoch);
        if (ok && epoch > 0 && due.isValid() && !text.isEmpty())
            m_items.push_back(Reminder{m_nextId++, due, text});
    }
    return true;
}

bool ReminderManager::saveData(bool reportErrors)
{
    return writeData(m_items, m_dueQueue, m_current, reportErrors);
}

bool ReminderManager::writeData(
    const std::vector<Reminder> &items,
    const std::deque<Reminder> &dueQueue,
    const std::optional<Reminder> &current,
    bool reportErrors)
{
    if (m_preserveUnreadableData)
    {
        if (!reportErrors)
            return false;
        if (!m_corruptBackupCreated)
        {
            showStorageError(
                tr("原提醒文件无法读取且没有安全备份，程序不会覆盖它。"
                   "请先复制或移走 reminders.json 后再重试。"));
            return false;
        }
    }

    QJsonArray array;
    const auto appendReminder = [&array](const Reminder &reminder)
    {
        QJsonObject object;
        object.insert(QStringLiteral("due"), reminder.due.toSecsSinceEpoch());
        object.insert(QStringLiteral("text"), reminder.text);
        object.insert(QStringLiteral("missed"), reminder.missed);
        array.append(object);
    };

    for (const Reminder &reminder : items)
    {
        if (reminder.id >= 0)
            appendReminder(reminder);
    }
    for (const Reminder &reminder : dueQueue)
    {
        if (reminder.id >= 0)
            appendReminder(reminder);
    }
    if (current && current->id >= 0)
        appendReminder(*current);

    QSaveFile file(dataPath());
    file.setDirectWriteFallback(false);
    if (!file.open(QIODevice::WriteOnly))
    {
        if (reportErrors)
            showStorageError(file.errorString());
        return false;
    }

    const QByteArray payload = QJsonDocument(array).toJson(QJsonDocument::Indented);
    if (file.write(payload) != payload.size() || !file.commit())
    {
        if (reportErrors)
            showStorageError(file.errorString());
        return false;
    }

    m_preserveUnreadableData = false;
    m_corruptBackupCreated = false;
    m_automaticStorageFailureReported = false;
    return true;
}

bool ReminderManager::writeAutomaticData(
    const std::vector<Reminder> &items,
    const std::deque<Reminder> &dueQueue,
    const std::optional<Reminder> &current)
{
    const bool saved = writeData(
        items,
        dueQueue,
        current,
        !m_automaticStorageFailureReported);
    if (!saved)
        m_automaticStorageFailureReported = true;
    return saved;
}

void ReminderManager::sortItems()
{
    std::stable_sort(m_items.begin(), m_items.end(), reminderLessThan);
}

void ReminderManager::showNextReminder()
{
    if (m_current || m_dueQueue.empty())
        return;

    std::deque<Reminder> candidateQueue = m_dueQueue;
    std::optional<Reminder> candidateCurrent = std::move(candidateQueue.front());
    candidateQueue.pop_front();
    if (!writeAutomaticData(m_items, candidateQueue, candidateCurrent))
        return;

    m_dueQueue = std::move(candidateQueue);
    m_current = std::move(candidateCurrent);
    emit pendingChanged();
    emit currentReminderChanged();
    emit alarmRequested();
    if (m_current->id >= 0 && m_systemIntegrationEnabled)
        startAlarm();
}

void ReminderManager::startAlarm()
{
    stopAlarm();
#ifdef Q_OS_WIN
    const bool playingWav =
        !m_alarmWav.isEmpty() &&
        PlaySoundW(
            reinterpret_cast<LPCWSTR>(m_alarmWav.utf16()),
            nullptr,
            SND_FILENAME | SND_ASYNC | SND_LOOP | SND_NODEFAULT);
    if (!playingWav)
    {
        fallbackBeep();
        m_beepTimer.start();
    }
#endif
    m_soundStopTimer.start();
    m_autoMissTimer.start();
}

void ReminderManager::stopSound()
{
#ifdef Q_OS_WIN
    PlaySoundW(nullptr, nullptr, 0);
#endif
    m_beepTimer.stop();
    m_soundStopTimer.stop();
}

void ReminderManager::stopAlarm()
{
    stopSound();
    m_autoMissTimer.stop();
}

void ReminderManager::updateDefaultTime()
{
    emit defaultsChanged();
}

void ReminderManager::createTrayIcon()
{
    m_trayIcon.setIcon(createAppIcon());
    m_trayIcon.setToolTip(tr("WinReminder 定时提醒"));
    connect(
        &m_trayIcon,
        &QSystemTrayIcon::activated,
        this,
        [this](QSystemTrayIcon::ActivationReason reason)
        {
            if (reason == QSystemTrayIcon::DoubleClick || reason == QSystemTrayIcon::Trigger)
                showMainWindow();
        });
    m_trayIcon.show();
}

void ReminderManager::createTrayMenu()
{
    m_trayMenu = new QMenu;
    QAction *openAction = m_trayMenu->addAction(tr("打开 WinReminder"));
    m_trayMenu->addSeparator();
    QAction *quitAction = m_trayMenu->addAction(tr("退出程序"));

    connect(openAction, &QAction::triggered, this, &ReminderManager::showMainWindow);
    connect(quitAction, &QAction::triggered, this, &ReminderManager::quitApplication);
    m_trayIcon.setContextMenu(m_trayMenu);
}

void ReminderManager::showMainWindow()
{
    emit restoreRequested();
}

void ReminderManager::showStorageError(const QString &detail)
{
    const QString message =
        tr("提醒数据无法保存。请检查程序目录是否可写。%1")
            .arg(detail.isEmpty() ? QString{} : QStringLiteral("\n") + detail);
    emit toastRequested(message, true);
    if (m_trayIcon.isVisible())
        m_trayIcon.showMessage(tr("保存失败"), message, QSystemTrayIcon::Critical, 8000);
}

QString ReminderManager::formatDue(const QDateTime &due) const
{
    return due.toString(QLatin1String(kDueFormat));
}

QString ReminderManager::formatRelative(const QDateTime &due) const
{
    const qint64 seconds = QDateTime::currentDateTime().secsTo(due);
    if (seconds <= 0)
        return tr("即将提醒");
    if (seconds < 60)
        return tr("不到 1 分钟");
    if (seconds < 60 * 60)
        return tr("%1 分钟后").arg((seconds + 59) / 60);
    if (seconds < 24 * 60 * 60)
        return tr("%1 小时后").arg((seconds + 3599) / 3600);
    return tr("%1 天后").arg((seconds + 86399) / 86400);
}

QString ReminderManager::dataPath() const
{
    const QString directory =
        m_dataDirectory.isEmpty() ? QCoreApplication::applicationDirPath() : m_dataDirectory;
    return QDir(directory).filePath(QStringLiteral("reminders.json"));
}

QString ReminderManager::legacyDataPath() const
{
    const QString directory =
        m_dataDirectory.isEmpty() ? QCoreApplication::applicationDirPath() : m_dataDirectory;
    return QDir(directory).filePath(QStringLiteral("reminders.dat"));
}

QString ReminderManager::executablePath() const
{
    return QCoreApplication::applicationFilePath();
}

bool ReminderManager::autorunCommandMatchesCurrent() const
{
    QSettings settings(QString::fromLatin1(kRunRegistryPath), QSettings::NativeFormat);
    const QString stored = settings.value(QString::fromLatin1(kAutorunKey)).toString();
    if (stored.isEmpty())
        return false;

    const QString expected =
        QStringLiteral("\"%1\" /tray").arg(QDir::toNativeSeparators(executablePath()));
    return stored.compare(expected, Qt::CaseInsensitive) == 0;
}

QIcon ReminderManager::createAppIcon()
{
    QPixmap pixmap(128, 128);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);

    QLinearGradient gradient(18, 12, 110, 118);
    gradient.setColorAt(0.0, QColor(QStringLiteral("#7C83FF")));
    gradient.setColorAt(1.0, QColor(QStringLiteral("#4B51D8")));
    painter.setPen(Qt::NoPen);
    painter.setBrush(gradient);
    painter.drawRoundedRect(QRectF(8, 8, 112, 112), 32, 32);

    QPen clockPen(Qt::white, 8, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
    painter.setPen(clockPen);
    painter.setBrush(Qt::NoBrush);
    painter.drawEllipse(QPointF(64, 64), 34, 34);
    painter.drawLine(QPointF(64, 64), QPointF(64, 40));
    painter.drawLine(QPointF(64, 64), QPointF(82, 73));

    return QIcon(pixmap);
}
