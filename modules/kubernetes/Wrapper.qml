pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

// Dummy wrapper for compatibility - actual UI is in floating window
Item {
    id: root

    required property ScreenState screenState

    readonly property bool needsKeyboard: false
    readonly property real nonAnimHeight: 0
    readonly property bool shouldBeActive: false

    property real offsetScale: 1

    visible: false
    implicitHeight: 0
    implicitWidth: 0

    // When visibility is requested, open the floating window instead
    Connections {
        target: screenState
        function onKubernetesChanged(): void {
            if (screenState.kubernetes && Config.kubernetes.enabled) {
                WindowFactory.open();
                // Immediately reset the panel visibility
                screenState.kubernetes = false;
            }
        }
    }
}
