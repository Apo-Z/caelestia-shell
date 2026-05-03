pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Prayer data
    property var prayers: []
    property int nextIndex: -1
    property string nextName: ""
    property string nextTime: ""
    property string error: ""
    property bool loading: false

    // Computed properties for easy access
    readonly property bool hasData: prayers.length === 6
    readonly property var nextPrayer: hasData && nextIndex >= 0 ? prayers[nextIndex] : null

    // Format: returns "Fajr" or "Dhuhr" etc
    readonly property string currentPrayerName: nextPrayer ? nextPrayer.name : ""
    readonly property string currentPrayerTime: nextPrayer ? nextPrayer.time : "--:--"

    // Get prayer by index (0=Fajr, 1=Sunrise, 2=Dhuhr, 3=Asr, 4=Maghrib, 5=Isha)
    function getPrayer(index: int): var {
        if (index >= 0 && index < prayers.length)
            return prayers[index];
        return null;
    }

    // Get prayer by id
    function getPrayerById(id: string): var {
        for (const p of prayers) {
            if (p.id === id)
                return p;
        }
        return null;
    }

    function reload(): void {
        prayerProcess.running = true;
    }

    function updateNextPrayer(): void {
        if (!hasData)
            return;

        const now = new Date();
        const nowMin = now.getHours() * 60 + now.getMinutes();

        let foundNext = false;
        for (let i = 0; i < prayers.length; i++) {
            const parts = prayers[i].time.split(":");
            const prayerMin = parseInt(parts[0]) * 60 + parseInt(parts[1]);
            if (prayerMin > nowMin) {
                nextIndex = i;
                nextName = prayers[i].name;
                nextTime = prayers[i].time;
                foundNext = true;
                break;
            }
        }

        // If no next prayer found today, the next is Fajr (tomorrow)
        if (!foundNext && prayers.length > 0) {
            nextIndex = 0;
            nextName = prayers[0].name;
            nextTime = prayers[0].time;
        }
    }

    Component.onCompleted: reload()

    // Update next prayer every minute
    Timer {
        interval: 60000
        running: root.hasData
        repeat: true
        onTriggered: root.updateNextPrayer()
    }

    // Reload prayer times every 6 hours
    Timer {
        interval: 21600000 // 6 hours
        running: true
        repeat: true
        onTriggered: root.reload()
    }

    Process {
        id: prayerProcess

        command: ["/home/apo/scripts/prayer/run_prayer.sh"]

        onRunningChanged: {
            if (running)
                root.loading = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(text);

                    if (data.error) {
                        root.error = data.error;
                        return;
                    }

                    root.error = "";
                    root.prayers = data.prayers || [];
                    root.nextIndex = data.nextIndex ?? -1;
                    root.nextName = data.nextName ?? "";
                    root.nextTime = root.prayers[root.nextIndex]?.time ?? "--:--";
                } catch (e) {
                    root.error = "Failed to parse prayer data: " + e.message;
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("Prayer script stderr:", text.trim());
            }
        }
    }

    IpcHandler {
        target: "prayer"

        function reload(): void {
            root.reload();
        }
    }
}
