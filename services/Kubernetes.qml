pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

Singleton {
    id: root

    // Reference counting for lifecycle management
    property int refCount

    // Cluster context
    property string currentContext: ""
    property string currentNamespace: GlobalConfig.kubernetes?.defaultNamespace ?? "default"
    property var contexts: []
    property var namespaces: []

    // Cluster data
    property var nodes: []
    property var pods: []              // Pods filtered by currentNamespace
    property var allPods: []           // All pods across all namespaces (for popout overview)
    property var deployments: []
    property var services: []

    // Aggregated stats (based on allPods for global overview)
    readonly property int totalPods: allPods.length
    readonly property int runningPods: allPods.filter(p => p.status === "Running").length
    readonly property int pendingPods: allPods.filter(p => p.status === "Pending").length
    readonly property int failedPods: allPods.filter(p => ["CrashLoopBackOff", "Error", "Failed", "ImagePullBackOff", "ErrImagePull", "CreateContainerConfigError"].includes(p.status)).length
    readonly property int healthyNodes: nodes.filter(n => n.status === "Ready").length
    readonly property int totalNodes: nodes.length

    // Overall cluster health (based on all pods)
    readonly property string clusterHealth: {
        if (!currentContext)
            return "unknown";
        if (failedPods > 0 || healthyNodes < totalNodes)
            return "error";
        if (pendingPods > 0)
            return "warning";
        return "healthy";
    }

    // Loading states
    property bool loading: false
    property bool available: false
    property string lastError: ""

    // Actions
    function deletePod(namespace: string, name: string, callback: var): void {
        deleteProcess.callback = callback;
        deleteProcess.command = ["kubectl", "delete", "pod", "-n", namespace, name, "--grace-period=30"];
        deleteProcess.running = true;
    }

    function execShell(namespace: string, pod: string, container: string): void {
        const terminal = GlobalConfig.kubernetes?.terminal ?? "foot";
        const args = [terminal];

        // Handle different terminal emulators
        if (terminal.includes("foot") || terminal.includes("alacritty") || terminal.includes("kitty")) {
            args.push("-e");
        } else if (terminal.includes("gnome-terminal") || terminal.includes("konsole")) {
            args.push("--");
        } else {
            args.push("-e");
        }

        args.push("kubectl", "exec", "-it", "-n", namespace, pod);
        if (container)
            args.push("-c", container);
        args.push("--", "/bin/sh", "-c", "command -v bash >/dev/null && exec bash || exec sh");

        Quickshell.execDetached(args);
    }

    function getLogs(namespace: string, pod: string, container: string, follow: bool, callback: var): void {
        const proc = logsProcessComponent.createObject(root, {
            namespace: namespace,
            podName: pod,
            containerName: container,
            follow: follow,
            callback: callback
        });
        proc.running = true;
        return proc;
    }

    function describe(resourceType: string, namespace: string, name: string, callback: var): void {
        describeProcess.callback = callback;
        describeProcess.command = ["kubectl", "describe", resourceType, "-n", namespace, name];
        describeProcess.running = true;
    }

    function setNamespace(ns: string): void {
        currentNamespace = ns;
        refresh();
    }

    function setContext(ctx: string): void {
        contextSwitch.targetContext = ctx;
        contextSwitch.command = ["kubectl", "config", "use-context", ctx];
        contextSwitch.running = true;
    }

    function refresh(): void {
        if (refCount > 0) {
            loading = true;
            podsProcess.running = true;
            allPodsProcess.running = true;
            nodesProcess.running = true;
            deploymentsProcess.running = true;
            servicesProcess.running = true;
        }
    }

    function scaleDeploy(namespace: string, name: string, replicas: int, callback: var): void {
        scaleProcess.callback = callback;
        scaleProcess.command = ["kubectl", "scale", "deployment", "-n", namespace, name, `--replicas=${replicas}`];
        scaleProcess.running = true;
    }

    function restartDeploy(namespace: string, name: string, callback: var): void {
        restartProcess.callback = callback;
        restartProcess.command = ["kubectl", "rollout", "restart", "deployment", "-n", namespace, name];
        restartProcess.running = true;
    }

    // Utility functions
    function formatAge(timestamp: string): string {
        if (!timestamp)
            return "-";
        const ms = Date.now() - new Date(timestamp).getTime();
        const mins = Math.floor(ms / 60000);
        const hours = Math.floor(mins / 60);
        const days = Math.floor(hours / 24);

        if (days > 0)
            return `${days}d`;
        if (hours > 0)
            return `${hours}h`;
        if (mins > 0)
            return `${mins}m`;
        return "<1m";
    }

    function formatBytes(bytes: real): string {
        if (bytes === 0)
            return "0B";
        const k = 1024;
        const sizes = ["B", "Ki", "Mi", "Gi", "Ti"];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${(bytes / Math.pow(k, i)).toFixed(1)}${sizes[i]}`;
    }

    function parseK8sMemory(memStr: string): real {
        if (!memStr)
            return 0;
        const match = memStr.match(/^(\d+)(\w+)?$/);
        if (!match)
            return 0;
        const value = parseInt(match[1], 10);
        const unit = match[2] || "";
        switch (unit) {
        case "Ki":
            return value * 1024;
        case "Mi":
            return value * 1024 * 1024;
        case "Gi":
            return value * 1024 * 1024 * 1024;
        case "Ti":
            return value * 1024 * 1024 * 1024 * 1024;
        default:
            return value;
        }
    }

    // Polling timer
    Timer {
        running: root.refCount > 0
        interval: GlobalConfig.kubernetes?.updateInterval ?? 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Initial context detection
    Process {
        id: contextInit

        running: true
        command: ["kubectl", "config", "current-context"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ctx = text.trim();
                if (ctx && !ctx.startsWith("error")) {
                    root.currentContext = ctx;
                    root.available = true;
                } else {
                    root.available = false;
                    root.lastError = "No kubectl context configured";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.available = false;
                    root.lastError = text.trim();
                }
            }
        }
    }

    // List contexts
    Process {
        id: contextsProcess

        running: true
        command: ["kubectl", "config", "get-contexts", "-o", "name"]
        stdout: StdioCollector {
            onStreamFinished: root.contexts = text.trim().split("\n").filter(c => c && !c.startsWith("error"))
        }
    }

    // List namespaces
    Timer {
        running: root.refCount > 0 && root.available
        interval: 30000 // Refresh namespaces every 30s
        repeat: true
        triggeredOnStart: true
        onTriggered: namespacesProcess.running = true
    }

    Process {
        id: namespacesProcess

        command: ["kubectl", "get", "namespaces", "-o", "jsonpath={.items[*].metadata.name}"]
        stdout: StdioCollector {
            onStreamFinished: root.namespaces = text.trim().split(" ").filter(n => n)
        }
    }

    // Pods
    Process {
        id: podsProcess

        readonly property bool allNamespaces: root.currentNamespace === "__all__"

        command: ["kubectl", "get", "pods", ...(allNamespaces ? ["--all-namespaces"] : ["-n", root.currentNamespace]), "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.pods = (data.items || []).map(item => {
                        const containerStatuses = item.status?.containerStatuses || [];
                        const initContainerStatuses = item.status?.initContainerStatuses || [];

                        // Determine actual status
                        let status = item.status?.phase || "Unknown";
                        if (status === "Running") {
                            // Check for waiting containers
                            const waitingContainer = containerStatuses.find(c => c.state?.waiting);
                            if (waitingContainer?.state?.waiting) {
                                status = waitingContainer.state.waiting.reason || "Waiting";
                            }
                            // Check for terminated with error
                            const terminatedContainer = containerStatuses.find(c => c.state?.terminated && c.state.terminated.exitCode !== 0);
                            if (terminatedContainer?.state?.terminated) {
                                status = terminatedContainer.state.terminated.reason || "Error";
                            }
                        }

                        // Check init containers
                        if (status === "Pending") {
                            const waitingInit = initContainerStatuses.find(c => c.state?.waiting);
                            if (waitingInit?.state?.waiting) {
                                status = `Init:${waitingInit.state.waiting.reason || "Waiting"}`;
                            }
                        }

                        const readyCount = containerStatuses.filter(c => c.ready).length;
                        const totalContainers = item.spec?.containers?.length || 0;

                        return {
                            name: item.metadata?.name || "",
                            namespace: item.metadata?.namespace || "",
                            status: status,
                            ready: `${readyCount}/${totalContainers}`,
                            restarts: containerStatuses.reduce((sum, c) => sum + (c.restartCount || 0), 0),
                            age: root.formatAge(item.metadata?.creationTimestamp),
                            node: item.spec?.nodeName || "-",
                            containers: (item.spec?.containers || []).map(c => c.name),
                            ip: item.status?.podIP || "-",
                            createdAt: item.metadata?.creationTimestamp || ""
                        };
                    });
                    root.lastError = "";
                } catch (e) {
                    console.error("K8s pods parse error:", e);
                    root.lastError = `Failed to parse pods: ${e}`;
                }
                root.loading = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.lastError = text.trim();
                    root.loading = false;
                }
            }
        }
    }

    // All pods (for global stats and popout overview)
    Process {
        id: allPodsProcess

        command: ["kubectl", "get", "pods", "--all-namespaces", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.allPods = (data.items || []).map(item => {
                        const containerStatuses = item.status?.containerStatuses || [];
                        const initContainerStatuses = item.status?.initContainerStatuses || [];

                        let status = item.status?.phase || "Unknown";
                        if (status === "Running") {
                            const waitingContainer = containerStatuses.find(c => c.state?.waiting);
                            if (waitingContainer?.state?.waiting) {
                                status = waitingContainer.state.waiting.reason || "Waiting";
                            }
                            const terminatedContainer = containerStatuses.find(c => c.state?.terminated && c.state.terminated.exitCode !== 0);
                            if (terminatedContainer?.state?.terminated) {
                                status = terminatedContainer.state.terminated.reason || "Error";
                            }
                        }

                        if (status === "Pending") {
                            const waitingInit = initContainerStatuses.find(c => c.state?.waiting);
                            if (waitingInit?.state?.waiting) {
                                status = `Init:${waitingInit.state.waiting.reason || "Waiting"}`;
                            }
                        }

                        const readyCount = containerStatuses.filter(c => c.ready).length;
                        const totalContainers = item.spec?.containers?.length || 0;

                        return {
                            name: item.metadata?.name || "",
                            namespace: item.metadata?.namespace || "",
                            status: status,
                            ready: `${readyCount}/${totalContainers}`,
                            restarts: containerStatuses.reduce((sum, c) => sum + (c.restartCount || 0), 0),
                            age: root.formatAge(item.metadata?.creationTimestamp),
                            node: item.spec?.nodeName || "-",
                            containers: (item.spec?.containers || []).map(c => c.name),
                            ip: item.status?.podIP || "-",
                            createdAt: item.metadata?.creationTimestamp || ""
                        };
                    });
                } catch (e) {
                    console.error("K8s allPods parse error:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.error("K8s allPods error:", text.trim());
                }
            }
        }
    }

    // Nodes
    Process {
        id: nodesProcess

        command: ["kubectl", "get", "nodes", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.nodes = (data.items || []).map(item => {
                        const conditions = item.status?.conditions || [];
                        const readyCondition = conditions.find(c => c.type === "Ready");
                        const labels = item.metadata?.labels || {};

                        // Extract roles from labels
                        const roles = Object.keys(labels).filter(l => l.startsWith("node-role.kubernetes.io/")).map(l => l.split("/")[1]).join(",") || "worker";

                        return {
                            name: item.metadata?.name || "",
                            status: readyCondition?.status === "True" ? "Ready" : "NotReady",
                            roles: roles,
                            version: item.status?.nodeInfo?.kubeletVersion || "-",
                            age: root.formatAge(item.metadata?.creationTimestamp),
                            cpu: item.status?.allocatable?.cpu || "-",
                            memory: item.status?.allocatable?.memory || "-",
                            memoryBytes: root.parseK8sMemory(item.status?.allocatable?.memory),
                            os: item.status?.nodeInfo?.osImage || "-",
                            arch: item.status?.nodeInfo?.architecture || "-",
                            containerRuntime: item.status?.nodeInfo?.containerRuntimeVersion || "-"
                        };
                    });
                } catch (e) {
                    console.error("K8s nodes parse error:", e);
                }
            }
        }
    }

    // Deployments
    Process {
        id: deploymentsProcess

        readonly property bool allNamespaces: root.currentNamespace === "__all__"

        command: ["kubectl", "get", "deployments", ...(allNamespaces ? ["--all-namespaces"] : ["-n", root.currentNamespace]), "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.deployments = (data.items || []).map(item => ({
                        name: item.metadata?.name || "",
                        namespace: item.metadata?.namespace || "",
                        ready: `${item.status?.readyReplicas || 0}/${item.spec?.replicas || 0}`,
                        upToDate: item.status?.updatedReplicas || 0,
                        available: item.status?.availableReplicas || 0,
                        replicas: item.spec?.replicas || 0,
                        age: root.formatAge(item.metadata?.creationTimestamp),
                        images: (item.spec?.template?.spec?.containers || []).map(c => c.image).join(", ")
                    }));
                } catch (e) {
                    console.error("K8s deployments parse error:", e);
                }
            }
        }
    }

    // Services
    Process {
        id: servicesProcess

        readonly property bool allNamespaces: root.currentNamespace === "__all__"

        command: ["kubectl", "get", "services", ...(allNamespaces ? ["--all-namespaces"] : ["-n", root.currentNamespace]), "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.services = (data.items || []).map(item => ({
                        name: item.metadata?.name || "",
                        namespace: item.metadata?.namespace || "",
                        type: item.spec?.type || "-",
                        clusterIP: item.spec?.clusterIP || "-",
                        externalIP: (item.status?.loadBalancer?.ingress || []).map(i => i.ip || i.hostname).join(",") || (item.spec?.externalIPs || []).join(",") || "-",
                        ports: (item.spec?.ports || []).map(p => `${p.port}${p.nodePort ? `:${p.nodePort}` : ""}/${p.protocol}`).join(", "),
                        age: root.formatAge(item.metadata?.creationTimestamp)
                    }));
                } catch (e) {
                    console.error("K8s services parse error:", e);
                }
            }
        }
    }

    // Action processes
    Process {
        id: deleteProcess

        property var callback

        stdout: StdioCollector {
            onStreamFinished: {
                deleteProcess.callback?.(true, text.trim());
                root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    deleteProcess.callback?.(false, text.trim());
            }
        }
    }

    Process {
        id: describeProcess

        property var callback

        stdout: StdioCollector {
            onStreamFinished: describeProcess.callback?.(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    describeProcess.callback?.(`Error: ${text.trim()}`);
            }
        }
    }

    Process {
        id: contextSwitch

        property string targetContext

        stdout: StdioCollector {
            onStreamFinished: {
                root.currentContext = contextSwitch.targetContext;
                root.refresh();
            }
        }
    }

    Process {
        id: scaleProcess

        property var callback

        stdout: StdioCollector {
            onStreamFinished: {
                scaleProcess.callback?.(true, text.trim());
                root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    scaleProcess.callback?.(false, text.trim());
            }
        }
    }

    Process {
        id: restartProcess

        property var callback

        stdout: StdioCollector {
            onStreamFinished: {
                restartProcess.callback?.(true, text.trim());
                root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    restartProcess.callback?.(false, text.trim());
            }
        }
    }

    // Dynamic logs process component
    Component {
        id: logsProcessComponent

        Process {
            id: logsProc

            property string namespace
            property string podName
            property string containerName
            property bool follow
            property var callback
            property string logContent: ""

            command: ["kubectl", "logs", "-n", namespace, podName, ...(containerName ? ["-c", containerName] : []), ...(follow ? ["-f", "--tail=100"] : ["--tail=500"])]

            stdout: StdioCollector {
                onStreamFinished: {
                    logsProc.logContent = text;
                    logsProc.callback?.(text);
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim())
                        logsProc.callback?.(`Error: ${text.trim()}`);
                }
            }
        }
    }
}
