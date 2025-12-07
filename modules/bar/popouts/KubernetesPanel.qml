pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    spacing: Appearance.spacing.small
    width: Config.bar.sizes.networkWidth

    // Header
    RowLayout {
        Layout.topMargin: Appearance.padding.normal
        Layout.leftMargin: Appearance.padding.small
        Layout.rightMargin: Appearance.padding.small
        Layout.fillWidth: true

        MaterialIcon {
            text: Kubernetes.getStatusIcon()
            color: {
                if (!Kubernetes.isConnected) return Colours.palette.m3error;
                switch (Kubernetes.statusClass) {
                    case "critical": return Colours.palette.m3error;
                    case "warning": return Colours.palette.m3tertiary;
                    default: return Colours.palette.m3primary;
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Kubernetes.clusterContext || qsTr("Kubernetes")
            font.weight: 500
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

    // Status summary
    StyledText {
        Layout.leftMargin: Appearance.padding.small
        Layout.rightMargin: Appearance.padding.small
        text: Kubernetes.isConnected
            ? qsTr("Nodes: %1/%2 • Pods: %3/%4").arg(Kubernetes.nodesReady).arg(Kubernetes.nodesTotal).arg(Kubernetes.podsRunning).arg(Kubernetes.podsTotal)
            : qsTr("Disconnected")
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.small
    }

    // Nodes section
    StyledText {
        visible: Kubernetes.nodesList.length > 0
        Layout.topMargin: Appearance.spacing.normal
        Layout.leftMargin: Appearance.padding.small
        text: qsTr("Nodes")
        font.weight: 500
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {
        model: Kubernetes.nodesList

        RowLayout {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: Appearance.padding.small
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: modelData.status.includes("Ready") ? "check_circle" : "error"
                color: modelData.status.includes("Ready") ? Colours.palette.m3tertiary : Colours.palette.m3error
                font.pointSize: Appearance.font.size.normal
            }

            Column {
                Layout.fillWidth: true

                StyledText {
                    text: modelData.name
                    font.weight: 500
                    font.pixelSize: Appearance.font.size.small
                }

                StyledText {
                    text: `${modelData.role} • ${modelData.version}`
                    font.pixelSize: Appearance.font.size.smaller
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    // Namespaces section
    StyledText {
        visible: Kubernetes.namespaceStats.length > 0
        Layout.topMargin: Appearance.spacing.normal
        Layout.leftMargin: Appearance.padding.small
        text: qsTr("Top Namespaces")
        font.weight: 500
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {
        model: Kubernetes.namespaceStats

        RowLayout {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: Appearance.padding.small
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "folder"
                color: Colours.palette.m3secondary
            }

            StyledText {
                Layout.fillWidth: true
                text: modelData.namespace
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            StyledText {
                text: `${modelData.count}`
                font.family: Appearance.font.family.mono
                font.pixelSize: Appearance.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // Actions section
    StyledText {
        Layout.topMargin: Appearance.spacing.normal
        Layout.leftMargin: Appearance.padding.small
        text: qsTr("Actions")
        font.weight: 500
        font.pixelSize: Appearance.font.size.small
    }

    // Refresh button
    ActionButton {
        Layout.leftMargin: Appearance.padding.small
        Layout.rightMargin: Appearance.padding.small
        icon: "refresh"
        text: qsTr("Refresh")
        onClicked: Kubernetes.refresh()
    }

    // View events button
    ActionButton {
        Layout.leftMargin: Appearance.padding.small
        Layout.rightMargin: Appearance.padding.small
        icon: "event"
        text: qsTr("View Events")
        onClicked: Kubernetes.getEvents("all")
    }

    // Delete inactive pods button
    ActionButton {
        Layout.leftMargin: Appearance.padding.small
        Layout.rightMargin: Appearance.padding.small
        Layout.bottomMargin: Appearance.padding.normal
        icon: "delete_sweep"
        text: qsTr("Delete Inactive Pods")
        dangerous: true
        onClicked: Kubernetes.deleteInactivePods()
    }

    // Error message
    StyledRect {
        visible: Kubernetes.errorMessage.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: Appearance.padding.small
        Layout.rightMargin: Appearance.padding.small
        Layout.bottomMargin: Appearance.padding.normal
        implicitHeight: errorContent.implicitHeight + Appearance.padding.normal * 2

        color: Colours.palette.m3errorContainer
        radius: Appearance.rounding.normal

        RowLayout {
            id: errorContent

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "warning"
                color: Colours.palette.m3onErrorContainer
            }

            StyledText {
                Layout.fillWidth: true
                text: Kubernetes.errorMessage
                color: Colours.palette.m3onErrorContainer
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    component ActionButton: StyledRect {
        property string text
        property string icon
        property bool dangerous: false
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: btnContent.implicitHeight + Appearance.padding.normal * 2

        color: dangerous ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.normal

        StateLayer {
            radius: Appearance.rounding.normal

            function onClicked(): void {
                parent.clicked();
            }
        }

        RowLayout {
            id: btnContent

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: parent.parent.icon
                color: dangerous ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
            }

            StyledText {
                Layout.fillWidth: true
                text: parent.parent.text
                color: dangerous ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
                font.pixelSize: Appearance.font.size.small
            }
        }
    }
}
