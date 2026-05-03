pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Column {
    id: root

    // Helper function to get icon for prayer
    function getPrayerIcon(prayerId: string): string {
        switch (prayerId) {
            case "fajr": return "dark_mode";        // Moon/night - dawn prayer
            case "chourouk": return "wb_twilight";  // Sunrise
            case "dhuhr": return "light_mode";      // Sun - noon
            case "asr": return "wb_sunny";          // Afternoon sun
            case "maghrib": return "wb_twilight";   // Sunset
            case "isha": return "nights_stay";      // Night
            default: return "schedule";
        }
    }

    spacing: Tokens.spacing.larger
    width: Tokens.sizes.bar.prayerWidth

    // Header with next prayer - prominent display
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.small

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Next Prayer")
            font.pointSize: Tokens.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.normal

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Prayer.nextPrayer ? root.getPrayerIcon(Prayer.nextPrayer.id) : "schedule"
                font.pointSize: Tokens.font.size.extraLarge
                color: Colours.palette.m3primary
                fill: 1
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                StyledText {
                    text: Prayer.nextName || qsTr("Loading...")
                    font.pointSize: Tokens.font.size.large
                    font.weight: Font.Bold
                    color: Colours.palette.m3primary
                }

                StyledText {
                    text: Prayer.nextTime || "--:--"
                    font.pointSize: Tokens.font.size.extraLarge
                    font.family: Tokens.font.family.mono
                    font.weight: Font.Bold
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }

    // Divider
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 1
        color: Colours.palette.m3outlineVariant
        opacity: 0.3
    }

    // All prayers - horizontal layout
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.normal

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Today's Prayers")
            font.pointSize: Tokens.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }

        // Prayer list
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.small

            Repeater {
                model: Prayer.prayers

                delegate: StyledRect {
                    id: prayerDelegate

                    required property var modelData
                    required property int index

                    readonly property bool isNext: index === Prayer.nextIndex
                    readonly property bool isSunrise: modelData ? modelData.id === "chourouk" : false
                    readonly property string prayerName: modelData ? modelData.name : ""
                    readonly property string prayerTime: modelData ? modelData.time : "--:--"
                    readonly property string prayerId: modelData ? modelData.id : ""

                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: prayerRow.implicitWidth + Tokens.padding.normal * 2
                    implicitHeight: prayerRow.implicitHeight + Tokens.padding.small * 2

                    color: isNext ? Colours.palette.m3primaryContainer : "transparent"
                    radius: Tokens.rounding.normal
                    opacity: isNext ? 1 : (isSunrise ? 0.5 : 0.8)

                    Row {
                        id: prayerRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.normal

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.getPrayerIcon(prayerDelegate.prayerId)
                            font.pointSize: Tokens.font.size.normal
                            color: prayerDelegate.isNext ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            fill: prayerDelegate.isNext ? 1 : 0
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: prayerDelegate.prayerName
                            font.pointSize: Tokens.font.size.normal
                            font.weight: prayerDelegate.isNext ? Font.Bold : Font.Normal
                            color: prayerDelegate.isNext ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            horizontalAlignment: Text.AlignLeft
                            Layout.preferredWidth: 60
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: prayerDelegate.prayerTime
                            font.pointSize: Tokens.font.size.normal
                            font.family: Tokens.font.family.mono
                            font.weight: prayerDelegate.isNext ? Font.Bold : Font.Medium
                            color: prayerDelegate.isNext ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        }
                    }
                }
            }
        }
    }

    // Error display
    Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        active: Prayer.error !== ""
        visible: active

        sourceComponent: StyledRect {
            implicitWidth: errorRow.implicitWidth + Tokens.padding.normal * 2
            implicitHeight: errorRow.implicitHeight + Tokens.padding.small * 2
            color: Qt.alpha(Colours.palette.m3errorContainer, 0.5)
            radius: Tokens.rounding.small

            Row {
                id: errorRow
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "error"
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3error
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Prayer.error
                    font.pointSize: Tokens.font.size.small
                    color: Colours.palette.m3error
                }
            }
        }
    }

    // Reload button
    IconTextButton {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Prayer.loading ? qsTr("Loading...") : qsTr("Reload")
        icon: Prayer.loading ? "sync" : "refresh"
        enabled: !Prayer.loading
        onClicked: Prayer.reload()
    }
}
