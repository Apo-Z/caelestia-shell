pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    property color colour: Colours.palette.m3secondary

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full
    clip: true

    implicitWidth: Config.bar.sizes.innerWidth
    implicitHeight: content.implicitHeight + Appearance.padding.normal * 2

    Column {
        id: content

        anchors.centerIn: parent
        spacing: 2

        MaterialIcon {
            id: prayerIcon

            anchors.horizontalCenter: parent.horizontalCenter
            text: "mosque"  // Symbole islamique
            color: root.colour
            font.pointSize: Appearance.font.size.normal
            animate: true
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: PrayerTimes.nextPrayerTime || "--:--"
            color: root.colour
            font.family: Appearance.font.family.mono
            font.pixelSize: Appearance.font.size.smaller
            animate: true
        }
    }

    // Afficher un indicateur de chargement
    MaterialIcon {
        anchors.centerIn: parent
        visible: PrayerTimes.isLoading
        text: "progress_activity"
        color: root.colour

        RotationAnimator on rotation {
            running: PrayerTimes.isLoading
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }
}
