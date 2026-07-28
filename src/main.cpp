#include "ReminderManager.h"

#include <QApplication>
#include <QFileInfo>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QQuickStyle>
#include <QTimer>
#include <QUrl>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

namespace
{
constexpr wchar_t kMutexName[] = L"Local\\WinReminder_Qt_SingleInstance";
constexpr auto kInstanceServerName = "WinReminder_Qt_SingleInstance";

// 通过本地套接字通知已运行的实例弹出主窗口。
// 不按窗口标题查找：标题恰为 "WinReminder" 的资源管理器窗口会被误命中，
// 托盘隐藏状态下的窗口也未必能被 FindWindow 可靠还原。
void activatePreviousInstance()
{
    QLocalSocket socket;
    socket.connectToServer(QLatin1String(kInstanceServerName));
    if (!socket.waitForConnected(500))
        return;

    socket.write("activate\n");
    socket.flush();
    socket.waitForBytesWritten(300);
    socket.disconnectFromServer();
    if (socket.state() != QLocalSocket::UnconnectedState)
        socket.waitForDisconnected(200);
}
}

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName(QStringLiteral("WinReminder"));
    QCoreApplication::setApplicationName(QStringLiteral("WinReminder"));
    QCoreApplication::setApplicationVersion(QStringLiteral(WINREMINDER_VERSION));

    QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));

    // QLocalSocket 依赖应用对象，单实例检测放在 QApplication 构造之后
    QApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);

    const QStringList arguments = app.arguments();
    const int screenshotArgument = arguments.indexOf(QStringLiteral("--screenshot"));
    const bool screenshotMode =
        screenshotArgument >= 0
        && screenshotArgument + 1 < arguments.size()
        && !arguments.at(screenshotArgument + 1).startsWith(QStringLiteral("--"));
    const bool diagnosticLaunch = screenshotMode;

#ifdef Q_OS_WIN
    HANDLE mutex = nullptr;
    if (!diagnosticLaunch)
    {
        mutex = CreateMutexW(nullptr, TRUE, kMutexName);
        if (mutex && GetLastError() == ERROR_ALREADY_EXISTS)
        {
            activatePreviousInstance();
            CloseHandle(mutex);
            return 0;
        }
    }
#endif

    const QString screenshotPath =
        screenshotMode ? QFileInfo(arguments.at(screenshotArgument + 1)).absoluteFilePath() : QString{};
    const int sizeArgument = arguments.indexOf(QStringLiteral("--window-size"));
    const QStringList requestedSize =
        sizeArgument >= 0 && sizeArgument + 1 < arguments.size()
            ? arguments.at(sizeArgument + 1).toLower().split(u'x')
            : QStringList{};
    const int pickerArgument = arguments.indexOf(QStringLiteral("--picker"));
    const QString requestedPicker =
        pickerArgument >= 0 && pickerArgument + 1 < arguments.size()
            ? arguments.at(pickerArgument + 1).toLower()
            : QString{};
    const bool alarmPreview = arguments.contains(QStringLiteral("--alarm-preview"));
    const bool alarmSequencePreview =
        arguments.contains(QStringLiteral("--alarm-sequence-preview"));
    const bool pendingPreview =
        arguments.contains(QStringLiteral("--pending-preview"));
    const bool alarmWindowPreview = alarmPreview || alarmSequencePreview;
    const bool startHidden =
        !screenshotMode && arguments.contains(QStringLiteral("/tray"), Qt::CaseInsensitive);
    ReminderManager manager(startHidden);
    app.setWindowIcon(ReminderManager::createAppIcon());

    QLocalServer instanceServer;
    if (!diagnosticLaunch)
    {
        QLocalServer::removeServer(QLatin1String(kInstanceServerName));
        if (instanceServer.listen(QLatin1String(kInstanceServerName)))
        {
            QObject::connect(
                &instanceServer,
                &QLocalServer::newConnection,
                &manager,
                [&instanceServer, &manager]
                {
                    while (QLocalSocket *connection = instanceServer.nextPendingConnection())
                        connection->deleteLater();
                    manager.showMainWindow();
                });
        }
    }

    QQmlApplicationEngine engine;
    engine.setInitialProperties(
        {{QStringLiteral("reminders"), QVariant::fromValue(static_cast<QObject *>(&manager))}});

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] { QCoreApplication::exit(EXIT_FAILURE); },
        Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("WinReminder"), QStringLiteral("Main"));

    if (engine.rootObjects().isEmpty())
    {
#ifdef Q_OS_WIN
        if (mutex)
            CloseHandle(mutex);
#endif
        return EXIT_FAILURE;
    }

    if (screenshotMode)
    {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        if (!window)
            return EXIT_FAILURE;

        if (requestedSize.size() == 2)
        {
            bool widthOk = false;
            bool heightOk = false;
            const int requestedWidth = requestedSize.at(0).toInt(&widthOk);
            const int requestedHeight = requestedSize.at(1).toInt(&heightOk);
            if (widthOk && heightOk)
                window->resize(requestedWidth, requestedHeight);
        }

        window->show();
        window->requestActivate();
        if (alarmPreview)
            QTimer::singleShot(180, &manager, &ReminderManager::previewAlarm);
        if (alarmSequencePreview)
            QTimer::singleShot(180, &manager, &ReminderManager::previewAlarmSequence);
        if (pendingPreview)
            QTimer::singleShot(180, &manager, &ReminderManager::previewAlarmSequence);
        if (!requestedPicker.isEmpty())
        {
            QTimer::singleShot(
                220,
                window,
                [window, requestedPicker]
                {
                    QMetaObject::invokeMethod(
                        window,
                        "previewPicker",
                        Q_ARG(QVariant, requestedPicker));
                });
        }
        QTimer::singleShot(
            1200,
            &app,
            [window, screenshotPath, alarmWindowPreview, alarmSequencePreview, &manager]
            {
                QQuickWindow *captureWindow = window;
                bool alarmWindowVisible = false;
                if (alarmWindowPreview)
                {
                    for (QWindow *candidate : QGuiApplication::topLevelWindows())
                    {
                        if (candidate->title() == QStringLiteral("提醒时间到")
                            && candidate->isVisible())
                        {
                            if (auto *quickWindow = qobject_cast<QQuickWindow *>(candidate))
                            {
                                captureWindow = quickWindow;
                                alarmWindowVisible = true;
                            }
                            break;
                        }
                    }
                }

                if (alarmWindowPreview && !alarmWindowVisible)
                {
                    QCoreApplication::exit(3);
                    return;
                }
                if (alarmSequencePreview
                    && manager.currentText() != QStringLiteral("连续提醒测试：第二条"))
                {
                    QCoreApplication::exit(4);
                    return;
                }

                const QImage image = captureWindow->grabWindow();
                if (image.isNull() || !image.save(screenshotPath))
                    QCoreApplication::exit(2);
                else
                    QCoreApplication::quit();
            });
    }

    const int result = app.exec();

#ifdef Q_OS_WIN
    if (mutex)
        CloseHandle(mutex);
#endif
    return result;
}
