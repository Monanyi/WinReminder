pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root

    required property var reminders

    width: 900
    height: 720
    minimumWidth: 600
    minimumHeight: 460
    visible: !root.reminders.startHidden
    title: "WinReminder"
    color: canvasColor

    property bool darkMode: systemPalette.window.hslLightness < 0.45
    property color canvasColor: darkMode ? "#101012" : "#F5F5F7"
    property color surfaceColor: darkMode ? "#1C1C1E" : "#FFFFFF"
    property color elevatedColor: darkMode ? "#262629" : "#FFFFFF"
    property color fieldColor: darkMode ? "#242427" : "#F5F5F7"
    property color hoverColor: darkMode ? "#29292C" : "#F3F3F5"
    property color primaryText: darkMode ? "#F5F5F7" : "#1D1D1F"
    property color secondaryText: darkMode ? "#A1A1A6" : "#6E6E73"
    property color tertiaryText: darkMode ? "#74747A" : "#98989D"
    property color lineColor: darkMode ? "#38383C" : "#DCDCE0"
    property color accent: "#0071E3"
    property color danger: "#FF453A"
    property int pageMargin: width < 700 ? 20 : 30
    readonly property int totalReminderCount:
        root.reminders.count + root.reminders.pendingCount
    readonly property int totalActiveCount:
        root.reminders.activeCount + root.reminders.pendingCount

    function previewPicker(kind) {
        if (kind === "date")
            dateInput.openPicker()
        else if (kind === "time")
            timeInput.openPicker()
    }

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    background: Rectangle {
        color: root.canvasColor

        Behavior on color {
            ColorAnimation { duration: 220 }
        }
    }

    ScrollView {
        id: pageScroll

        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Item {
            width: pageScroll.availableWidth
            height: pageColumn.implicitHeight + 48

            Column {
                id: pageColumn

                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(880, parent.width - root.pageMargin * 2)
                spacing: 16

                Item {
                    width: parent.width
                    height: 64

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 13

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 13
                            color: root.primaryText

                            Rectangle {
                                anchors.centerIn: parent
                                width: 21
                                height: 21
                                radius: 11
                                color: "transparent"
                                border.color: root.canvasColor
                                border.width: 2

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 4
                                    width: 2
                                    height: 7
                                    radius: 1
                                    color: root.canvasColor
                                }

                                Rectangle {
                                    x: parent.width / 2
                                    y: parent.height / 2
                                    width: 6
                                    height: 2
                                    radius: 1
                                    color: root.canvasColor
                                    transformOrigin: Item.Left
                                    rotation: 24
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "WinReminder"
                                color: root.primaryText
                                font.family: "Segoe UI Variable Display"
                                font.pixelSize: 23
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: root.totalReminderCount === 0
                                      ? "安静守候，不错过重要时刻"
                                      : root.totalActiveCount > 0
                                        ? root.totalActiveCount + " 个提醒已安排"
                                          + (root.reminders.missedCount > 0
                                             ? " · " + root.reminders.missedCount + " 个已错过" : "")
                                        : root.reminders.missedCount + " 个提醒已错过"
                                color: root.secondaryText
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7
                            radius: 4
                            color: "#30D158"
                        }

                        Text {
                            text: "后台运行中"
                            color: root.secondaryText
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    id: composeCard

                    width: parent.width
                    height: 250
                    radius: 20
                    color: root.surfaceColor
                    border.color: root.darkMode ? "#303034" : "#E5E5E8"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 220 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        anchors.topMargin: 20
                        anchors.bottomMargin: 20
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            Text {
                                text: "新提醒"
                                color: root.primaryText
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: root.width >= 680
                                text: "输入内容，选择时间"
                                color: root.tertiaryText
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 11
                            }
                        }

                        TextArea {
                            id: reminderInput

                            Layout.fillWidth: true
                            Layout.preferredHeight: 82
                            placeholderText: "要提醒什么？"
                            placeholderTextColor: root.tertiaryText
                            color: root.primaryText
                            selectionColor: root.accent
                            selectedTextColor: "white"
                            wrapMode: TextArea.Wrap
                            leftPadding: 14
                            rightPadding: 14
                            topPadding: 12
                            bottomPadding: 12
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 14

                            background: Rectangle {
                                radius: 13
                                color: root.fieldColor
                                border.color: reminderInput.activeFocus ? root.accent : root.lineColor
                                border.width: reminderInput.activeFocus ? 1.5 : 1

                                Behavior on border.color { ColorAnimation { duration: 140 } }
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }

                            Keys.onPressed: function(event) {
                                if ((event.modifiers & Qt.ControlModifier)
                                        && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    addButton.clicked()
                                    event.accepted = true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 62
                            spacing: 10

                            DateInput {
                                id: dateInput
                                Layout.preferredWidth: 190
                                Layout.fillHeight: true
                                text: root.reminders.defaultDate
                                surfaceColor: root.fieldColor
                                elevatedColor: root.elevatedColor
                                textColor: root.primaryText
                                secondaryTextColor: root.secondaryText
                                borderColor: root.lineColor
                                accentColor: root.accent
                                darkMode: root.darkMode
                            }

                            TimeInput {
                                id: timeInput
                                Layout.preferredWidth: 142
                                Layout.fillHeight: true
                                text: root.reminders.defaultTime
                                surfaceColor: root.fieldColor
                                elevatedColor: root.elevatedColor
                                textColor: root.primaryText
                                secondaryTextColor: root.secondaryText
                                borderColor: root.lineColor
                                accentColor: root.accent
                                darkMode: root.darkMode
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                id: addButton

                                Layout.preferredWidth: root.width < 680 ? 126 : 142
                                Layout.preferredHeight: 42
                                Layout.alignment: Qt.AlignBottom
                                text: "添加提醒"
                                scale: down ? 0.97 : 1

                                contentItem: Text {
                                    text: addButton.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                background: Rectangle {
                                    radius: 11
                                    color: addButton.down
                                           ? "#005BB7"
                                           : addButton.hovered ? "#1683EA" : root.accent

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Behavior on scale { NumberAnimation { duration: 90 } }

                                onClicked: {
                                    const previousCount = root.reminders.count
                                    root.reminders.addReminder(
                                                reminderInput.text,
                                                dateInput.text,
                                                timeInput.text)
                                    if (root.reminders.count > previousCount) {
                                        reminderInput.clear()
                                        reminderInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: reminderCard

                    width: parent.width
                    height: reminderContents.implicitHeight + 36
                    radius: 20
                    color: root.surfaceColor
                    border.color: root.darkMode ? "#303034" : "#E5E5E8"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 220 } }

                    Column {
                        id: reminderContents

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.topMargin: 18
                        spacing: 12

                        Row {
                            width: parent.width
                            height: 30

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "提醒"
                                color: root.primaryText
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.totalReminderCount === 0
                                      ? "没有待处理提醒"
                                      : root.totalActiveCount + " 个待提醒"
                                        + (root.reminders.missedCount > 0
                                           ? " · " + root.reminders.missedCount + " 个已错过" : "")
                                color: root.secondaryText
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.lineColor
                        }

                        Column {
                            id: pendingList

                            width: parent.width
                            visible: root.reminders.pendingCount > 0
                            spacing: 8

                            Repeater {
                                model: root.reminders.pendingItems

                                delegate: Rectangle {
                                    id: pendingDelegate

                                    required property var modelData

                                    width: pendingList.width
                                    height: 78
                                    radius: 14
                                    color: pendingDelegate.modelData.current
                                           ? (root.darkMode ? "#193A5D" : "#E8F3FD")
                                           : root.fieldColor
                                    border.color: pendingDelegate.modelData.current
                                                  ? root.accent : root.lineColor
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            radius: 12
                                            color: pendingDelegate.modelData.current
                                                   ? root.accent
                                                   : (root.darkMode ? "#353539" : "#E9E9ED")

                                            Text {
                                                anchors.centerIn: parent
                                                text: pendingDelegate.modelData.current ? "!" : "…"
                                                color: pendingDelegate.modelData.current
                                                       ? "white" : root.secondaryText
                                                font.family: "Segoe UI"
                                                font.pixelSize: 17
                                                font.weight: Font.DemiBold
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Text {
                                                Layout.fillWidth: true
                                                text: pendingDelegate.modelData.reminderText
                                                color: root.primaryText
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                font.family: "Microsoft YaHei UI"
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                            }

                                            Text {
                                                text: pendingDelegate.modelData.dueText
                                                      + "  ·  "
                                                      + pendingDelegate.modelData.statusText
                                                color: pendingDelegate.modelData.current
                                                       ? root.accent : root.secondaryText
                                                font.family: "Microsoft YaHei UI"
                                                font.pixelSize: 10
                                                font.weight: pendingDelegate.modelData.current
                                                             ? Font.DemiBold : Font.Normal
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: visible ? 1 : 0
                            visible: root.reminders.pendingCount > 0
                                     && root.reminders.count > 0
                            color: root.lineColor
                        }

                        Item {
                            width: parent.width
                            height: root.reminders.count === 0
                                    ? (root.reminders.pendingCount === 0 ? 184 : 0)
                                    : Math.max(78, reminderList.contentHeight)

                            ListView {
                                id: reminderList

                                anchors.fill: parent
                                visible: root.reminders.count > 0
                                interactive: false
                                spacing: 8
                                model: root.reminders

                                add: Transition {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "opacity"
                                            from: 0
                                            to: 1
                                            duration: 220
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            from: 0.97
                                            to: 1
                                            duration: 240
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                remove: Transition {
                                    ParallelAnimation {
                                        NumberAnimation {
                                            property: "opacity"
                                            from: 1
                                            to: 0
                                            duration: 150
                                        }
                                        NumberAnimation {
                                            property: "scale"
                                            from: 1
                                            to: 0.97
                                            duration: 150
                                        }
                                    }
                                }

                                displaced: Transition {
                                    NumberAnimation {
                                        properties: "x,y"
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                delegate: Rectangle {
                                    id: reminderDelegate

                                    required property var reminderId
                                    required property string reminderText
                                    required property string dueText
                                    required property string relativeText
                                    required property bool dueSoon
                                    required property bool reminderMissed

                                    width: reminderList.width
                                    height: 78
                                    radius: 14
                                    color: delegateMouse.containsMouse
                                           ? root.hoverColor : root.surfaceColor
                                    border.color: delegateMouse.containsMouse
                                                  ? root.lineColor : root.surfaceColor
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    MouseArea {
                                        id: delegateMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            radius: 12
                                            color: reminderDelegate.reminderMissed
                                                   ? (root.darkMode ? "#3B2926" : "#FFF1ED")
                                                   : reminderDelegate.dueSoon
                                                     ? (root.darkMode ? "#193A5D" : "#E8F3FD")
                                                     : root.fieldColor

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 16
                                                height: 16
                                                radius: 8
                                                color: "transparent"
                                                border.color: reminderDelegate.reminderMissed
                                                              ? root.danger
                                                              : reminderDelegate.dueSoon
                                                                ? root.accent : root.secondaryText
                                                border.width: 1.5

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
                                            spacing: 4

                                            Text {
                                                Layout.fillWidth: true
                                                text: reminderDelegate.reminderText
                                                color: reminderDelegate.reminderMissed
                                                       ? root.secondaryText : root.primaryText
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                font.family: "Microsoft YaHei UI"
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                            }

                                            Text {
                                                text: reminderDelegate.dueText
                                                      + "  ·  " + reminderDelegate.relativeText
                                                color: reminderDelegate.reminderMissed
                                                       ? root.danger
                                                       : reminderDelegate.dueSoon
                                                       ? root.accent : root.secondaryText
                                                font.family: "Microsoft YaHei UI"
                                                font.pixelSize: 10
                                                font.weight: reminderDelegate.dueSoon
                                                             ? Font.DemiBold : Font.Normal
                                            }
                                        }

                                        Button {
                                            id: deleteButton

                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            flat: true
                                            scale: down ? 0.9 : 1

                                            contentItem: Text {
                                                text: "×"
                                                color: deleteButton.hovered
                                                       ? root.danger : root.tertiaryText
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.family: "Segoe UI"
                                                font.pixelSize: 20
                                            }

                                            background: Rectangle {
                                                radius: 10
                                                color: deleteButton.hovered
                                                       ? (root.darkMode ? "#3A2425" : "#FFF0EF")
                                                       : "transparent"
                                            }

                                            ToolTip.visible: hovered
                                            ToolTip.text: "删除"
                                            Behavior on scale { NumberAnimation { duration: 80 } }
                                            onClicked: root.reminders.removeReminder(
                                                           reminderDelegate.reminderId)
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                visible: root.totalReminderCount === 0
                                spacing: 9

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 46
                                    height: 46
                                    radius: 15
                                    color: root.fieldColor

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: root.secondaryText
                                        font.family: "Segoe UI"
                                        font.pixelSize: 21
                                        font.weight: Font.Medium
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "一切已安排妥当"
                                    color: root.primaryText
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "新的提醒会出现在这里"
                                    color: root.tertiaryText
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.lineColor
                        }

                        Row {
                            width: parent.width
                            height: 34

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "关闭窗口后仍会在托盘运行"
                                color: root.tertiaryText
                                font.family: "Microsoft YaHei UI"
                                font.pixelSize: 10
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "开机启动"
                                    color: root.secondaryText
                                    font.family: "Microsoft YaHei UI"
                                    font.pixelSize: 11
                                }

                                Switch {
                                    id: autorunSwitch
                                    width: 46
                                    height: 28
                                    checked: root.reminders.autorunEnabled
                                    onToggled: root.reminders.autorunEnabled = checked
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: toast

        anchors.horizontalCenter: parent.horizontalCenter
        y: opacity > 0.01 ? 18 : 2
        z: 100
        width: Math.min(root.width - 40, toastRow.implicitWidth + 32)
        height: Math.max(44, toastRow.implicitHeight + 18)
        radius: 14
        opacity: 0
        visible: opacity > 0.01
        color: root.darkMode ? "#2C2C2E" : "#FFFFFF"
        border.color: root.darkMode ? "#444448" : "#DEDEE2"
        border.width: 1

        property bool isError: false

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 9

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: toast.isError ? root.danger : "#30B46B"

                Text {
                    anchors.centerIn: parent
                    text: toast.isError ? "!" : "✓"
                    color: "white"
                    font.family: "Segoe UI"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }

            Text {
                id: toastText
                width: Math.min(460, implicitWidth)
                text: ""
                color: root.primaryText
                wrapMode: Text.Wrap
                font.family: "Microsoft YaHei UI"
                font.pixelSize: 11
            }
        }

        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

        Timer {
            id: toastTimer
            interval: 3000
            onTriggered: toast.opacity = 0
        }

        function showMessage(message, error) {
            toastText.text = message
            toast.isError = error
            toast.opacity = 1
            toastTimer.restart()
        }
    }

    AlarmWindow {
        id: alarmWindow
        reminders: root.reminders
        ownerWindow: root
        darkMode: root.darkMode
        accent: root.accent
        primaryText: root.primaryText
        secondaryText: root.secondaryText
        surfaceColor: root.surfaceColor
        fieldColor: root.fieldColor
        lineColor: root.lineColor
    }

    Connections {
        target: root.reminders

        function onRestoreRequested() {
            root.show()
            root.visibility = Window.Windowed
            root.raise()
            root.requestActivate()
        }

        function onToastRequested(message, isError) {
            toast.showMessage(message, isError)
        }
    }

    onClosing: function(close) {
        if (!root.reminders.quitting) {
            close.accepted = false
            root.hide()
            root.reminders.notifyHidden()
        }
    }

    onVisibilityChanged: {
        if (visibility === Window.Minimized && !root.reminders.quitting) {
            root.hide()
            root.reminders.notifyHidden()
        }
    }

    Component.onCompleted: {
        if (visible)
            reminderInput.forceActiveFocus()
    }
}
