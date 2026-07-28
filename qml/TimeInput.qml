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
    property string label: "时间"

    implicitWidth: 150
    implicitHeight: 62

    function pad(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function syncPicker() {
        const parts = field.text.split(":")
        const hour = Number(parts[0])
        const minute = Number(parts[1])
        if (parts.length === 2 && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            hourWheel.currentIndex = hour
            minuteWheel.currentIndex = minute
        } else {
            const now = new Date()
            hourWheel.currentIndex = now.getHours()
            minuteWheel.currentIndex = now.getMinutes()
        }
    }

    function openPicker() {
        control.syncPicker()
        timePopup.open()
    }

    Text {
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
        inputMask: "00:00;_"
        color: control.textColor
        selectionColor: control.accentColor
        selectedTextColor: "white"
        leftPadding: 13
        rightPadding: 43
        verticalAlignment: TextInput.AlignVCenter
        font.family: "Segoe UI Variable Text"
        font.pixelSize: 13

        background: Rectangle {
            radius: 11
            color: control.surfaceColor
            border.color: field.activeFocus || timePopup.opened
                          ? control.accentColor : control.borderColor
            border.width: field.activeFocus || timePopup.opened ? 1.5 : 1

            Behavior on border.color { ColorAnimation { duration: 140 } }
        }
    }

    Button {
        id: timeButton

        anchors.right: field.right
        anchors.rightMargin: 5
        anchors.verticalCenter: field.verticalCenter
        width: 33
        height: 32
        flat: true
        scale: down ? 0.92 : 1
        Accessible.name: "打开时间选择器"
        ToolTip.visible: hovered
        ToolTip.text: "选择时间"

        contentItem: Item {
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 15
                radius: 8
                color: "transparent"
                border.color: timeButton.hovered
                              ? control.accentColor : control.secondaryTextColor
                border.width: 1.4

                Rectangle {
                    anchors.centerIn: parent
                    width: 1.3
                    height: 5
                    radius: 1
                    color: parent.border.color
                    transform: Translate { y: -2 }
                }

                Rectangle {
                    x: parent.width / 2
                    y: parent.height / 2
                    width: 4
                    height: 1.3
                    radius: 1
                    color: parent.border.color
                    transformOrigin: Item.Left
                    rotation: 28
                }
            }
        }

        background: Rectangle {
            radius: 8
            color: timeButton.hovered
                   ? (control.darkMode ? "#303033" : "#ECECF0")
                   : "transparent"
        }

        Behavior on scale { NumberAnimation { duration: 90 } }

        onClicked: control.openPicker()
    }

    Popup {
        id: timePopup

        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.max(12, Math.round((parent.height - height) / 2))
        width: Math.min(264, parent.width - 24)
        padding: 16
        modal: false
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

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
            spacing: 12

            Text {
                width: parent.width
                text: "选择时间"
                color: control.textColor
                horizontalAlignment: Text.AlignHCenter
                font.family: "Microsoft YaHei UI"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Item {
                width: parent.width
                height: 142

                Rectangle {
                    anchors.centerIn: parent
                    width: 156
                    height: 40
                    radius: 11
                    color: control.darkMode ? "#2A2A2D" : "#F1F1F3"
                }

                Row {
                    anchors.centerIn: parent
                    height: parent.height
                    spacing: 6

                    Tumbler {
                        id: hourWheel
                        width: 70
                        height: parent.height
                        model: 24
                        visibleItemCount: 3
                        wrap: true

                        delegate: Text {
                            required property int modelData
                            text: control.pad(modelData)
                            color: control.textColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: 1.0 - Math.abs(Tumbler.displacement) / 2.2
                            font.family: "Segoe UI Variable Display"
                            font.pixelSize: 19
                            font.weight: Math.abs(Tumbler.displacement) < 0.1
                                         ? Font.DemiBold : Font.Normal
                        }
                    }

                    Text {
                        height: parent.height
                        text: ":"
                        color: control.secondaryTextColor
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }

                    Tumbler {
                        id: minuteWheel
                        width: 70
                        height: parent.height
                        model: 60
                        visibleItemCount: 3
                        wrap: true

                        delegate: Text {
                            required property int modelData
                            text: control.pad(modelData)
                            color: control.textColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: 1.0 - Math.abs(Tumbler.displacement) / 2.2
                            font.family: "Segoe UI Variable Display"
                            font.pixelSize: 19
                            font.weight: Math.abs(Tumbler.displacement) < 0.1
                                         ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 38
                spacing: 8

                Button {
                    id: cancelButton
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    text: "取消"
                    onClicked: timePopup.close()
                }

                Button {
                    id: confirmButton
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    text: "确定"
                    scale: down ? 0.97 : 1

                    contentItem: Text {
                        text: confirmButton.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    background: Rectangle {
                        radius: 10
                        color: confirmButton.down
                               ? (control.darkMode ? "#0A5DB8" : "#005EBB")
                               : confirmButton.hovered ? "#1683EA" : control.accentColor
                    }

                    Behavior on scale { NumberAnimation { duration: 90 } }

                    onClicked: {
                        field.text = control.pad(hourWheel.currentIndex)
                                   + ":" + control.pad(minuteWheel.currentIndex)
                        timePopup.close()
                    }
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
