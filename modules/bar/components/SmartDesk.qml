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
    implicitHeight: Config.bar.sizes.innerWidth

    MaterialIcon {
        id: deskIcon

        anchors.centerIn: parent
        text: SmartDesk.statusIcon
        color: {
            if (SmartDesk.isCalibrating) return Colours.palette.m3tertiary;
            if (SmartDesk.isMoving) return Colours.palette.m3primary;
            return root.colour;
        }
        font.pointSize: Appearance.font.size.large
        animate: true

        RotationAnimator on rotation {
            running: SmartDesk.isCalibrating
            from: 0
            to: 360
            duration: 2000
            loops: Animation.Infinite
        }
    }
}
