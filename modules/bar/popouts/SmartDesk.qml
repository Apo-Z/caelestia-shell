pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Column {
    id: root

    spacing: Appearance.spacing.normal
    width: Config.bar.sizes.smartDeskWidth

    // Header
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTr("Smart Desk")
        font.weight: 600
        font.pixelSize: Appearance.font.size.normal
    }

    // Status actuel
    StyledRect {
        width: parent.width
        implicitHeight: statusContent.implicitHeight + Appearance.padding.normal * 2

        color: {
            if (SmartDesk.isCalibrating) return Colours.palette.m3tertiaryContainer;
            if (SmartDesk.isMoving) return Colours.palette.m3primaryContainer;
            return Colours.tPalette.m3surfaceContainerHigh;
        }
        radius: Appearance.rounding.normal

        Column {
            id: statusContent

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            RowLayout {
                width: parent.width
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: SmartDesk.statusIcon
                    color: {
                        if (SmartDesk.isCalibrating) return Colours.palette.m3onTertiaryContainer;
                        if (SmartDesk.isMoving) return Colours.palette.m3onPrimaryContainer;
                        return Colours.palette.m3onSurface;
                    }
                    font.pointSize: Appearance.font.size.large

                    RotationAnimator on rotation {
                        running: SmartDesk.isCalibrating
                        from: 0
                        to: 360
                        duration: 2000
                        loops: Animation.Infinite
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: SmartDesk.statusText
                        color: {
                            if (SmartDesk.isCalibrating) return Colours.palette.m3onTertiaryContainer;
                            if (SmartDesk.isMoving) return Colours.palette.m3onPrimaryContainer;
                            return Colours.palette.m3onSurface;
                        }
                        font.weight: 600
                    }

                    StyledText {
                        visible: SmartDesk.currentPosition > 0
                        text: qsTr("Position: %1mm").arg(SmartDesk.currentPosition)
                        color: {
                            if (SmartDesk.isCalibrating) return Colours.palette.m3onTertiaryContainer;
                            if (SmartDesk.isMoving) return Colours.palette.m3onPrimaryContainer;
                            return Colours.palette.m3onSurface;
                        }
                        font.pixelSize: Appearance.font.size.small
                    }

                    StyledText {
                        visible: SmartDesk.isMoving && SmartDesk.targetPosition > 0
                        text: qsTr("Target: %1mm").arg(SmartDesk.targetPosition)
                        color: {
                            if (SmartDesk.isMoving) return Colours.palette.m3onPrimaryContainer;
                            return Colours.palette.m3onSurface;
                        }
                        font.pixelSize: Appearance.font.size.smaller
                        opacity: 0.8
                    }
                }
            }

            // Mode proche si applicable
            StyledText {
                visible: SmartDesk.getClosestMode() !== null
                text: {
                    const mode = SmartDesk.getClosestMode();
                    return mode ? qsTr("Near: %1 (%2mm)").arg(mode.name).arg(mode.position) : "";
                }
                color: {
                    if (SmartDesk.isCalibrating) return Colours.palette.m3onTertiaryContainer;
                    if (SmartDesk.isMoving) return Colours.palette.m3onPrimaryContainer;
                    return Colours.palette.m3onSurface;
                }
                font.pixelSize: Appearance.font.size.smaller
                opacity: 0.7
            }
        }

        Behavior on color {
            CAnim {}
        }
    }

    // Contrôles manuels
    StyledText {
        text: qsTr("Manual Controls")
        font.weight: 600
        font.pixelSize: Appearance.font.size.small
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Appearance.spacing.normal

        ControlButton {
            icon: "arrow_upward"
            text: qsTr("Up")
            onClicked: SmartDesk.moveUp()
        }

        ControlButton {
            icon: "stop"
            text: qsTr("Stop")
            onClicked: SmartDesk.stop()
            dangerous: SmartDesk.isMoving
        }

        ControlButton {
            icon: "arrow_downward"
            text: qsTr("Down")
            onClicked: SmartDesk.moveDown()
        }
    }

    // Positions enregistrées
    StyledText {
        text: qsTr("Saved Positions")
        font.weight: 600
        font.pixelSize: Appearance.font.size.small
    }

    // Message si pas de modes
    StyledRect {
        visible: SmartDesk.modes.length === 0 && !SmartDesk.isLoading
        width: parent.width
        implicitHeight: noModesText.implicitHeight + Appearance.padding.normal * 2

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.normal

        StyledText {
            id: noModesText
            anchors.centerIn: parent
            text: qsTr("No saved positions")
            opacity: 0.6
        }
    }

    // Liste des modes (dynamique)
    Repeater {
        model: SmartDesk.modes

        delegate: StyledRect {
            required property var modelData
            required property int index

            readonly property bool isCurrent: SmartDesk.currentPosition > 0 &&
                                             Math.abs(modelData.position - SmartDesk.currentPosition) <= 5
            readonly property bool isTarget: SmartDesk.isMoving && SmartDesk.targetPosition === modelData.position

            width: parent.width
            implicitHeight: modeRow.implicitHeight + Appearance.padding.normal * 2

            color: {
                if (isTarget) return Colours.palette.m3primaryContainer;
                if (isCurrent) return Colours.palette.m3tertiaryContainer;
                return Colours.tPalette.m3surfaceContainer;
            }
            radius: Appearance.rounding.normal

            StateLayer {
                radius: Appearance.rounding.normal

                function onClicked(): void {
                    SmartDesk.moveTo(modelData.name);
                }
            }

            RowLayout {
                id: modeRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: {
                        if (isTarget) return "play_arrow";
                        if (isCurrent) return "check_circle";
                        return "bookmark";
                    }
                    color: {
                        if (isTarget) return Colours.palette.m3onPrimaryContainer;
                        if (isCurrent) return Colours.palette.m3onTertiaryContainer;
                        return Colours.palette.m3secondary;
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: modelData.name
                        color: {
                            if (isTarget) return Colours.palette.m3onPrimaryContainer;
                            if (isCurrent) return Colours.palette.m3onTertiaryContainer;
                            return Colours.palette.m3onSurface;
                        }
                        font.weight: isCurrent || isTarget ? 600 : 400
                    }

                    StyledText {
                        visible: modelData.position > 0
                        text: `${modelData.position}mm`
                        color: {
                            if (isTarget) return Colours.palette.m3onPrimaryContainer;
                            if (isCurrent) return Colours.palette.m3onTertiaryContainer;
                            return Colours.palette.m3onSurface;
                        }
                        font.family: Appearance.font.family.mono
                        font.pixelSize: Appearance.font.size.smaller
                        opacity: 0.7
                    }
                }

                MaterialIcon {
                    text: "chevron_right"
                    color: {
                        if (isTarget) return Colours.palette.m3onPrimaryContainer;
                        if (isCurrent) return Colours.palette.m3onTertiaryContainer;
                        return Colours.palette.m3onSurface;
                    }
                    opacity: 0.5
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }

    // Indicateur de chargement
    StyledRect {
        visible: SmartDesk.isLoading
        width: parent.width
        implicitHeight: loadingRow.implicitHeight + Appearance.padding.normal * 2

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.normal

        RowLayout {
            id: loadingRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "progress_activity"
                color: Colours.palette.m3primary

                RotationAnimator on rotation {
                    running: SmartDesk.isLoading
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            StyledText {
                text: qsTr("Loading positions...")
                color: Colours.palette.m3primary
            }
        }
    }

    // Bouton refresh
    StyledRect {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: refreshContent.implicitWidth + Appearance.padding.large * 2
        implicitHeight: refreshContent.implicitHeight + Appearance.padding.normal * 2

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        StateLayer {
            radius: Appearance.rounding.full

            function onClicked(): void {
                SmartDesk.refresh();
            }
        }

        RowLayout {
            id: refreshContent

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "refresh"
                color: Colours.palette.m3primary

                RotationAnimator on rotation {
                    running: SmartDesk.isLoading
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            StyledText {
                text: qsTr("Refresh")
                color: Colours.palette.m3primary
            }
        }
    }

    // Message d'erreur
    StyledRect {
        visible: SmartDesk.errorMessage.length > 0
        width: parent.width
        implicitHeight: errorText.implicitHeight + Appearance.padding.normal * 2

        color: Colours.palette.m3errorContainer
        radius: Appearance.rounding.normal

        RowLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "warning"
                color: Colours.palette.m3onErrorContainer
            }

            StyledText {
                id: errorText
                Layout.fillWidth: true
                text: SmartDesk.errorMessage
                color: Colours.palette.m3onErrorContainer
                wrapMode: Text.WordWrap
            }
        }
    }

    component ControlButton: StyledRect {
        property string icon
        property string text
        property bool dangerous: false
        signal clicked()

        implicitWidth: btnContent.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: btnContent.implicitHeight + Appearance.padding.normal * 2

        color: dangerous ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.normal

        StateLayer {
            radius: Appearance.rounding.normal

            function onClicked(): void {
                parent.clicked();
            }
        }

        Column {
            id: btnContent

            anchors.centerIn: parent
            spacing: Appearance.spacing.smaller

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.icon
                color: dangerous ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.text
                color: dangerous ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
                font.pixelSize: Appearance.font.size.smaller
            }
        }
    }
}
