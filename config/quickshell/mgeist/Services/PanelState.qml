// Only one primary overlay owns the desktop at a time.
pragma Singleton
import Quickshell

Singleton {
    property var activePanel: null
    function activate(panel) {
        if (activePanel && activePanel !== panel) activePanel.close();
        activePanel = panel;
    }
    function release(panel) { if (activePanel === panel) activePanel = null; }
}
