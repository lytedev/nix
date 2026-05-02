import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["osk-toggle"])
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["osk-toggle"])
            }
        }
    }
}
