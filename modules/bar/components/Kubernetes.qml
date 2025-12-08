pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    property color colour: Colours.palette.m3secondary

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full
    clip: true

    implicitWidth: Config.bar.sizes.innerWidth
    implicitHeight: Config.bar.sizes.innerWidth

    MaterialIcon {
        id: k8sIcon

        anchors.centerIn: parent
        text: "workspaces"  // Icône représentant des clusters/workspaces
        color: {
            if (!Kubernetes.isConnected) return Colours.palette.m3error;
            switch (Kubernetes.statusClass) {
                case "critical": return Colours.palette.m3error;
                case "warning": return Qt.rgba(1.0, 0.6, 0.0, 1.0);
                default: return root.colour;
            }
        }
        font.pointSize: Appearance.font.size.large
        animate: true
    }

    // Indicateur de chargement
    MaterialIcon {
        anchors.centerIn: parent
        visible: Kubernetes.isLoading
        text: "progress_activity"
        color: root.colour

        RotationAnimator on rotation {
            running: Kubernetes.isLoading
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }
}
