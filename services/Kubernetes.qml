pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    property int nodesTotal: 0
    property int nodesReady: 0
    property int podsTotal: 0
    property int podsRunning: 0
    property int podsFailed: 0
    property int podsPending: 0

    property string clusterContext: ""
    property bool isConnected: false
    property bool isLoading: false
    property string errorMessage: ""

    readonly property string statusClass: {
        if (!isConnected) return "critical";
        if (podsFailed > 5 || nodesReady === 0) return "critical";
        if (podsFailed > 0 || nodesReady !== nodesTotal) return "warning";
        return "normal";
    }

    property var nodesList: []
    property var namespaceStats: []

    Timer {
        interval: 30000 // 30 secondes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: clusterInfoProc

        command: ["kubectl", "cluster-info"]

        onExited: code => {
            if (code === 0) {
                isConnected = true;
                contextProc.running = true;
                nodesProc.running = true;
                podsProc.running = true;
            } else {
                isConnected = false;
                errorMessage = "Cannot connect to cluster";
                isLoading = false;
            }
        }
    }

    Process {
        id: contextProc

        command: ["kubectl", "config", "current-context"]

        stdout: StdioCollector {
            onStreamFinished: {
                clusterContext = text.trim();
            }
        }
    }

    Process {
        id: nodesProc

        command: ["kubectl", "get", "nodes", "--no-headers"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n').filter(l => l.length > 0);
                nodesTotal = lines.length;
                nodesReady = 0;

                const nodeDetails = [];

                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(/\s+/);
                    if (parts.length >= 5) {
                        const nodeName = parts[0];
                        const nodeStatus = parts[1];
                        const nodeRole = parts[2] || "worker";
                        const nodeVersion = parts[4];

                        if (nodeStatus.includes("Ready")) {
                            nodesReady++;
                        }

                        nodeDetails.push({
                            name: nodeName,
                            status: nodeStatus,
                            role: nodeRole,
                            version: nodeVersion
                        });
                    }
                }

                nodesList = nodeDetails;
            }
        }
    }

    Process {
        id: podsProc

        command: ["kubectl", "get", "pods", "--all-namespaces", "--no-headers"]

        onExited: {
            isLoading = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n').filter(l => l.length > 0);
                podsTotal = lines.length;
                podsRunning = 0;
                podsFailed = 0;
                podsPending = 0;

                const nsCount = {};

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const parts = line.split(/\s+/);

                    if (parts.length >= 4) {
                        const namespace = parts[0];
                        const status = parts[3];

                        // Compter par namespace
                        nsCount[namespace] = (nsCount[namespace] || 0) + 1;

                        if (status === "Running") {
                            podsRunning++;
                        } else if (status === "Pending") {
                            podsPending++;
                        } else if (status.match(/(Failed|Error|CrashLoopBackOff)/)) {
                            podsFailed++;
                        }
                    }
                }

                // Convertir en tableau et trier
                const nsArray = Object.keys(nsCount).map(ns => ({
                    namespace: ns,
                    count: nsCount[ns]
                }));
                nsArray.sort((a, b) => b.count - a.count);
                namespaceStats = nsArray.slice(0, 5);
            }
        }
    }

    Process {
        id: deletePodsProc

        command: [
            "kubectl", "delete", "pods",
            "--field-selector=status.phase!=Running,status.phase!=Pending",
            "--all-namespaces"
        ]

        onExited: {
            refresh();
        }
    }

    Process {
        id: eventsProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    // Ouvrir dans un terminal pour afficher les événements
                    const terminal = Config.general.apps.terminal[0] || "alacritty";
                    Quickshell.execDetached([
                        terminal, "-e", "sh", "-c",
                        `echo '${text}' | less -R`
                    ]);
                }
            }
        }
    }

    function refresh(): void {
        isLoading = true;
        errorMessage = "";
        clusterInfoProc.running = true;
    }

    function getStatusIcon(): string {
        switch (statusClass) {
            case "critical": return "error";
            case "warning": return "warning";
            default: return "check_circle";
        }
    }

    function deleteInactivePods(): void {
        console.log("Deleting inactive pods...");
        deletePodsProc.running = true;
    }

    function getEvents(namespace: string): void {
        const args = ["kubectl", "get", "events"];

        if (namespace && namespace !== "all") {
            args.push("-n", namespace);
        } else {
            args.push("--all-namespaces");
        }

        args.push("--sort-by=.lastTimestamp");
        args.push("--field-selector=type!=Normal");

        eventsProc.command = args;
        eventsProc.running = true;
    }
}
