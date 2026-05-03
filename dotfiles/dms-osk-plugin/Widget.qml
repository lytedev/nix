import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    function fire() {
        toggleProcess.running = true;
    }

    Process {
        id: toggleProcess
        command: ["osk-toggle"]
        running: false
    }

    // Register a quickshell IPC method so the toggle can be invoked from
    // outside the bar — useful for remote testing (ssh) and for any other
    // automation that wants to fire the OSK without faking a touch event.
    //   quickshell ipc call oskToggle trigger
    IpcHandler {
        target: "oskToggle"
        function trigger(): string {
            root.fire();
            return "ok";
        }
    }

    // DMS plugin click hooks: the bar framework intercepts touch/click events
    // upstream and invokes these callbacks. A MouseArea inside the pill itself
    // doesn't see left-clicks because the framework consumes them first.
    pillClickAction: function () {
        root.fire();
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: icon.implicitWidth + Theme.spacingS * 2
            implicitHeight: parent ? parent.height : Theme.iconSize + Theme.spacingS

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: "keyboard"
                size: Theme.iconSize
                color: Theme.primary
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: parent ? parent.width : Theme.iconSize + Theme.spacingS
            implicitHeight: icon2.implicitHeight + Theme.spacingS * 2

            DankIcon {
                id: icon2
                anchors.centerIn: parent
                name: "keyboard"
                size: Theme.iconSize
                color: Theme.primary
            }
        }
    }
}
