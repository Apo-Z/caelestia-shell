pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QMLTermWidget
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

Item {
    id: root

    // For floating window mode
    property bool floating: false
    signal close
    
    // State (internal when floating, or passed in)
    readonly property KubernetesState kubeState: KubernetesState {}
    readonly property string currentContext: Kubernetes.currentContext

    readonly property bool needsKeyboard: true
    readonly property real nonAnimHeight: mainColumn.implicitHeight

    // Current resource list based on tab
    readonly property var currentResources: {
        switch (kubeState.currentTab) {
        case 0:
            return Kubernetes.pods;
        case 1:
            return Kubernetes.nodes;
        case 2:
            return Kubernetes.deployments;
        case 3:
            return Kubernetes.services;
        default:
            return [];
        }
    }

    // Filtered resources based on search
    readonly property var filteredResources: {
        if (!kubeState.searchQuery)
            return currentResources;
        const query = kubeState.searchQuery.toLowerCase();
        return currentResources.filter(r => r.name.toLowerCase().includes(query) ||
                                            (r.namespace && r.namespace.toLowerCase().includes(query)));
    }

    readonly property var selectedResource: {
        if (kubeState.selectedIndex < 0 || kubeState.selectedIndex >= filteredResources.length)
            return null;
        return filteredResources[kubeState.selectedIndex];
    }

    readonly property var tabLabels: [
        { icon: "deployed_code", label: qsTr("Pods") },
        { icon: "dns", label: qsTr("Nodes") },
        { icon: "rocket_launch", label: qsTr("Deployments") },
        { icon: "lan", label: qsTr("Services") }
    ]

    // Namespace list with "All" as first option
    readonly property var namespaceList: {
        let list = [{ name: "__all__", display: qsTr("All namespaces") }];
        for (const ns of Kubernetes.namespaces) {
            list.push({ name: ns, display: ns });
        }
        return list;
    }

    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight

    // Focus handler - invisible item that captures keyboard
    Item {
        id: keyHandler
        focus: true
        
        Keys.onPressed: event => root.handleKey(event)
        
        Component.onCompleted: forceActiveFocus()
    }

    Ref {
        service: Kubernetes
    }

    // Reset timeout
    Timer {
        id: resetTimer
        interval: 5 * 60 * 1000
        onTriggered: {
            kubeState.currentView = "list";
            kubeState.outputContent = "";
        }
    }

    function resetInactivityTimer(): void {
        resetTimer.restart();
    }

    // Actions
    function showLogs(): void {
        if (!selectedResource) return;
        kubeState.currentView = "output";
        kubeState.outputTitle = qsTr("Logs: %1").arg(selectedResource.name);
        kubeState.outputContent = qsTr("Loading logs...");
        logsProcess.command = ["kubectl", "logs", "-n", selectedResource.namespace, selectedResource.name, "--tail=500"];
        logsProcess.running = true;
    }

    function showDescribe(): void {
        if (!selectedResource) return;
        kubeState.currentView = "output";
        const resourceType = ["pod", "node", "deployment", "service"][kubeState.currentTab];
        kubeState.outputTitle = qsTr("Describe: %1").arg(selectedResource.name);
        kubeState.outputContent = qsTr("Loading...");
        describeProcess.command = ["kubectl", "describe", resourceType, "-n", selectedResource.namespace || "default", selectedResource.name];
        describeProcess.running = true;
    }

    function execShell(): void {
        if (!selectedResource || kubeState.currentTab !== 0) return;
        
        const container = selectedResource.containers?.[0] || "";
        const ns = selectedResource.namespace || "default";
        const pod = selectedResource.name;
        
        // Store shell info and switch to shell view
        kubeState.shellPod = pod;
        kubeState.shellNamespace = ns;
        kubeState.shellContainer = container;
        kubeState.currentView = "shell";
    }

    function deleteResource(): void {
        if (!selectedResource) return;
        const resourceType = kubeState.currentTab === 0 ? "pod" : "deployment";
        Kubernetes.deleteResource(resourceType, selectedResource.namespace, selectedResource.name, result => {
            if (result.success)
                Kubernetes.refresh();
        });
    }

    function openNamespaceSelector(): void {
        kubeState.currentView = "namespace";
        const currentNs = Kubernetes.currentNamespace;
        const idx = namespaceList.findIndex(ns => ns.name === currentNs);
        kubeState.nsSelectedIndex = idx >= 0 ? idx : 0;
    }

    function selectNamespace(nsName: string): void {
        Kubernetes.setNamespace(nsName);
        kubeState.currentView = "list";
        kubeState.selectedIndex = 0;
        keyHandler.forceActiveFocus();
    }

    function showHelp(): void {
        kubeState.currentView = "output";
        kubeState.outputTitle = qsTr("Help");
        kubeState.outputContent = `Navigation
  j/↓      Down
  k/↑      Up  
  g        First
  G        Last
  /        Search (type then Enter)
  Esc      Back/Close/Clear search
  1-4      Switch tabs

Actions (on selected resource)
  Enter    Logs (pods) / Describe
  l        Logs
  d        Describe  
  s        Shell (pods)
  x        Delete
  r        Refresh
  y        Copy name

General
  n        Change namespace
  ?        This help
  q        Close panel`;
    }

    // Keyboard handler
    function handleKey(event: KeyEvent): void {
        resetInactivityTimer();

        // Shell mode - let terminal handle keys
        if (kubeState.currentView === "shell") {
            // Don't intercept keys, let QMLTermWidget handle them
            return;
        }

        // Search mode
        if (kubeState.searchMode) {
            if (event.key === Qt.Key_Escape) {
                kubeState.searchMode = false;
                kubeState.searchQuery = "";
                event.accepted = true;
            } else if (event.key === Qt.Key_Return) {
                kubeState.searchMode = false;
                if (filteredResources.length > 0 && kubeState.selectedIndex < 0)
                    kubeState.selectedIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace) {
                kubeState.searchQuery = kubeState.searchQuery.slice(0, -1);
                event.accepted = true;
            } else if (event.text && event.text.length === 1 && !event.modifiers) {
                kubeState.searchQuery += event.text;
                event.accepted = true;
            }
            return;
        }

        // Namespace view
        if (kubeState.currentView === "namespace") {
            switch (event.key) {
            case Qt.Key_J:
            case Qt.Key_Down:
                if (kubeState.nsSelectedIndex < namespaceList.length - 1)
                    kubeState.nsSelectedIndex++;
                event.accepted = true;
                break;
            case Qt.Key_K:
            case Qt.Key_Up:
                if (kubeState.nsSelectedIndex > 0)
                    kubeState.nsSelectedIndex--;
                event.accepted = true;
                break;
            case Qt.Key_G:
                if (event.modifiers & Qt.ShiftModifier)
                    kubeState.nsSelectedIndex = namespaceList.length - 1;
                else
                    kubeState.nsSelectedIndex = 0;
                event.accepted = true;
                break;
            case Qt.Key_Return:
                const ns = namespaceList[kubeState.nsSelectedIndex];
                if (ns)
                    selectNamespace(ns.name);
                event.accepted = true;
                break;
            case Qt.Key_Escape:
            case Qt.Key_Q:
            case Qt.Key_N:
                kubeState.currentView = "list";
                event.accepted = true;
                break;
            }
            return;
        }

        // Output view
        if (kubeState.currentView === "output") {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                kubeState.currentView = "list";
                event.accepted = true;
            } else if (event.key === Qt.Key_Y) {
                Quickshell.execDetached(["wl-copy", kubeState.outputContent]);
                event.accepted = true;
            }
            return;
        }

        // List view - vim navigation
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            if (kubeState.selectedIndex < filteredResources.length - 1)
                kubeState.selectedIndex++;
            else if (kubeState.selectedIndex === -1 && filteredResources.length > 0)
                kubeState.selectedIndex = 0;
            event.accepted = true;
            break;
        case Qt.Key_K:
        case Qt.Key_Up:
            if (kubeState.selectedIndex > 0)
                kubeState.selectedIndex--;
            event.accepted = true;
            break;
        case Qt.Key_G:
            if (event.modifiers & Qt.ShiftModifier)
                kubeState.selectedIndex = filteredResources.length - 1;
            else
                kubeState.selectedIndex = 0;
            event.accepted = true;
            break;
        case Qt.Key_Slash:
            kubeState.searchMode = true;
            event.accepted = true;
            break;
        case Qt.Key_Return:
            if (selectedResource) {
                if (kubeState.currentTab === 0)
                    showLogs();
                else
                    showDescribe();
            }
            event.accepted = true;
            break;
        case Qt.Key_L:
            if (selectedResource && kubeState.currentTab === 0)
                showLogs();
            event.accepted = true;
            break;
        case Qt.Key_D:
            if (selectedResource)
                showDescribe();
            event.accepted = true;
            break;
        case Qt.Key_S:
            if (selectedResource && kubeState.currentTab === 0)
                execShell();
            event.accepted = true;
            break;
        case Qt.Key_X:
            if (selectedResource)
                deleteResource();
            event.accepted = true;
            break;
        case Qt.Key_R:
            Kubernetes.refresh();
            event.accepted = true;
            break;
        case Qt.Key_Y:
            if (selectedResource)
                Quickshell.execDetached(["wl-copy", selectedResource.name]);
            event.accepted = true;
            break;
        case Qt.Key_N:
            openNamespaceSelector();
            event.accepted = true;
            break;
        case Qt.Key_Question:
            showHelp();
            event.accepted = true;
            break;
        case Qt.Key_Escape:
            if (kubeState.searchQuery) {
                kubeState.searchQuery = "";
            } else {
                root.close();
            }
            event.accepted = true;
            break;
        case Qt.Key_Q:
            root.close();
            event.accepted = true;
            break;
        case Qt.Key_1:
        case Qt.Key_2:
        case Qt.Key_3:
        case Qt.Key_4:
            kubeState.currentTab = event.key - Qt.Key_1;
            kubeState.selectedIndex = filteredResources.length > 0 ? 0 : -1;
            kubeState.currentView = "list";
            event.accepted = true;
            break;
        }
    }

    // Processes
    Process {
        id: logsProcess
        stdout: StdioCollector {
            onStreamFinished: kubeState.outputContent = text || qsTr("No logs")
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    kubeState.outputContent = qsTr("Error: ") + text.trim();
            }
        }
    }

    Process {
        id: describeProcess
        stdout: StdioCollector {
            onStreamFinished: kubeState.outputContent = text || qsTr("No data")
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    kubeState.outputContent = qsTr("Error: ") + text.trim();
            }
        }
    }

    // Main layout
    ColumnLayout {
        id: mainColumn
        spacing: 0

        // Header
        StyledRect {
            Layout.fillWidth: true
            implicitWidth: 850
            implicitHeight: headerRow.implicitHeight + Tokens.padding.medium * 2
            color: Colours.palette.m3surfaceContainerHigh
            radius: Tokens.rounding.medium

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "cloud"
                    color: {
                        switch (Kubernetes.clusterHealth) {
                        case "healthy": return Colours.palette.m3primary;
                        case "warning": return Colours.palette.m3tertiary;
                        case "error": return Colours.palette.m3error;
                        default: return Colours.palette.m3onSurfaceVariant;
                        }
                    }
                }

                StyledText {
                    text: Kubernetes.currentContext || qsTr("No context")
                    font.weight: Font.Medium
                }

                // Namespace button
                StyledRect {
                    id: nsButton
                    implicitWidth: nsRow.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: nsRow.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3surfaceContainerHighest

                    RowLayout {
                        id: nsRow
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "folder"
                            font.pointSize: Tokens.font.body.small.pointSize
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            text: Kubernetes.currentNamespace === "__all__" ? qsTr("All") : Kubernetes.currentNamespace
                            font.pointSize: Tokens.font.body.small.pointSize
                        }

                        StyledText {
                            text: "n"
                            font.family: Tokens.font.mono.small.family
                            font.pointSize: Tokens.font.body.small.pointSize
                            color: Colours.palette.m3onSurfaceVariant
                            opacity: 0.5
                        }
                    }

                    StateLayer {
                        color: Colours.palette.m3onSurface
                        onClicked: openNamespaceSelector()
                    }
                }

                Item { Layout.fillWidth: true }

                // Search indicator
                StyledRect {
                    visible: kubeState.searchMode || kubeState.searchQuery
                    implicitWidth: searchIndicator.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: searchIndicator.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.small
                    color: kubeState.searchMode ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest

                    RowLayout {
                        id: searchIndicator
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: "/"
                            font.family: Tokens.font.mono.small.family
                            color: kubeState.searchMode ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            text: kubeState.searchQuery || (kubeState.searchMode ? "..." : "")
                            font.family: Tokens.font.mono.small.family
                            color: kubeState.searchMode ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        }
                    }
                }

                // Stats
                StyledText {
                    text: qsTr("%1/%2").arg(Kubernetes.runningPods).arg(Kubernetes.totalPods)
                    font.family: Tokens.font.mono.small.family
                    font.pointSize: Tokens.font.body.small.pointSize
                    color: Colours.palette.m3primary
                }

                StyledText {
                    visible: Kubernetes.failedPods > 0
                    text: Kubernetes.failedPods + " ✗"
                    font.pointSize: Tokens.font.body.small.pointSize
                    color: Colours.palette.m3error
                }
            }
        }

        // Tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.tabLabels

                StyledRect {
                    id: tabBtn
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: tabRow.implicitHeight + Tokens.padding.medium * 2
                    color: kubeState.currentTab === index ? Colours.palette.m3secondaryContainer : "transparent"

                    RowLayout {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: tabBtn.modelData.icon
                            font.pointSize: Tokens.font.body.medium.pointSize
                            color: kubeState.currentTab === tabBtn.index ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fill: kubeState.currentTab === tabBtn.index ? 1 : 0
                        }

                        StyledText {
                            text: tabBtn.modelData.label
                            font.pointSize: Tokens.font.body.small.pointSize
                            color: kubeState.currentTab === tabBtn.index ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            text: tabBtn.index + 1
                            font.family: Tokens.font.mono.small.family
                            font.pointSize: Tokens.font.body.small.pointSize
                            color: Colours.palette.m3onSurfaceVariant
                            opacity: 0.5
                        }
                    }

                    StateLayer {
                        color: Colours.palette.m3onSurface
                        onClicked: {
                            kubeState.currentTab = tabBtn.index;
                            kubeState.selectedIndex = filteredResources.length > 0 ? 0 : -1;
                            kubeState.currentView = "list";
                        }
                    }
                }
            }
        }

        // Content area
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: kubeState.currentView === "list" ? 350 : 450
            color: Colours.palette.m3surfaceContainer
            radius: Tokens.rounding.medium

            Behavior on implicitHeight {
                Anim {}
            }

            // List view
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small
                visible: kubeState.currentView === "list"

                // Header row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.preferredWidth: 220
                        text: qsTr("NAME")
                        font.pointSize: Tokens.font.body.small.pointSize
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.preferredWidth: 100
                        visible: kubeState.currentTab === 0
                        text: qsTr("NAMESPACE")
                        font.pointSize: Tokens.font.body.small.pointSize
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.preferredWidth: 90
                        text: qsTr("STATUS")
                        font.pointSize: Tokens.font.body.small.pointSize
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.preferredWidth: 60
                        visible: kubeState.currentTab === 0
                        text: qsTr("READY")
                        font.pointSize: Tokens.font.body.small.pointSize
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("AGE")
                        font.pointSize: Tokens.font.body.small.pointSize
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colours.palette.m3outlineVariant
                }

                ListView {
                    id: resourceList
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    model: root.filteredResources
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: kubeState.selectedIndex

                    delegate: StyledRect {
                        id: row
                        required property var modelData
                        required property int index

                        width: resourceList.width
                        implicitHeight: rowLayout.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.small
                        color: kubeState.selectedIndex === index ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"

                        RowLayout {
                            id: rowLayout
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            spacing: Tokens.spacing.medium

                            StyledRect {
                                implicitWidth: 3
                                Layout.fillHeight: true
                                radius: 2
                                color: kubeState.selectedIndex === row.index ? Colours.palette.m3primary : "transparent"
                            }

                            StyledText {
                                Layout.preferredWidth: 215
                                text: row.modelData.name
                                font.family: Tokens.font.mono.small.family
                                font.pointSize: Tokens.font.body.small.pointSize
                                color: kubeState.selectedIndex === row.index ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                elide: Text.ElideMiddle
                            }

                            StyledText {
                                Layout.preferredWidth: 100
                                visible: kubeState.currentTab === 0
                                text: row.modelData.namespace || "-"
                                font.family: Tokens.font.mono.small.family
                                font.pointSize: Tokens.font.body.small.pointSize
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.preferredWidth: 90
                                spacing: Tokens.spacing.small

                                StyledRect {
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    radius: 3
                                    color: {
                                        const s = row.modelData.status;
                                        if (s === "Running" || s === "Ready" || s === "Active")
                                            return Colours.palette.m3primary;
                                        if (s === "Pending" || s === "Progressing")
                                            return Colours.palette.m3tertiary;
                                        return Colours.palette.m3error;
                                    }
                                }

                                StyledText {
                                    text: row.modelData.status || "-"
                                    font.pointSize: Tokens.font.body.small.pointSize
                                }
                            }

                            StyledText {
                                Layout.preferredWidth: 60
                                visible: kubeState.currentTab === 0
                                text: row.modelData.ready || "-"
                                font.family: Tokens.font.mono.small.family
                                font.pointSize: Tokens.font.body.small.pointSize
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.age || "-"
                                font.pointSize: Tokens.font.body.small.pointSize
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            onClicked: kubeState.selectedIndex = row.index
                            onDoubleClicked: {
                                kubeState.selectedIndex = row.index;
                                if (kubeState.currentTab === 0)
                                    showLogs();
                                else
                                    showDescribe();
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: filteredResources.length === 0
                        text: kubeState.searchQuery ? qsTr("No results for '%1'").arg(kubeState.searchQuery) : qsTr("No resources")
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: resourceList
                    }
                }

                // Status bar
                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        visible: kubeState.selectedIndex >= 0
                        text: qsTr("%1/%2").arg(kubeState.selectedIndex + 1).arg(filteredResources.length)
                        font.family: Tokens.font.mono.small.family
                        font.pointSize: Tokens.font.body.small.pointSize
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: kubeState.searchMode ? qsTr("Type to search, Enter to confirm") : 
                              Kubernetes.loading ? qsTr("Loading...") : qsTr("j/k:nav  /:search  ?:help")
                        font.pointSize: Tokens.font.body.small.pointSize
                        color: Colours.palette.m3onSurfaceVariant
                        opacity: 0.6
                    }
                }
            }

            // Output view (logs, describe, help)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small
                visible: kubeState.currentView === "output"

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: kubeState.outputTitle.startsWith("Logs") ? "article" : "info"
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: kubeState.outputTitle
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }

                    IconButton {
                        icon: "content_copy"
                        onClicked: Quickshell.execDetached(["wl-copy", kubeState.outputContent])
                    }

                    IconButton {
                        icon: "close"
                        onClicked: kubeState.currentView = "list"
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3surfaceContainerLowest

                    Flickable {
                        id: outputFlick
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        contentWidth: outputText.width
                        contentHeight: outputText.height
                        clip: true

                        TextEdit {
                            id: outputText
                            width: outputFlick.width
                            text: kubeState.outputContent
                            font.family: Tokens.font.mono.small.family
                            font.pointSize: Tokens.font.body.small.pointSize
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                            readOnly: true
                            selectByMouse: true
                        }

                        StyledScrollBar.vertical: StyledScrollBar {
                            flickable: outputFlick
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Esc to close • y to copy")
                    font.pointSize: Tokens.font.body.small.pointSize
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.5
                }
            }

            // Namespace selector
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small
                visible: kubeState.currentView === "namespace"

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "folder"
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Select Namespace")
                        font.weight: Font.Medium
                    }

                    IconButton {
                        icon: "close"
                        onClicked: kubeState.currentView = "list"
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colours.palette.m3outlineVariant
                }

                ListView {
                    id: nsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    model: root.namespaceList
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: kubeState.nsSelectedIndex

                    delegate: StyledRect {
                        id: nsRow
                        required property var modelData
                        required property int index

                        width: nsList.width
                        implicitHeight: nsRowLayout.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.small
                        color: kubeState.nsSelectedIndex === index ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"

                        RowLayout {
                            id: nsRowLayout
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            StyledRect {
                                implicitWidth: 3
                                Layout.fillHeight: true
                                radius: 2
                                color: kubeState.nsSelectedIndex === nsRow.index ? Colours.palette.m3primary : "transparent"
                            }

                            MaterialIcon {
                                text: nsRow.modelData.name === "__all__" ? "select_all" : "folder"
                                color: kubeState.nsSelectedIndex === nsRow.index ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: nsRow.modelData.display
                                color: kubeState.nsSelectedIndex === nsRow.index ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            }

                            MaterialIcon {
                                visible: Kubernetes.currentNamespace === nsRow.modelData.name
                                text: "check"
                                color: Colours.palette.m3primary
                            }
                        }

                        StateLayer {
                            color: Colours.palette.m3onSurface
                            onClicked: selectNamespace(nsRow.modelData.name)
                        }
                    }

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: nsList
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("j/k:nav  Enter:select  Esc:cancel")
                    font.pointSize: Tokens.font.body.small.pointSize
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.5
                }
            }

            // Shell view - integrated terminal
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small
                visible: kubeState.currentView === "shell"

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "terminal"
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Shell: %1").arg(kubeState.shellPod)
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        text: kubeState.shellNamespace
                        font.pointSize: Tokens.font.body.small.pointSize
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    IconButton {
                        icon: "close"
                        onClicked: {
                            if (terminalLoader.item?.session)
                                terminalLoader.item.session.sendSignal(15);
                            kubeState.currentView = "list";
                            keyHandler.forceActiveFocus();
                        }
                    }
                }

                // Terminal container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.small
                    color: "#1e1e2e"
                    clip: true

                    Loader {
                        id: terminalLoader
                        anchors.fill: parent
                        anchors.margins: 4
                        active: kubeState.currentView === "shell"
                        
                        sourceComponent: QMLTermWidget {
                            id: terminal
                            anchors.fill: parent

                            font.family: "monospace"
                            font.pointSize: 11
                            colorScheme: "Linux"

                            session: QMLTermSession {
                                initialWorkingDirectory: Quickshell.env("HOME") || "/tmp"

                                onFinished: {
                                    kubeState.currentView = "list";
                                    keyHandler.forceActiveFocus();
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape && (event.modifiers & Qt.ControlModifier)) {
                                    session.sendSignal(15);
                                    kubeState.currentView = "list";
                                    keyHandler.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            Component.onCompleted: {
                                forceActiveFocus();
                                
                                session.shellProgram = "/bin/bash";
                                session.shellProgramArgs = [];
                                session.startShellProgram();
                                
                                Qt.callLater(() => {
                                    let cmd = `kubectl exec -it -n ${kubeState.shellNamespace} ${kubeState.shellPod}`;
                                    if (kubeState.shellContainer)
                                        cmd += ` -c ${kubeState.shellContainer}`;
                                    cmd += ` -- sh -c 'exec bash 2>/dev/null || exec sh'\n`;
                                    session.sendText(cmd);
                                });
                            }
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Ctrl+Esc to close")
                    font.pointSize: Tokens.font.body.small.pointSize
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.5
                }
            }
        }
    }

    // Focus management
    Connections {
        target: kubeState
        function onCurrentViewChanged(): void {
            if (kubeState.currentView === "shell" && terminalLoader.item) {
                terminalLoader.item.forceActiveFocus();
            } else {
                keyHandler.forceActiveFocus();
            }
        }
    }

    Component.onCompleted: {
        if (filteredResources.length > 0 && kubeState.selectedIndex < 0)
            kubeState.selectedIndex = 0;
        resetInactivityTimer();
        keyHandler.forceActiveFocus();
    }
}
