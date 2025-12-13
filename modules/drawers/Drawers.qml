pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import qs.modules.bar
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData
        readonly property bool screenFullyExcluded: {
            const regexChecker = /^\^.*\$$/;
            for (const filter of Config.bar.excludedScreens) {
                // Only object format supports full exclusion
                if (typeof filter !== 'object' || !filter.excludeAll)
                    continue;

                const screenPattern = filter.screen;

                // If filter is a regex
                if (regexChecker.test(screenPattern)) {
                    if ((new RegExp(screenPattern)).test(modelData.name))
                        return true;
                } else {
                    if (screenPattern === modelData.name)
                        return true;
                }
            }
            return false;
        }

        readonly property bool barDisabled: {
            const regexChecker = /^\^.*\$$/;
            for (const filter of Config.bar.excludedScreens) {
                // Support both string (backward compatibility) and object format
                const screenPattern = typeof filter === 'string' ? filter : filter.screen;
                const outlineOnly = typeof filter === 'object' && filter.outlineOnly === true;
                const excludeAll = typeof filter === 'object' && filter.excludeAll === true;

                // Skip if only showing outline (not full bar exclusion)
                if (outlineOnly)
                    continue;

                // Skip if excluding everything (handled separately)
                if (excludeAll)
                    continue;

                // If filter is a regex
                if (regexChecker.test(screenPattern)) {
                    if ((new RegExp(screenPattern)).test(modelData.name))
                        return true;
                } else {
                    if (screenPattern === modelData.name)
                        return true;
                }
            }
            return false;
        }

        readonly property bool barOutlineOnly: {
            const regexChecker = /^\^.*\$$/;
            for (const filter of Config.bar.excludedScreens) {
                // Only object format supports outline-only mode
                if (typeof filter !== 'object' || !filter.outlineOnly)
                    continue;

                const screenPattern = filter.screen;

                // If filter is a regex
                if (regexChecker.test(screenPattern)) {
                    if ((new RegExp(screenPattern)).test(modelData.name))
                        return true;
                } else {
                    if (screenPattern === modelData.name)
                        return true;
                }
            }
            return false;
        }

        Loader {
            active: !scope.screenFullyExcluded && !scope.barDisabled
            sourceComponent: Exclusions {
                screen: scope.modelData
                bar: bar
            }
        }

        StyledWindow {
            id: win
            visible: !scope.screenFullyExcluded

            readonly property bool hasFullscreen: Hypr.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen === 2) ?? false
            readonly property int dragMaskPadding: {
                if (focusGrab.active || panels.popouts.isDetached)
                    return 0;

                const mon = Hypr.monitorFor(screen);
                if (mon?.lastIpcObject.specialWorkspace.name || mon?.activeWorkspace?.lastIpcObject.windows > 0)
                    return 0;

                const thresholds = [];
                for (const panel of ["dashboard", "launcher", "session", "sidebar"])
                    if (Config[panel].enabled)
                        thresholds.push(Config[panel].dragThreshold);
                return Math.max(...thresholds);
            }

            onHasFullscreenChanged: {
                visibilities.launcher = false;
                visibilities.session = false;
                visibilities.dashboard = false;
            }

            screen: scope.modelData
            name: "drawers"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Region {
                x: bar.implicitWidth + win.dragMaskPadding
                y: Config.border.thickness + win.dragMaskPadding
                width: win.width - bar.implicitWidth - Config.border.thickness - win.dragMaskPadding * 2
                height: win.height - Config.border.thickness * 2 - win.dragMaskPadding * 2
                intersection: Intersection.Xor

                regions: regions.instances
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Variants {
                id: regions

                model: panels.children

                Region {
                    required property Item modelData

                    x: modelData.x + bar.implicitWidth
                    y: modelData.y + Config.border.thickness
                    width: modelData.width
                    height: modelData.height
                    intersection: Intersection.Subtract
                }
            }

            HyprlandFocusGrab {
                id: focusGrab

                active: (visibilities.launcher && Config.launcher.enabled) || (visibilities.session && Config.session.enabled) || (visibilities.sidebar && Config.sidebar.enabled) || (!Config.dashboard.showOnHover && visibilities.dashboard && Config.dashboard.enabled) || (panels.popouts.currentName.startsWith("traymenu") && panels.popouts.current?.depth > 1)
                windows: [win]
                onCleared: {
                    visibilities.launcher = false;
                    visibilities.session = false;
                    visibilities.sidebar = false;
                    visibilities.dashboard = false;
                    panels.popouts.hasCurrent = false;
                    bar.closeTray();
                }
            }

            StyledRect {
                anchors.fill: parent
                opacity: visibilities.session && Config.session.enabled ? 0.5 : 0
                color: Colours.palette.m3scrim

                Behavior on opacity {
                    Anim {}
                }
            }

            Item {
                anchors.fill: parent
                opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
                }

                Border {
                    bar: bar
                    visible: !scope.barDisabled || scope.barOutlineOnly
                }

                Backgrounds {
                    panels: panels
                    bar: bar
                }
            }

            PersistentProperties {
                id: visibilities

                property bool bar
                property bool osd
                property bool session
                property bool launcher
                property bool dashboard
                property bool utilities
                property bool sidebar

                Component.onCompleted: Visibilities.load(scope.modelData, this)
            }

            Interactions {
                screen: scope.modelData
                popouts: panels.popouts
                visibilities: visibilities
                panels: panels
                bar: bar

                Panels {
                    id: panels

                    screen: scope.modelData
                    visibilities: visibilities
                    bar: bar
                }

                BarWrapper {
                    id: bar

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    screen: scope.modelData
                    visibilities: visibilities
                    popouts: panels.popouts

                    disabled: scope.barDisabled || scope.barOutlineOnly

                    Component.onCompleted: Visibilities.bars.set(scope.modelData, this)
                }
            }
        }
    }
}
