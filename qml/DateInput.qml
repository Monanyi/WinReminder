pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Item {
    id: control

    required property color surfaceColor
    required property color elevatedColor
    required property color textColor
    required property color secondaryTextColor
    required property color borderColor
    required property color accentColor
    required property bool darkMode

    property alias text: field.text
    property string label: "日期"

    implicitWidth: 190
    implicitHeight: 62

    function pad(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function syncCalendar() {
        const parts = field.text.split("-")
        const year = Number(parts[0])
        const month = Number(parts[1])
        if (parts.length === 3 && year >= 1900 && month >= 1 && month <= 12) {
            calendarPopup.shownYear = year
            calendarPopup.shownMonth = month - 1
        } else {
            const today = new Date()
            calendarPopup.shownYear = today.getFullYear()
            calendarPopup.shownMonth = today.getMonth()
        }
    }

    function openPicker() {
        control.syncCalendar()
        calendarPopup.open()
    }

    Text {
        id: labelText
        text: control.label
        color: control.secondaryTextColor
        font.family: "Microsoft YaHei UI"
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    TextField {
        id: field

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 42
        inputMask: "0000-00-00;_"
        color: control.textColor
        selectionColor: control.accentColor
        selectedTextColor: "white"
        horizontalAlignment: TextInput.AlignLeft
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: 13
        rightPadding: 45
        font.family: "Segoe UI Variable Text"
        font.pixelSize: 13

        background: Rectangle {
            radius: 11
            color: control.surfaceColor
            border.color: field.activeFocus || calendarPopup.opened
                          ? control.accentColor : control.borderColor
            border.width: field.activeFocus || calendarPopup.opened ? 1.5 : 1

            Behavior on border.color { ColorAnimation { duration: 140 } }
        }
    }

    Button {
        id: calendarButton

        anchors.right: field.right
        anchors.rightMargin: 5
        anchors.verticalCenter: field.verticalCenter
        width: 34
        height: 32
        flat: true
        scale: down ? 0.92 : 1
        Accessible.name: "打开日期选择器"
        ToolTip.visible: hovered
        ToolTip.text: "选择日期"

        contentItem: Item {
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 14
                radius: 3
                color: "transparent"
                border.color: calendarButton.hovered
                              ? control.accentColor : control.secondaryTextColor
                border.width: 1.4

                Rectangle {
                    x: 2
                    y: 4
                    width: parent.width - 4
                    height: 1
                    color: parent.border.color
                }

                Rectangle {
                    x: 3
                    y: -2
                    width: 1.5
                    height: 4
                    radius: 1
                    color: parent.border.color
                }

                Rectangle {
                    x: parent.width - 4.5
                    y: -2
                    width: 1.5
                    height: 4
                    radius: 1
                    color: parent.border.color
                }
            }
        }

        background: Rectangle {
            radius: 8
            color: calendarButton.hovered
                   ? (control.darkMode ? "#303033" : "#ECECF0")
                   : "transparent"
        }

        Behavior on scale { NumberAnimation { duration: 90 } }

        onClicked: control.openPicker()
    }

    Popup {
        id: calendarPopup

        property int shownMonth: 0
        property int shownYear: 2026

        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.max(12, Math.round((parent.height - height) / 2))
        width: Math.min(326, parent.width - 24)
        padding: 16
        modal: false
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        function shiftMonth(offset) {
            let month = shownMonth + offset
            let year = shownYear
            if (month < 0) {
                month = 11
                year -= 1
            } else if (month > 11) {
                month = 0
                year += 1
            }
            shownMonth = month
            shownYear = year
        }

        background: Rectangle {
            radius: 18
            color: control.elevatedColor
            border.color: control.borderColor
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 5
                z: -1
                radius: parent.radius
                color: control.darkMode ? "#50000000" : "#14000000"
            }
        }

        contentItem: Column {
            spacing: 10

            Row {
                width: parent.width
                height: 34

                Button {
                    id: previousButton
                    width: 34
                    height: 34
                    flat: true
                    text: "‹"
                    font.pixelSize: 22
                    onClicked: calendarPopup.shiftMonth(-1)
                }

                Text {
                    width: parent.width - 68
                    height: parent.height
                    text: calendarPopup.shownYear + " 年 " + (calendarPopup.shownMonth + 1) + " 月"
                    color: control.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Button {
                    width: 34
                    height: 34
                    flat: true
                    text: "›"
                    font.pixelSize: 22
                    onClicked: calendarPopup.shiftMonth(1)
                }
            }

            DayOfWeekRow {
                id: weekRow
                width: parent.width
                height: 25
                locale: Qt.locale("zh_CN")
                spacing: 2

                delegate: Text {
                    required property string shortName
                    width: (weekRow.width - weekRow.spacing * 6) / 7
                    height: weekRow.height
                    text: shortName
                    color: control.secondaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }

            MonthGrid {
                id: monthGrid
                width: parent.width
                height: 222
                month: calendarPopup.shownMonth
                year: calendarPopup.shownYear
                locale: Qt.locale("zh_CN")
                spacing: 2

                delegate: Rectangle {
                    required property var model

                    readonly property string dateKey:
                        model.year + "-" + control.pad(model.month + 1) + "-" + control.pad(model.day)
                    readonly property bool selected: dateKey === field.text

                    implicitWidth: (monthGrid.width - monthGrid.spacing * 6) / 7
                    implicitHeight: 35
                    radius: 10
                    color: selected
                           ? control.accentColor
                           : model.today
                             ? (control.darkMode ? "#25364A" : "#EAF3FC")
                             : "transparent"
                    opacity: model.month === monthGrid.month ? 1 : 0.28

                    Text {
                        anchors.centerIn: parent
                        text: parent.model.day
                        color: parent.selected ? "white"
                                               : parent.model.today
                                                 ? control.accentColor : control.textColor
                        font.family: "Segoe UI Variable Text"
                        font.pixelSize: 12
                        font.weight: parent.selected || parent.model.today
                                     ? Font.DemiBold : Font.Normal
                    }
                }

                onClicked: function(date) {
                    field.text = Qt.formatDate(date, "yyyy-MM-dd")
                    calendarPopup.close()
                }
            }

            Button {
                id: todayButton
                width: parent.width
                height: 34
                text: "回到今天"

                contentItem: Text {
                    text: todayButton.text
                    color: control.accentColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                background: Rectangle {
                    radius: 9
                    color: todayButton.hovered
                           ? (control.darkMode ? "#25364A" : "#EDF5FD")
                           : "transparent"
                }

                onClicked: {
                    const today = new Date()
                    field.text = Qt.formatDate(today, "yyyy-MM-dd")
                    calendarPopup.close()
                }
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 170; easing.type: Easing.OutCubic }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 110 }
                NumberAnimation { property: "scale"; from: 1; to: 0.98; duration: 110 }
            }
        }
    }
}
