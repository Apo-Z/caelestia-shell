pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.effects
import qs.components.containers
import qs.components.controls
import qs.config
import qs.services
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property Session session

    anchors.fill: parent
    spacing: 0

    // Left panel - Cluster overview & nodes
    Item {
        Layout.preferredWidth: Math.floor(parent.width * 0.4)
        Layout.minimumWidth: 420
        Layout.fillHeight: true

        StyledFlickable {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large + Appearance.padding.normal / 2

            flickableDirection: Flickable.VerticalFlick
            contentHeight: leftColumn.height

            ColumnLayout {
                id: leftColumn

                width: parent.width
                spacing: Appearance.spacing.large

                // Cluster status header
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    RowLayout {
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
                            font.pointSize: Appearance.font.size.large * 1.5
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Kubernetes.clusterContext || qsTr("Kubernetes Cluster")
                            font.weight: 600
                            font.pixelSize: Appearance.font.size.large
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

                    StyledText {
                        text: Kubernetes.isConnected
                            ? qsTr("Connected")
                            : qsTr("Disconnected")
                        color: Kubernetes.isConnected
                            ? Colours.palette.m3tertiary
                            : Colours.palette.m3error
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                // Stats cards
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StatCard {
                        Layout.fillWidth: true
                        title: qsTr("Nodes")
                        value: `${Kubernetes.nodesReady}/${Kubernetes.nodesTotal}`
                        icon: "dns"
                        iconColor: Kubernetes.nodesReady === Kubernetes.nodesTotal
                            ? Colours.palette.m3tertiary
                            : Colours.palette.m3error
                    }

                    StatCard {
                        Layout.fillWidth: true
                        title: qsTr("Pods")
                        value: `${Kubernetes.podsRunning}/${Kubernetes.podsTotal}`
                        icon: "deployed_code"
                        iconColor: Kubernetes.podsFailed > 0
                            ? Colours.palette.m3error
                            : Colours.palette.m3primary
                    }
                }

                // Nodes list
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: qsTr("Nodes")
                        font.weight: 600
                    }

                    Repeater {
                        model: Kubernetes.nodesList

                        StyledRect {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: nodeContent.implicitHeight + Appearance.padding.large * 2

                            color: Colours.tPalette.m3surfaceContainerHigh
                            radius: Appearance.rounding.large

                            ColumnLayout {
                                id: nodeContent

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.large
                                spacing: Appearance.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.normal

                                    MaterialIcon {
                                        text: modelData.status.includes("Ready") ? "check_circle" : "error"
                                        color: modelData.status.includes("Ready")
                                            ? Colours.palette.m3tertiary
                                            : Colours.palette.m3error
                                        font.pointSize: Appearance.font.size.large
                                    }

                                    Column {
                                        Layout.fillWidth: true

                                        StyledText {
                                            text: modelData.name
                                            font.weight: 600
                                        }

                                        StyledText {
                                            text: `${modelData.role} • ${modelData.version}`
                                            font.pixelSize: Appearance.font.size.small
                                            color: Colours.palette.m3onSurfaceVariant
                                        }
                                    }

                                    StyledText {
                                        text: modelData.status
                                        font.family: Appearance.font.family.mono
                                        font.pixelSize: Appearance.font.size.small
                                        color: modelData.status.includes("Ready")
                                            ? Colours.palette.m3tertiary
                                            : Colours.palette.m3error
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        InnerBorder {
            leftThickness: 0
            rightThickness: Appearance.padding.normal / 2
        }
    }

    // Right panel - Pods & actions
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        StyledFlickable {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large + Appearance.padding.normal / 2
            anchors.rightMargin: Appearance.padding.large

            flickableDirection: Flickable.VerticalFlick
            contentHeight: rightColumn.height

            ColumnLayout {
                id: rightColumn

                width: parent.width
                spacing: Appearance.spacing.large

                // Namespaces
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: qsTr("Top Namespaces")
                        font.weight: 600
                    }

                    Repeater {
                        model: Kubernetes.namespaceStats

                        StyledRect {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: nsContent.implicitHeight + Appearance.padding.normal * 2

                            color: Colours.tPalette.m3surfaceContainer
                            radius: Appearance.rounding.normal

                            RowLayout {
                                id: nsContent

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.normal
                                spacing: Appearance.spacing.normal

                                MaterialIcon {
                                    text: "folder"
                                    color: Colours.palette.m3secondary
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.namespace
                                    font.weight: 500
                                }

                                StyledText {
                                    text: `${modelData.count} pods`
                                    font.family: Appearance.font.family.mono
                                    font.pixelSize: Appearance.font.size.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }
                }

                // Pod status
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: qsTr("Pod Status")
                        font.weight: 600
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        PodStatusCard {
                            Layout.fillWidth: true
                            title: qsTr("Running")
                            value: Kubernetes.podsRunning
                            icon: "play_circle"
                            iconColor: Colours.palette.m3tertiary
                        }

                        PodStatusCard {
                            Layout.fillWidth: true
                            title: qsTr("Failed")
                            value: Kubernetes.podsFailed
                            icon: "error"
                            iconColor: Colours.palette.m3error
                        }

                        PodStatusCard {
                            Layout.fillWidth: true
                            title: qsTr("Pending")
                            value: Kubernetes.podsPending
                            icon: "pending"
                            iconColor: Colours.palette.m3tertiary
                        }
                    }
                }

                // Actions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: qsTr("Actions")
                        font.weight: 600
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "refresh"
                        text: qsTr("Refresh Cluster Data")
                        onClicked: Kubernetes.refresh()
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "event"
                        text: qsTr("View Events in Terminal")
                        onClicked: Kubernetes.getEvents("all")
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        icon: "delete_sweep"
                        text: qsTr("Delete Inactive Pods")
                        dangerous: true
                        onClicked: Kubernetes.deleteInactivePods()
                    }
                }

                // Error message
                StyledRect {
                    visible: Kubernetes.errorMessage.length > 0
                    Layout.fillWidth: true
                    implicitHeight: errorContent.implicitHeight + Appearance.padding.large * 2

                    color: Colours.palette.m3errorContainer
                    radius: Appearance.rounding.large

                    RowLayout {
                        id: errorContent

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.normal

                        MaterialIcon {
                            text: "warning"
                            color: Colours.palette.m3onErrorContainer
                            font.pointSize: Appearance.font.size.large
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Kubernetes.errorMessage
                            color: Colours.palette.m3onErrorContainer
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        InnerBorder {
            leftThickness: Appearance.padding.normal / 2
        }
    }

    // Components
    component StatCard: StyledRect {
        property string title
        property string value
        property string icon
        property color iconColor: Colours.palette.m3primary

        implicitHeight: statContent.implicitHeight + Appearance.padding.large * 2

        color: Colours.tPalette.m3surfaceContainerHigh
        radius: Appearance.rounding.large

        ColumnLayout {
            id: statContent

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: parent.parent.icon
                color: parent.parent.iconColor
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                text: parent.parent.value
                font.weight: 700
                font.pixelSize: Appearance.font.size.large * 1.2
                color: parent.parent.iconColor
            }

            StyledText {
                text: parent.parent.title
                font.pixelSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    component PodStatusCard: StyledRect {
        id: podCard

        property string title
        property int value
        property string icon
        property color iconColor: Colours.palette.m3primary

        implicitHeight: podContent.implicitHeight + Appearance.padding.normal * 2

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.normal

        RowLayout {
            id: podContent

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: podCard.icon
                color: podCard.iconColor
            }

            Column {
                Layout.fillWidth: true

                StyledText {
                    text: podCard.value.toString()
                    font.weight: 600
                    color: podCard.iconColor
                }

                StyledText {
                    text: podCard.title
                    font.pixelSize: Appearance.font.size.smaller
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    component ActionButton: StyledRect {
        property string text
        property string icon
        property bool dangerous: false
        signal clicked()

        implicitHeight: btnContent.implicitHeight + Appearance.padding.large * 2

        color: dangerous ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.large

        StateLayer {
            radius: Appearance.rounding.large

            function onClicked(): void {
                parent.clicked();
            }
        }

        RowLayout {
            id: btnContent

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: parent.parent.icon
                color: dangerous ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: parent.parent.text
                color: dangerous ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
                font.weight: 500
            }
        }
    }
}
