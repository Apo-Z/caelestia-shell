pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Item {
            id: behindWidgets

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled

                sourceComponent: Wallpaper {}
            }

            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
            }
        }

        // Widget container that handles positioning and stacking
        Item {
            id: widgetArea

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLargeIncreased
            anchors.leftMargin: Tokens.padding.extraLargeIncreased + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness)

            readonly property string clockPos: Config.background.desktopClock.position
            readonly property string prayerPos: Config.background.desktopPrayer.position
            readonly property bool clockEnabled: Config.background.desktopClock.enabled
            readonly property bool prayerEnabled: Config.background.desktopPrayer.enabled

            // Container for each position - widgets stack vertically when sharing position
            component WidgetContainer: ColumnLayout {
                id: container

                required property string position

                readonly property bool hasClock: widgetArea.clockEnabled && widgetArea.clockPos === position
                readonly property bool hasPrayer: widgetArea.prayerEnabled && widgetArea.prayerPos === position
                readonly property bool hasWidgets: hasClock || hasPrayer

                visible: hasWidgets
                spacing: Tokens.spacing.large

                // Clock widget
                Loader {
                    id: clockLoader

                    Layout.alignment: {
                        if (container.position.endsWith("left")) return Qt.AlignLeft;
                        if (container.position.endsWith("right")) return Qt.AlignRight;
                        return Qt.AlignHCenter;
                    }

                    asynchronous: true
                    active: container.hasClock

                    sourceComponent: DesktopClock {
                        id: clockWidget

                        wallpaper: behindWidgets

                        readonly property point mapped: clockLoader.mapToItem(behindWidgets, 0, 0)
                        absX: mapped.x
                        absY: mapped.y
                    }
                }

                // Prayer widget
                Loader {
                    id: prayerLoader

                    Layout.alignment: {
                        if (container.position.endsWith("left")) return Qt.AlignLeft;
                        if (container.position.endsWith("right")) return Qt.AlignRight;
                        return Qt.AlignHCenter;
                    }

                    asynchronous: true
                    active: container.hasPrayer

                    sourceComponent: DesktopPrayer {
                        id: prayerWidget

                        wallpaper: behindWidgets

                        readonly property point mapped: prayerLoader.mapToItem(behindWidgets, 0, 0)
                        absX: mapped.x
                        absY: mapped.y
                    }
                }
            }

            // Top-left
            WidgetContainer {
                position: "top-left"
                anchors.top: parent.top
                anchors.left: parent.left
            }

            // Top-center
            WidgetContainer {
                position: "top-center"
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Top-right
            WidgetContainer {
                position: "top-right"
                anchors.top: parent.top
                anchors.right: parent.right
            }

            // Middle-left
            WidgetContainer {
                position: "middle-left"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
            }

            // Middle-center
            WidgetContainer {
                position: "middle-center"
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Middle-right
            WidgetContainer {
                position: "middle-right"
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
            }

            // Bottom-left
            WidgetContainer {
                position: "bottom-left"
                anchors.bottom: parent.bottom
                anchors.left: parent.left
            }

            // Bottom-center
            WidgetContainer {
                position: "bottom-center"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Bottom-right
            WidgetContainer {
                position: "bottom-right"
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }
        }
    }
}
