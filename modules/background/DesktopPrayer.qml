pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real prayerScale: Config.background.desktopPrayer.scale
    readonly property bool bgEnabled: Config.background.desktopPrayer.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopPrayer.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopPrayer.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary

    implicitWidth: layout.implicitWidth + (Tokens.padding.large * 4 * root.prayerScale)
    implicitHeight: layout.implicitHeight + (Tokens.padding.large * 2 * root.prayerScale)

    Item {
        id: prayerContainer

        anchors.fill: parent

        layer.enabled: Config.background.desktopPrayer.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopPrayer.shadow.opacity
            shadowBlur: Config.background.desktopPrayer.shadow.blur
        }

        Loader {
            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.large * root.prayerScale
            opacity: Config.background.desktopPrayer.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Tokens.spacing.medium * root.prayerScale

            // Next prayer - large display
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.small * root.prayerScale

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Prayer.nextName || qsTr("Loading...")
                    font.pointSize: Tokens.font.body.large.pointSize * root.prayerScale
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    color: root.safeSecondary
                    opacity: 0.9
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Prayer.nextTime || "--:--"
                    font.pointSize: Tokens.font.headline.medium.pointSize * 2.5 * root.prayerScale
                    font.weight: Font.Bold
                    color: root.safePrimary
                }
            }

            // Divider
            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: prayerTimesRow.implicitWidth * 0.8
                Layout.preferredHeight: 2 * root.prayerScale
                radius: Tokens.rounding.full
                color: root.safePrimary
                opacity: 0.3
            }

            // All prayers row - compact display
            RowLayout {
                id: prayerTimesRow

                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.large * root.prayerScale

                Repeater {
                    model: Prayer.prayers

                    delegate: ColumnLayout {
                        id: prayerDelegate

                        required property var modelData
                        required property int index

                        readonly property bool isNext: index === Prayer.nextIndex
                        readonly property bool isSunrise: modelData.id === "chourouk"

                        spacing: Tokens.spacing.extraSmall * root.prayerScale
                        opacity: isNext ? 1 : (isSunrise ? 0.5 : 0.7)

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: prayerDelegate.modelData.name
                            font.pointSize: Tokens.font.body.small.pointSize * root.prayerScale
                            font.weight: prayerDelegate.isNext ? Font.Bold : Font.Normal
                            font.letterSpacing: 1
                            color: prayerDelegate.isNext ? root.safePrimary : root.safeSecondary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: prayerDelegate.modelData.time
                            font.pointSize: Tokens.font.body.medium.pointSize * root.prayerScale
                            font.weight: prayerDelegate.isNext ? Font.Bold : Font.Medium
                            color: prayerDelegate.isNext ? root.safePrimary : root.safeTertiary
                        }
                    }
                }
            }

            // Error display
            Loader {
                Layout.alignment: Qt.AlignHCenter
                active: Prayer.error !== ""
                visible: active

                sourceComponent: StyledText {
                    text: Prayer.error
                    font.pointSize: Tokens.font.body.small.pointSize * root.prayerScale
                    color: Colours.palette.m3error
                    opacity: 0.8
                }
            }
        }
    }

    Behavior on prayerScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
