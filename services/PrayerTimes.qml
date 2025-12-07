pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.utils

Singleton {
    id: root

    property string nextPrayer: ""
    property string nextPrayerTime: ""
    property int nextPrayerIndex: -1

    property var prayerTimes: ({
        "fajr": "",
        "chourouk": "",
        "dhuhr": "",
        "asr": "",
        "maghrib": "",
        "isha": ""
    })

    readonly property var prayerNames: ["fajr", "chourouk", "dhuhr", "asr", "maghrib", "isha"]
    readonly property var prayerDisplayNames: {
        "fajr": "Fajr",
        "chourouk": "Chourouk",
        "dhuhr": "Dhuhr",
        "asr": "Asr",
        "maghrib": "Maghrib",
        "isha": "Isha"
    }

    property bool isLoading: false
    property string errorMessage: ""
    property int currentPrayerIndex: 0

    // Timer pour rafraîchir toutes les heures
    Timer {
        interval: 3600000 // 1 heure
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Timer pour vérifier la prochaine prière toutes les minutes
    Timer {
        interval: 60000 // 1 minute
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateNextPrayer()
    }

    Component.onCompleted: {
        refresh();
    }

    Process {
        id: prayerProc

        onExited: {
            // Charger la prière suivante après la fin du process
            if (root.currentPrayerIndex < prayerNames.length - 1) {
                root.currentPrayerIndex++;
                loadPrayer(root.currentPrayerIndex);
            } else {
                isLoading = false;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    const prayerName = prayerNames[root.currentPrayerIndex];
                    prayerTimes[prayerName] = result.text || "";

                    // Forcer la mise à jour de l'objet
                    const temp = prayerTimes;
                    prayerTimes = {};
                    prayerTimes = temp;

                    updateNextPrayer();
                } catch (e) {
                    console.error("Failed to parse prayer time for", prayerNames[root.currentPrayerIndex], ":", e, "- Data:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                // Ignorer les erreurs vides ou les warnings bash de source
                if (text.trim().length > 0 && !text.includes("source:") && !text.includes("bash:")) {
                    console.error("Prayer script error for", prayerNames[root.currentPrayerIndex], ":", text);
                }
            }
        }
    }

    function refresh(): void {
        isLoading = true;
        errorMessage = "";
        currentPrayerIndex = 0;
        loadPrayer(0);
    }

    function loadPrayer(index: int): void {
        const scriptPath = `${Paths.home}/scripts/prayer/prayer.sh`;
        prayerProc.command = [scriptPath, index.toString()];
        prayerProc.running = true;
    }

    function updateNextPrayer(): void {
        const now = new Date();
        const currentHour = now.getHours();
        const currentMinute = now.getMinutes();
        const currentTime = currentHour * 60 + currentMinute;

        let foundNext = false;

        for (let i = 0; i < prayerNames.length; i++) {
            const prayerName = prayerNames[i];
            const timeStr = prayerTimes[prayerName];

            if (!timeStr) continue;

            const parts = timeStr.split(':');
            if (parts.length !== 2) continue;

            const prayerHour = parseInt(parts[0]);
            const prayerMinute = parseInt(parts[1]);
            const prayerTime = prayerHour * 60 + prayerMinute;

            if (prayerTime > currentTime) {
                nextPrayer = prayerDisplayNames[prayerName];
                nextPrayerTime = timeStr;
                nextPrayerIndex = i;
                foundNext = true;
                break;
            }
        }

        // Si aucune prière trouvée aujourd'hui, prendre Fajr (prochaine prière du lendemain)
        if (!foundNext && prayerTimes["fajr"]) {
            nextPrayer = prayerDisplayNames["fajr"];
            nextPrayerTime = prayerTimes["fajr"];
            nextPrayerIndex = 0;
        }
    }

    function getPrayerIcon(prayerName: string): string {
        switch (prayerName.toLowerCase()) {
            case "fajr": return "wb_twilight";
            case "chourouk": return "wb_sunny";
            case "dhuhr": return "wb_sunny";
            case "asr": return "light_mode";
            case "maghrib": return "wb_twilight";
            case "isha": return "nights_stay";
            default: return "schedule";
        }
    }
}
