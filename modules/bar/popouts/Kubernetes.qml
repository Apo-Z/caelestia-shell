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

    width: Config.bar.sizes.kubernetesWidth
    spacing: Appearance.spacing.normal

    // Titre centré
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: qsTr("Kubernetes")
        font.weight: 600
        font.pixelSize: Appearance.font.size.normal
    }

    // Badge de statut
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Appearance.spacing.normal

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
        Layout.alignment: Qt.AlignHCenter
        visible: Kubernetes.isConnected
        text: Kubernetes.clusterContext || qsTr("Unknown cluster")
        color: Colours.palette.m3onSurfaceVariant
        font.pixelSize: Appearance.font.size.small
    }

    // Stats - Nodes
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: nodesRow.implicitHeight + Appearance.padding.normal * 2
        visible: Kubernetes.isConnected

        color: Colours.tPalette.m3surfaceContainerHigh
        radius: Appearance.rounding.normal

        RowLayout {
            id: nodesRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: "workspaces"
                color: Kubernetes.nodesReady === Kubernetes.nodesTotal
                    ? Colours.palette.m3tertiary
                    : Colours.palette.m3error
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Nodes")
                font.weight: 500
            }

            StyledText {
                text: `${Kubernetes.nodesReady}/${Kubernetes.nodesTotal}`
                color: Kubernetes.nodesReady === Kubernetes.nodesTotal
                    ? Colours.palette.m3tertiary
                    : Colours.palette.m3error
                font.weight: 600
            }
        }
    }

    // Stats - Pods Running
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: podsRow.implicitHeight + Appearance.padding.normal * 2
        visible: Kubernetes.isConnected

        color: Colours.tPalette.m3surfaceContainerHigh
        radius: Appearance.rounding.normal

        RowLayout {
            id: podsRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: "deployed_code"
                color: Kubernetes.podsFailed > 0
                    ? Colours.palette.m3error
                    : Colours.palette.m3primary
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Pods running")
                font.weight: 500
            }

            StyledText {
                text: Kubernetes.podsRunning.toString()
                color: Kubernetes.podsFailed > 0
                    ? Colours.palette.m3error
                    : Colours.palette.m3primary
                font.weight: 600
            }
        }
    }

    // Failed pods warning
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: failedRow.implicitHeight + Appearance.padding.normal * 2
        visible: Kubernetes.podsFailed > 0

        color: Colours.palette.m3errorContainer
        radius: Appearance.rounding.normal

        RowLayout {
            id: failedRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: "warning"
                color: Colours.palette.m3onErrorContainer
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Failed pods")
                color: Colours.palette.m3onErrorContainer
                font.weight: 500
            }

            StyledText {
                text: Kubernetes.podsFailed.toString()
                color: Colours.palette.m3onErrorContainer
                font.weight: 600
            }
        }
    }

    // Open panel button
    StyledRect {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: expandBtn.implicitWidth + Appearance.padding.large * 2
        implicitHeight: expandBtn.implicitHeight + Appearance.padding.normal * 2

        radius: Appearance.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        StateLayer {
            radius: Appearance.rounding.full

            function onClicked(): void {
                root.wrapper.detach("kubernetes");
            }
        }

        RowLayout {
            id: expandBtn

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "open_in_new"
                color: Colours.palette.m3primary
            }

            StyledText {
                text: qsTr("Open panel")
                color: Colours.palette.m3primary
            }
        }
    }

}
