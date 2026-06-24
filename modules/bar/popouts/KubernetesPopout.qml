pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

ColumnLayout {
    id: root

    required property PopoutState popouts

    width: 300
    spacing: Tokens.spacing.small

    Ref {
        service: Kubernetes
    }

    // Header with context info
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.medium
        Layout.rightMargin: Tokens.padding.small
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: Kubernetes.available ? "cloud" : "cloud_off"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Kubernetes.currentContext || qsTr("No cluster")
                font.weight: Font.Medium
                elide: Text.ElideMiddle
            }

            StyledText {
                text: `ns: ${Kubernetes.currentNamespace}`
                font.pointSize: Tokens.font.body.small.pointSize
                font.family: Tokens.font.mono.small.family
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        // Open full panel button
        StyledRect {
            implicitWidth: 28
            implicitHeight: 28
            radius: Tokens.rounding.full
            color: Colours.palette.m3primaryContainer

            StateLayer {
                color: Colours.palette.m3onPrimaryContainer
                onClicked: {
                    root.popouts.hasCurrent = false;
                    const v = Visibilities.getForActive();
                    if (v)
                        v.kubernetes = true;
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "open_in_full"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3onPrimaryContainer
            }
        }
    }

    // Not available message
    ColumnLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small
        visible: !Kubernetes.available
        spacing: Tokens.spacing.small

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: notAvailableContent.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.medium
            color: Qt.alpha(Colours.palette.m3errorContainer, 0.5)

            ColumnLayout {
                id: notAvailableContent

                anchors.centerIn: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "warning"
                        color: Colours.palette.m3error
                    }

                    StyledText {
                        text: qsTr("Cluster unavailable")
                        color: Colours.palette.m3onErrorContainer
                        font.weight: Font.Medium
                    }
                }

                 StyledText {
                    visible: Kubernetes.lastError
                    text: Kubernetes.lastError
                    font.pointSize: Tokens.font.body.small.pointSize
                    color: Colours.palette.m3onErrorContainer
                    opacity: 0.8
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    // Quick stats
    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small
        spacing: Tokens.spacing.small
        visible: Kubernetes.available

        StatBox {
            Layout.fillWidth: true
            icon: "check_circle"
            value: Kubernetes.runningPods
            label: qsTr("Running")
            boxColor: Colours.palette.m3primary
        }

        StatBox {
            Layout.fillWidth: true
            icon: "pending"
            value: Kubernetes.pendingPods
            label: qsTr("Pending")
            boxColor: Colours.palette.m3tertiary
            visible: Kubernetes.pendingPods > 0
        }

        StatBox {
            Layout.fillWidth: true
            icon: "error"
            value: Kubernetes.failedPods
            label: qsTr("Failed")
            boxColor: Colours.palette.m3error
            visible: Kubernetes.failedPods > 0
        }
    }

    // Separator
    StyledRect {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small
        visible: Kubernetes.available && Kubernetes.nodes.length > 0
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    // Nodes section
        StyledText {
            Layout.rightMargin: Tokens.padding.small
            visible: Kubernetes.available && Kubernetes.nodes.length > 0
            text: qsTr("Nodes")
            font.weight: Font.Medium
            font.pointSize: Tokens.font.body.small.pointSize
        color: Colours.palette.m3onSurfaceVariant
    }

    Repeater {
        model: Kubernetes.nodes.slice(0, 4)

        RowLayout {
            id: nodeRow

            required property var modelData
            required property int index

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            opacity: 0
            scale: 0.9

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }

            StyledRect {
                implicitWidth: 8
                implicitHeight: 8
                radius: Tokens.rounding.full
                color: nodeRow.modelData.status === "Ready" ? Colours.palette.m3primary : Colours.palette.m3error
            }

            StyledText {
                Layout.fillWidth: true
                text: nodeRow.modelData.name
                font.family: Tokens.font.mono.small.family
                font.pointSize: Tokens.font.body.small.pointSize
                elide: Text.ElideMiddle
            }

            StyledText {
                text: nodeRow.modelData.roles
                font.pointSize: Tokens.font.body.small.pointSize
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    // More nodes indicator
    StyledText {
        Layout.rightMargin: Tokens.padding.small
        visible: Kubernetes.nodes.length > 4
        text: qsTr("+ %1 more nodes").arg(Kubernetes.nodes.length - 4)
        font.pointSize: Tokens.font.body.small.pointSize
        color: Colours.palette.m3onSurfaceVariant
        font.italic: true
    }

    // Separator for unhealthy pods
    StyledRect {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small
        visible: unhealthyPods.count > 0
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    // Unhealthy pods section
    StyledText {
        Layout.rightMargin: Tokens.padding.small
        visible: unhealthyPods.count > 0
        text: qsTr("Unhealthy Pods")
        font.weight: Font.Medium
        font.pointSize: Tokens.font.body.small.pointSize
        color: Colours.palette.m3error
    }

    Repeater {
        id: unhealthyPods

        model: Kubernetes.allPods.filter(p => !["Running", "Succeeded", "Completed"].includes(p.status)).slice(0, 5)

        RowLayout {
            id: podRow

            required property var modelData
            required property int index

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            opacity: 0
            scale: 0.9

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }

            MaterialIcon {
                text: "warning"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3error
            }

            StyledText {
                Layout.fillWidth: true
                text: podRow.modelData.name
                font.family: Tokens.font.mono.small.family
                font.pointSize: Tokens.font.body.small.pointSize
                elide: Text.ElideMiddle
            }

            StyledText {
                text: podRow.modelData.status
                font.pointSize: Tokens.font.body.small.pointSize
                color: Colours.palette.m3error
            }
        }
    }

    // All healthy message
    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small
        visible: Kubernetes.available && Kubernetes.failedPods === 0 && Kubernetes.pendingPods === 0 && Kubernetes.totalPods > 0
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: "check_circle"
            color: Colours.palette.m3primary
        }

        StyledText {
            text: qsTr("All %1 pods healthy").arg(Kubernetes.totalPods)
            color: Colours.palette.m3primary
        }
    }

    // Loading indicator
    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small
        visible: Kubernetes.loading
        spacing: Tokens.spacing.small

        CircularIndicator {
            implicitSize: Tokens.font.body.medium.pointSize
            running: Kubernetes.loading
        }

        StyledText {
            text: qsTr("Refreshing...")
            font.pointSize: Tokens.font.body.small.pointSize
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // StatBox component
    component StatBox: StyledRect {
        id: statBox

        property string icon
        property int value
        property string label
        property color boxColor: Colours.palette.m3primary

        implicitHeight: statCol.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.medium
        color: Qt.alpha(boxColor, 0.1)

        ColumnLayout {
            id: statCol

            anchors.centerIn: parent
            spacing: 2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: statBox.icon
                    fontStyle: Tokens.font.icon.medium
                    color: statBox.boxColor
                }

                StyledText {
                    text: statBox.value
                    font.pointSize: Tokens.font.body.large.pointSize
                    font.weight: Font.Bold
                    color: statBox.boxColor
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: statBox.label
                font.pointSize: Tokens.font.body.small.pointSize
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
