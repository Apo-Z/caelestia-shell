pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Item wrapper

    spacing: Appearance.spacing.small

    // Header avec badge de statut
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.padding.normal
        Layout.rightMargin: Appearance.padding.small
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Kubernetes")
            font.weight: 600
            font.pixelSize: Appearance.font.size.normal
        }

        StyledRect {
            implicitWidth: statusLabel.implicitWidth + Appearance.padding.small * 2
            implicitHeight: statusLabel.implicitHeight + Appearance.padding.smaller * 2

            radius: Appearance.rounding.full
            color: {
                if (!Kubernetes.isConnected) return Colours.palette.m3errorContainer;
                switch (Kubernetes.statusClass) {
                    case "critical": return Colours.palette.m3errorContainer;
                    case "warning": return Qt.rgba(1.0, 0.6, 0.0, 0.2);
                    default: return Colours.palette.m3tertiaryContainer;
                }
            }

            StyledText {
                id: statusLabel
                anchors.centerIn: parent
                text: Kubernetes.isConnected ? qsTr("Connected") : qsTr("Offline")
                color: {
                    if (!Kubernetes.isConnected) return Colours.palette.m3onErrorContainer;
                    switch (Kubernetes.statusClass) {
                        case "critical": return Colours.palette.m3onErrorContainer;
                        case "warning": return Qt.rgba(1.0, 0.6, 0.0, 1.0);
                        default: return Colours.palette.m3onTertiaryContainer;
                    }
                }
                font.pixelSize: Appearance.font.size.smaller
                font.weight: 500
            }

            Behavior on color {
                CAnim {}
            }
        }

        MaterialIcon {
            visible: Kubernetes.isLoading
            text: "progress_activity"
            color: Colours.palette.m3primary

            RotationAnimator on rotation {
                running: Kubernetes.isLoading
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }
    }

    // Nom du cluster
    StyledText {
        Layout.rightMargin: Appearance.padding.small
        visible: Kubernetes.isConnected
        text: Kubernetes.clusterContext || qsTr("Unknown cluster")
        color: Colours.palette.m3onSurfaceVariant
        font.pixelSize: Appearance.font.size.small
    }

    // Stats
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        Layout.rightMargin: Appearance.padding.small
        visible: Kubernetes.isConnected
        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: "dns"
            color: Kubernetes.nodesReady === Kubernetes.nodesTotal
                ? Colours.palette.m3tertiary
                : Colours.palette.m3error
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Nodes: %1/%2").arg(Kubernetes.nodesReady).arg(Kubernetes.nodesTotal)
            font.pixelSize: Appearance.font.size.small
        }

        StyledText {
            text: `${Kubernetes.nodesReady}/${Kubernetes.nodesTotal}`
            color: Kubernetes.nodesReady === Kubernetes.nodesTotal
                ? Colours.palette.m3tertiary
                : Colours.palette.m3error
            font.weight: 600
            font.pixelSize: Appearance.font.size.small
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Appearance.padding.small
        visible: Kubernetes.isConnected
        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: "deployed_code"
            color: Kubernetes.podsFailed > 0
                ? Colours.palette.m3error
                : Colours.palette.m3primary
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Pods running")
            font.pixelSize: Appearance.font.size.small
        }

        StyledText {
            text: Kubernetes.podsRunning.toString()
            color: Kubernetes.podsFailed > 0
                ? Colours.palette.m3error
                : Colours.palette.m3primary
            font.weight: 600
            font.pixelSize: Appearance.font.size.small
        }
    }

    // Failed pods warning
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        Layout.rightMargin: Appearance.padding.small
        visible: Kubernetes.podsFailed > 0
        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: "warning"
            color: Colours.palette.m3error
            font.pointSize: Appearance.font.size.normal
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("%1 failed").arg(Kubernetes.podsFailed)
            color: Colours.palette.m3error
            font.weight: 500
            font.pixelSize: Appearance.font.size.small
        }
    }

    // Open panel button
    StyledRect {
        Layout.topMargin: Appearance.spacing.small
        implicitWidth: expandBtn.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: expandBtn.implicitHeight + Appearance.padding.small

        radius: Appearance.rounding.normal
        color: Colours.palette.m3primaryContainer

        StateLayer {
            color: Colours.palette.m3onPrimaryContainer

            function onClicked(): void {
                root.wrapper.detach("kubernetes");
            }
        }

        RowLayout {
            id: expandBtn

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            StyledText {
                Layout.leftMargin: Appearance.padding.smaller
                text: qsTr("Open panel")
                color: Colours.palette.m3onPrimaryContainer
            }

            MaterialIcon {
                text: "chevron_right"
                color: Colours.palette.m3onPrimaryContainer
                font.pointSize: Appearance.font.size.large
            }
        }
    }

}
