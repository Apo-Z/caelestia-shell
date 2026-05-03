pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.prayer.background ? Tokens.padding.normal : Tokens.padding.small

    // Helper function to get icon for prayer based on time of day
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

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.prayer.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Column {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Loader {
            asynchronous: true
            anchors.horizontalCenter: parent.horizontalCenter

            active: Config.bar.prayer.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: Prayer.nextPrayer ? root.getPrayerIcon(Prayer.nextPrayer.id) : "schedule"
                color: root.colour
                fill: 1

                Behavior on text {
                    enabled: false
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            visible: Config.bar.prayer.showName

            horizontalAlignment: StyledText.AlignHCenter
            text: Prayer.nextName ? Prayer.nextName.substring(0, 3) : "---"
            font.pointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.sans
            color: root.colour
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Config.bar.prayer.showName
            height: visible ? 1 : 0

            width: parent.width * 0.8
            color: root.colour
            opacity: 0.2
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            horizontalAlignment: StyledText.AlignHCenter
            text: Prayer.nextTime ? Prayer.nextTime.replace(":", "\n") : "--\n--"
            font.pointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            color: root.colour
        }
    }
}
