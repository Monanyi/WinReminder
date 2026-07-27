#include "ReminderManager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

namespace
{
QJsonObject reminderObject(
    const QDateTime &due,
    const QString &text,
    bool missed = false)
{
    QJsonObject object;
    object.insert(QStringLiteral("due"), due.toSecsSinceEpoch());
    object.insert(QStringLiteral("text"), text);
    object.insert(QStringLiteral("missed"), missed);
    return object;
}

bool writeBytes(const QString &path, const QByteArray &contents)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    return file.write(contents) == contents.size();
}

bool writeReminders(const QString &path, const QJsonArray &reminders)
{
    return writeBytes(path, QJsonDocument(reminders).toJson(QJsonDocument::Indented));
}

QJsonArray readReminders(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).array();
}

QDateTime futureMinute(int minutes)
{
    QDateTime result = QDateTime::currentDateTime().addSecs(minutes * 60);
    result.setTime(QTime(result.time().hour(), result.time().minute()));
    if (result <= QDateTime::currentDateTime())
        result = result.addSecs(60);
    return result;
}

void addAt(ReminderManager &manager, const QString &text, const QDateTime &due)
{
    manager.addReminder(
        text,
        due.date().toString(QStringLiteral("yyyy-MM-dd")),
        due.time().toString(QStringLiteral("HH:mm")));
}
}

class ReminderManagerTests final : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void addPersistsBeforeUpdatingModel();
    void addFailureDoesNotMutateModel();
    void removeFailureRollsBack();
    void corruptDataIsPreservedWithUniqueBackups();
    void startupMarksPastItemsMissedAndKeepsOrdering();
    void continuousSequenceAdvancesToSecondReminder();
};

void ReminderManagerTests::initTestCase()
{
    QCoreApplication::setOrganizationName(QStringLiteral("WinReminderTests"));
    QCoreApplication::setApplicationName(QStringLiteral("WinReminderTests"));
}

void ReminderManagerTests::addPersistsBeforeUpdatingModel()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    ReminderManager manager(false, nullptr, directory.path(), false);
    addAt(manager, QStringLiteral("写盘测试"), futureMinute(5));

    QCOMPARE(manager.count(), 1);
    const QJsonArray stored =
        readReminders(directory.filePath(QStringLiteral("reminders.json")));
    QCOMPARE(stored.size(), 1);
    QCOMPARE(stored.first().toObject().value(QStringLiteral("text")).toString(),
             QStringLiteral("写盘测试"));
}

void ReminderManagerTests::addFailureDoesNotMutateModel()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString missingDirectory =
        directory.filePath(QStringLiteral("missing/subdirectory"));

    ReminderManager manager(false, nullptr, missingDirectory, false);
    QSignalSpy errorSpy(&manager, &ReminderManager::toastRequested);
    addAt(manager, QStringLiteral("不应出现"), futureMinute(5));

    QCOMPARE(manager.count(), 0);
    QVERIFY(!QFileInfo::exists(
        QDir(missingDirectory).filePath(QStringLiteral("reminders.json"))));
    QVERIFY(!errorSpy.isEmpty());
}

void ReminderManagerTests::removeFailureRollsBack()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString dataPath =
        directory.filePath(QStringLiteral("reminders.json"));
    QJsonArray initial;
    initial.append(reminderObject(futureMinute(10), QStringLiteral("保留我")));
    QVERIFY(writeReminders(dataPath, initial));

    ReminderManager manager(false, nullptr, directory.path(), false);
    QCOMPARE(manager.count(), 1);
    const qint64 id =
        manager.data(manager.index(0, 0), ReminderManager::ReminderIdRole).toLongLong();

    QVERIFY(QFile::remove(dataPath));
    QVERIFY(QDir().rmdir(directory.path()));
    manager.removeReminder(id);

    QCOMPARE(manager.count(), 1);
    QCOMPARE(
        manager.data(manager.index(0, 0), ReminderManager::ReminderTextRole).toString(),
        QStringLiteral("保留我"));
}

void ReminderManagerTests::corruptDataIsPreservedWithUniqueBackups()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString dataPath =
        directory.filePath(QStringLiteral("reminders.json"));
    const QByteArray corrupt =
        QByteArrayLiteral("[{\"text\":\"仍可人工恢复\",\"due\":123");
    QVERIFY(writeBytes(dataPath, corrupt));

    {
        ReminderManager manager(false, nullptr, directory.path(), false);
        QCOMPARE(manager.count(), 0);
    }
    {
        ReminderManager manager(false, nullptr, directory.path(), false);
        QCOMPARE(manager.count(), 0);
    }

    QFile original(dataPath);
    QVERIFY(original.open(QIODevice::ReadOnly));
    QCOMPARE(original.readAll(), corrupt);

    const QStringList backups = QDir(directory.path()).entryList(
        {QStringLiteral("reminders.json.corrupt-*.bak")},
        QDir::Files,
        QDir::Name);
    QCOMPARE(backups.size(), 2);
    QVERIFY(backups.at(0) != backups.at(1));
}

void ReminderManagerTests::startupMarksPastItemsMissedAndKeepsOrdering()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString dataPath =
        directory.filePath(QStringLiteral("reminders.json"));

    QJsonArray initial;
    initial.append(reminderObject(
        QDateTime::currentDateTime().addSecs(-60),
        QStringLiteral("过去")));
    initial.append(reminderObject(futureMinute(10), QStringLiteral("未来")));
    QVERIFY(writeReminders(dataPath, initial));

    ReminderManager manager(false, nullptr, directory.path(), false);
    QCOMPARE(manager.activeCount(), 1);
    QCOMPARE(manager.missedCount(), 1);

    addAt(manager, QStringLiteral("更早的未来"), futureMinute(5));
    QCOMPARE(manager.count(), 3);
    QCOMPARE(
        manager.data(manager.index(0, 0), ReminderManager::ReminderTextRole).toString(),
        QStringLiteral("更早的未来"));
    QCOMPARE(
        manager.data(manager.index(1, 0), ReminderManager::ReminderTextRole).toString(),
        QStringLiteral("未来"));
    QVERIFY(manager.data(
        manager.index(2, 0),
        ReminderManager::MissedRole).toBool());

    const QJsonArray stored = readReminders(dataPath);
    int missed = 0;
    for (const QJsonValue &value : stored)
        missed += value.toObject().value(QStringLiteral("missed")).toBool() ? 1 : 0;
    QCOMPARE(missed, 1);
}

void ReminderManagerTests::continuousSequenceAdvancesToSecondReminder()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    ReminderManager manager(false, nullptr, directory.path(), false);
    QSignalSpy alarmSpy(&manager, &ReminderManager::alarmRequested);
    manager.previewAlarmSequence();

    QCOMPARE(manager.pendingCount(), 2);
    QCOMPARE(manager.currentText(), QStringLiteral("连续提醒测试：第一条"));
    QTRY_COMPARE_WITH_TIMEOUT(
        manager.currentText(),
        QStringLiteral("连续提醒测试：第二条"),
        1200);
    QCOMPARE(manager.pendingCount(), 1);
    QCOMPARE(alarmSpy.count(), 2);
}

QTEST_MAIN(ReminderManagerTests)

#include "ReminderManagerTests.moc"
