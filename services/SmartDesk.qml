pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int currentPosition: 0
    property int targetPosition: 0
    property bool isMoving: false
    property string direction: "stopped"
    property bool isCalibrating: false
    property bool isLoading: false
    property string errorMessage: ""

    property var modes: []

    readonly property string statusIcon: {
        if (isCalibrating) return "engineering";
        if (!isMoving) return "desk";
        switch (direction) {
            case "up": return "arrow_upward";
            case "down": return "arrow_downward";
            default: return "sync";
        }
    }

    readonly property string statusText: {
        if (isCalibrating) return "Calibrating...";
        if (!isMoving) return "Stopped";
        switch (direction) {
            case "up": return "Moving Up";
            case "down": return "Moving Down";
            default: return "Moving...";
        }
    }

    Timer {
        interval: 5000 // 5 secondes pour le statut
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statusProc.running = true;
        }
    }

    Timer {
        interval: 60000 // 1 minute pour les modes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            isLoading = true;
            modesProc.running = true;
        }
    }

    Process {
        id: statusProc

        command: ["smart-desk-cli", "get", "status", "-o", "json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);

                    if (data && data.status) {
                        const status = data.status;

                        currentPosition = status.sensor_position_mm || status.position_mm || 0;
                        targetPosition = status.target_position_mm || currentPosition;
                        isMoving = status.is_moving || false;
                        direction = status.direction || "stopped";
                        isCalibrating = status.is_calibrating || false;

                        errorMessage = "";
                    }
                } catch (e) {
                    console.error("Failed to parse smart-desk status:", e);
                    errorMessage = "Failed to parse status data";
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    errorMessage = "Cannot connect to smart-desk";
                }
            }
        }
    }

    Process {
        id: modesProc

        command: ["smart-desk-cli", "mode", "get", "-a", "-o", "json"]

        onExited: {
            isLoading = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);

                    if (data && data.desk_modes) {
                        const modeList = [];

                        for (let i = 0; i < data.desk_modes.length; i++) {
                            const mode = data.desk_modes[i];
                            modeList.push({
                                name: mode.name,
                                position: mode.sensor_position_mm || 0,
                                createdAt: mode.created_at || 0,
                                updatedAt: mode.updated_at || 0
                            });
                        }

                        modes = modeList;
                        errorMessage = "";
                    }
                } catch (e) {
                    console.error("Failed to parse smart-desk modes:", e);
                    errorMessage = "Failed to parse modes data";
                }
            }
        }
    }

    Process {
        id: actionProc

        onExited: {
            Qt.callLater(() => statusProc.running = true);
        }
    }

    function moveTo(modeName: string): void {
        console.log("Moving to mode:", modeName);
        actionProc.command = ["smart-desk-cli", "move-to", modeName];
        actionProc.running = true;
    }

    function stop(): void {
        console.log("Stopping desk movement");
        actionProc.command = ["smart-desk-cli", "stop"];
        actionProc.running = true;
    }

    function moveUp(): void {
        console.log("Moving desk up");
        actionProc.command = ["smart-desk-cli", "move", "up"];
        actionProc.running = true;
    }

    function moveDown(): void {
        console.log("Moving desk down");
        actionProc.command = ["smart-desk-cli", "move", "down"];
        actionProc.running = true;
    }

    function refresh(): void {
        statusProc.running = true;
        isLoading = true;
        modesProc.running = true;
    }

    function formatTimestamp(timestamp: int): string {
        if (!timestamp) return "N/A";

        const date = new Date(timestamp * 1000);
        return Qt.formatDateTime(date, "dd/MM/yyyy HH:mm");
    }

    function getClosestMode(): var {
        if (modes.length === 0 || currentPosition === 0) return null;

        let closest = null;
        let minDiff = Infinity;

        for (let i = 0; i < modes.length; i++) {
            const mode = modes[i];
            if (mode.position) {
                const diff = Math.abs(mode.position - currentPosition);
                if (diff < minDiff) {
                    minDiff = diff;
                    closest = mode;
                }
            }
        }

        // Seulement retourner si très proche (moins de 10mm)
        return (minDiff <= 10) ? closest : null;
    }
}
