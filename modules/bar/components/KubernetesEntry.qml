pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.misc
import qs.services

StyledRect {
    id: root

    readonly property color statusColor: {
        switch (Kubernetes.clusterHealth) {
        case "error":
            return Colours.palette.m3error;
        case "warning":
            return Colours.palette.m3tertiary;
        case "unknown":
            return Colours.palette.m3onSurfaceVariant;
        default:
            return Colours.palette.m3primary;
        }
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: icon.implicitHeight + Tokens.padding.normal * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Ref {
        service: Kubernetes
    }

    // Kubernetes icon with status indicator
    Item {
        anchors.centerIn: parent
        implicitWidth: icon.implicitWidth
        implicitHeight: icon.implicitHeight

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: Kubernetes.available ? "cloud" : "cloud_off"
            color: root.statusColor

            Behavior on color {
                CAnim {}
            }
        }

        // Status dot indicator (bottom-right)
        StyledRect {
            visible: Kubernetes.available
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -3
            anchors.bottomMargin: -2

            implicitWidth: 8
            implicitHeight: 8
            radius: Tokens.rounding.full
            color: root.statusColor
            border.width: 1.5
            border.color: Colours.tPalette.m3surfaceContainer

            // Pulse animation when there are issues
            SequentialAnimation on opacity {
                running: Kubernetes.clusterHealth === "error"
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.4
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    to: 1
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Badge for failed pod count (only if > 0)
        StyledRect {
            visible: Kubernetes.failedPods > 0
            anchors.left: parent.right
            anchors.top: parent.top
            anchors.leftMargin: -6
            anchors.topMargin: -4

            implicitWidth: Math.max(12, badgeText.implicitWidth + 4)
            implicitHeight: 12
            radius: Tokens.rounding.full
            color: Colours.palette.m3error

            StyledText {
                id: badgeText

                anchors.centerIn: parent
                text: Kubernetes.failedPods > 9 ? "+" : Kubernetes.failedPods
                font.pointSize: Tokens.font.size.smaller - 3
                font.weight: Font.Bold
                color: Colours.palette.m3onError
            }
        }
    }
}
