pragma Singleton

import QtQuick
import Quickshell
import qs.components
import qs.services

Singleton {
    id: root

    property var activeWindow: null

    function open(): void {
        if (activeWindow) {
            activeWindow.requestActivate();
            return;
        }
        activeWindow = kubernetesWindow.createObject(null);
    }

    function close(): void {
        if (activeWindow) {
            activeWindow.visible = false;
        }
    }

    function toggle(): void {
        if (activeWindow)
            close();
        else
            open();
    }

    Component {
        id: kubernetesWindow

        FloatingWindow {
            id: win

            color: Colours.tPalette.m3surface

            onVisibleChanged: {
                if (!visible) {
                    root.activeWindow = null;
                    destroy();
                }
            }

            implicitWidth: 900
            implicitHeight: 600

            minimumSize.width: 700
            minimumSize.height: 400
            
            title: qsTr("Kubernetes - %1").arg(content.currentContext || "cluster")

            KubernetesContent {
                id: content
                anchors.fill: parent
                floating: true
                onClose: win.visible = false
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
