import QtQuick

QtObject {
    // Tab and navigation
    property int currentTab: 0
    property int selectedIndex: -1

    // View mode: "list", "output", "namespace", or "shell"
    property string currentView: "list"

    // Namespace selection
    property int nsSelectedIndex: 0

    // Search
    property bool searchMode: false
    property string searchQuery: ""

    // Output view content (logs, describe, help)
    property string outputTitle: ""
    property string outputContent: ""
    
    // Shell view
    property string shellPod: ""
    property string shellNamespace: ""
    property string shellContainer: ""
}
