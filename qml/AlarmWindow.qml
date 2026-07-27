pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: alarm

    required property var reminders
    required property var ownerWindow
    required property bool darkMode
    required property color accent
    required property color primaryText
    required property color secondaryText
    required property color surfaceColor
    required property color fieldColor
    required property color lineColor

    property real restingX: 0
    property real restingY: 0
    property int remainingSeconds: 60

    width: 430
    height: 272
    visible: false
    opacity: 0
    title: "提醒时间到"
    color: "transparent"
    screen: ownerWindow.screen
    transientParent: ownerWindow
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    function positionAtBottomRight() {
        restingX = alarm.screen.virtualX
                   + alarm.screen.desktopAvailableWidth - alarm.width - 18
        restingY = alarm.screen.virtualY
                   + alarm.screen.desktopAvailableHeight - alarm.height - 18
        y = restingY
    }

    Behavior on x {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    Rectangle {
        x: 11
        y: 14
        width: parent.width - 22
        height: parent.height - 22
        radius: 21
        color: alarm.darkMode ? "#72000000" : "#19000000"
    }

    Rectangle {
        id: notificationCard

        x: 7
        y: 7
        width: parent.width - 14
        height: parent.height - 14
        radius: 20
        color: alarm.darkMode ? "#202023" : "#FFFFFF"
        border.color: alarm.darkMode ? "#414146" : "#E0E0E4"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 16
            anchors.bottomMargin: 16
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                spacing: 11

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 11
                    color: alarm.primaryText

                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        radius: 8
                        color: "transparent"
                        border.color: alarm.darkMode ? "#202023" : "#FFFFFF"
                        border.width: 1.7

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 3
                            width: 1.4
                            height: 5
                            radius: 1
                            color: parent.border.color
                        }

                        Rectangle {
                            x: parent.width / 2
                            y: parent.height / 2
                            width: 4
                            height: 1.4
                            radius: 1
                            color: parent.border.color
                            transformOrigin: Item.Left
                            rotation: 28
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "提醒时间到"
                        color: alarm.primaryText
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: alarm.reminders.currentDueText
                        color: alarm.secondaryText
                        font.family: "Segoe UI Variable Text"
                        font.pixelSize: 10
                    }
                }

                Button {
                    id: closeButton
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    flat: true
                    scale: down ? 0.9 : 1

                    contentItem: Text {
                        text: "×"
                        color: closeButton.hovered
                               ? alarm.primaryText : alarm.secondaryText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: "Segoe UI"
                        font.pixelSize: 18
                    }

                    background: Rectangle {
                        radius: 9
                        color: closeButton.hovered
                               ? (alarm.darkMode ? "#353539" : "#F0F0F2")
                               : "transparent"
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: "关闭并标记为已错过"
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    onClicked: alarm.reminders.dismissCurrentAsMissed()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 75
                radius: 13
                color: alarm.fieldColor

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 11
                    anchors.bottomMargin: 11
                    text: alarm.reminders.currentText
                    color: alarm.primaryText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18

                Text {
                    text: alarm.remainingSeconds + " 秒后归入已错过"
                    color: alarm.secondaryText
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 9
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "声音将在前 30 秒播放"
                    color: alarm.secondaryText
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 9
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 2
                color: alarm.darkMode ? "#3A3A3E" : "#E9E9EC"

                Rectangle {
                    width: parent.width * Math.max(0, alarm.remainingSeconds) / 60
                    height: parent.height
                    radius: parent.radius
                    color: alarm.accent

                    Behavior on width {
                        NumberAnimation { duration: 900; easing.type: Easing.Linear }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                spacing: 8

                Button {
                    id: snoozeFiveButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    text: "5 分钟后"
                    scale: down ? 0.96 : 1
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    onClicked: alarm.reminders.snoozeCurrent(5)
                }

                Button {
                    id: snoozeTenButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    text: "10 分钟后"
                    scale: down ? 0.96 : 1
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    onClicked: alarm.reminders.snoozeCurrent(10)
                }

                Button {
                    id: doneButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    text: "完成"
                    scale: down ? 0.96 : 1

                    contentItem: Text {
                        text: doneButton.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    background: Rectangle {
                        radius: 10
                        color: doneButton.down
                               ? "#005BB7"
                               : doneButton.hovered ? "#1683EA" : alarm.accent
                    }

                    Behavior on scale { NumberAnimation { duration: 80 } }
                    onClicked: alarm.reminders.acknowledgeCurrent()
                }
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (alarm.remainingSeconds > 0)
                alarm.remainingSeconds -= 1
            else
                stop()
        }
    }

    Timer {
        id: hideTimer
        interval: 210
        onTriggered: {
            // 退出动画期间下一条提醒可能已经开始显示。旧计时器不能
            // 把承载新提醒的同一个窗口再次隐藏。
            if (!alarm.reminders.hasCurrent)
                alarm.hide()
        }
    }

    Connections {
        target: alarm.reminders

        function onAlarmRequested() {
            // 取消上一条提醒遗留的延迟隐藏，避免连续提醒刚显示就消失。
            hideTimer.stop()
            alarm.remainingSeconds = 60
            alarm.positionAtBottomRight()
            alarm.x = alarm.restingX + 34
            alarm.opacity = 0
            alarm.show()
            alarm.raise()
            countdownTimer.restart()
            Qt.callLater(function() {
                alarm.x = alarm.restingX
                alarm.opacity = 1
            })
        }

        function onAlarmDismissed() {
            countdownTimer.stop()
            alarm.opacity = 0
            alarm.x = alarm.restingX + 22
            hideTimer.restart()
        }
    }

    onScreenChanged: {
        if (visible) {
            positionAtBottomRight()
            x = restingX
        }
    }

    onClosing: function(close) {
        if (!alarm.reminders.quitting && alarm.reminders.hasCurrent) {
            close.accepted = false
            alarm.reminders.dismissCurrentAsMissed()
        }
    }
}
