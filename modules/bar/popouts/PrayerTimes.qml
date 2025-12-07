pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Column {
    id: root

    spacing: Appearance.spacing.normal
    width: Config.bar.sizes.prayerTimesWidth

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTr("Prayer Times")
        font.weight: 600
        font.pixelSize: Appearance.font.size.normal
    }

    Repeater {
        model: PrayerTimes.prayerNames

        delegate: StyledRect {
            id: prayerItem

            required property int index
            required property string modelData

            readonly property bool isNext: index === PrayerTimes.nextPrayerIndex
            readonly property string prayerTime: PrayerTimes.prayerTimes[modelData] || "--:--"

            width: parent.width
            implicitHeight: prayerRow.implicitHeight + Appearance.padding.normal * 2

            color: isNext ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh
            radius: Appearance.rounding.normal

            RowLayout {
                id: prayerRow

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: PrayerTimes.getPrayerIcon(prayerItem.modelData)
                    color: prayerItem.isNext ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    font.pointSize: Appearance.font.size.large
                }

                StyledText {
                    Layout.fillWidth: true
                    text: PrayerTimes.prayerDisplayNames[prayerItem.modelData]
                    color: prayerItem.isNext ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    font.weight: prayerItem.isNext ? 600 : 400
                }

                StyledText {
                    text: prayerItem.prayerTime
                    color: prayerItem.isNext ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    font.family: Appearance.font.family.mono
                    font.weight: prayerItem.isNext ? 600 : 400
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }

    // Message d'erreur si nécessaire
    StyledRect {
        visible: PrayerTimes.errorMessage.length > 0
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
                text: PrayerTimes.errorMessage
                color: Colours.palette.m3onErrorContainer
                wrapMode: Text.WordWrap
            }
        }
    }

    // Bouton de rafraîchissement
    StyledRect {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: refreshContent.implicitWidth + Appearance.padding.large * 2
        implicitHeight: refreshContent.implicitHeight + Appearance.padding.normal * 2

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        StateLayer {
            radius: Appearance.rounding.full

            function onClicked(): void {
                PrayerTimes.refresh();
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
                    running: PrayerTimes.isLoading
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
}
