// Author: Jeff
// Date: 2026-08-21
// Description: Wi-Fi, Bluetooth and audio output in one dropdown
// Notes: Replaces dropping into nmtui, bluetoothctl or wiremix in a terminal.
//        Secured networks get an in-card password field rather than launching a
//        separate terminal or desktop window.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root

    cardWidth: 460
    // Sized to content, not to a number. The fixed 650 left 8px of slack, and
    // the password row a secured network raises is 54px tall with its spacing,
    // so the output list rendered outside the card — `body` is not clipped.
    cardHeight: 0
    placement: "topRight"

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi) return d;
        return null;
    }

    property var pendingNetwork: null
    property string password: ""
    readonly property PwNode microphone: Pipewire.defaultAudioSource

    PwObjectTracker { objects: root.microphone ? [root.microphone] : [] }

    // Keep a scan running only while the panel is open
    onOpenedChanged: {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = root.open;
    }

    // Join a network inside this popup; secured unknown networks get an in-card password prompt
    function join(network) {
        if (network.connected) return;

        if (network.known || network.security === WifiSecurityType.None) {
            network.connect(null);
            root.pendingNetwork = null;
            root.password = "";
            return;
        }

        root.pendingNetwork = network;
        root.password = "";
        passwordField.forceActiveFocus();
    }

    function submitPassword() {
        if (!root.pendingNetwork || root.password === "") return;
        root.pendingNetwork.connect(root.password);
        root.pendingNetwork = null;
        root.password = "";
    }

    Column {
        width: parent.width
        spacing: 12

        // ── Toggles ──────────────────────────────────────────
        Row {
            spacing: Theme.moduleSpacing

            Pill {
                id: wifiToggle
                accent: Networking.wifiEnabled ? Theme.green : Theme.muted
                bordered: Networking.wifiEnabled ?? false
                onClicked: {
                    Networking.wifiEnabled = !Networking.wifiEnabled;
                    Osd.show("\uf1eb", "Wi-Fi", Networking.wifiEnabled ? "Enabled" : "Disabled", -1,
                        Networking.wifiEnabled ? "green" : "red");
                }

                BarText {
                    text: "\uf1eb"   // nf-fa-wifi
                    color: wifiToggle.accent
                }
            }

            Pill {
                id: btToggle
                accent: Bluetooth.defaultAdapter?.enabled ? Theme.blue : Theme.muted
                bordered: Bluetooth.defaultAdapter?.enabled ?? false
                onClicked: {
                    if (!Bluetooth.defaultAdapter) return;
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                    Qt.callLater(() => Osd.show("\uf293", "Bluetooth",
                        Bluetooth.defaultAdapter.enabled ? "Enabled" : "Disabled", -1,
                        Bluetooth.defaultAdapter.enabled ? "blue" : "red"));
                }

                BarText {
                    text: "\uf293"   // nf-fa-bluetooth
                    color: btToggle.accent
                }
            }

            Pill {
                accent: root.microphone?.audio?.muted ? Theme.red : Theme.green
                bordered: true
                onClicked: {
                    if (!root.microphone?.audio) return;
                    root.microphone.audio.muted = !root.microphone.audio.muted;
                    Osd.show("\uf130", "Microphone",
                        root.microphone.audio.muted ? "Muted" : "Live", -1,
                        root.microphone.audio.muted ? "red" : "green");
                }

                BarText {
                    text: root.microphone?.audio?.muted ? "\uf131" : "\uf130"
                    color: root.microphone?.audio?.muted ? Theme.red : Theme.green
                    font.family: Theme.iconFontFamily
                }
            }
        }

        // ── Desktop modes and actions ────────────────────────
        Row {
            spacing: Theme.moduleSpacing

            Pill {
                accent: Notifications.doNotDisturb ? Theme.orange : Theme.muted
                bordered: Notifications.doNotDisturb
                onClicked: Notifications.toggleDnd()
                BarText { text: Notifications.doNotDisturb ? "\uf1f6" : "\uf0f3"; color: Notifications.doNotDisturb ? Theme.orange : Theme.muted }
            }
            Pill {
                accent: DesktopState.focusMode ? Theme.purple : Theme.muted
                bordered: DesktopState.focusMode
                onClicked: DesktopState.toggleFocus()
                BarText { text: "\uf140"; color: DesktopState.focusMode ? Theme.purple : Theme.muted; font.family: Theme.iconFontFamily }
            }
            Pill {
                accent: Theme.isDark ? Theme.blue : Theme.yellow
                bordered: true
                onClicked: {
                    DesktopState.setPolicy("manual");
                    Theme.toggleMode();
                    Qt.callLater(() => Osd.show(Theme.isDark ? "\uf186" : "\uf185",
                        Theme.isDark ? "Dark mode" : "Light mode", Theme.name, -1,
                        Theme.isDark ? "blue" : "yellow"));
                }
                BarText { text: Theme.isDark ? "\uf186" : "\uf185"; color: Theme.isDark ? Theme.blue : Theme.yellow; font.family: Theme.iconFontFamily }
            }
            Pill {
                accent: Theme.cyan
                bordered: true
                onClicked: {
                    const modes = ["wallpaper", "schedule", "manual"];
                    const next = modes[(modes.indexOf(DesktopState.appearancePolicy) + 1) % modes.length];
                    DesktopState.setPolicy(next);
                    Osd.show(next === "wallpaper" ? "\uf03e" : next === "schedule" ? "\uf017" : "\uf25a",
                        "Appearance policy", next, -1, "cyan");
                }
                BarText {
                    text: DesktopState.appearancePolicy === "wallpaper" ? "\uf03e"
                        : DesktopState.appearancePolicy === "schedule" ? "\uf017" : "\uf25a"
                    color: Theme.cyan
                    font.family: Theme.iconFontFamily
                }
            }
            Pill {
                accent: Theme.accentBrightness
                bordered: true
                onScrolledUp: Backlight.adjust(5)
                onScrolledDown: Backlight.adjust(-5)
                BarText { text: `\udb80\udcde ${Backlight.percent}%`; color: Theme.accentBrightness }
            }
            Pill {
                accent: Theme.purple
                onClicked: Quickshell.execDetached(["qs", "-c", "mgeist", "ipc", "call", "capture", "toggle"])
                BarText { text: "\uf030"; color: Theme.purple; font.family: Theme.iconFontFamily }
            }
            Pill {
                accent: Theme.red
                onClicked: Quickshell.execDetached(["qs", "-c", "mgeist", "ipc", "call", "recovery", "toggle"])
                BarText { text: "\uf0ad"; color: Theme.red; font.family: Theme.iconFontFamily }
            }
        }

        BarText {
            text: `${DesktopState.focusMode ? "Focus mode" : "Normal mode"} • ${DesktopState.appearancePolicy} appearance • scroll brightness`
            color: Theme.faint
            font.pixelSize: Theme.fontSize - 2
        }

        // ── Wi-Fi ────────────────────────────────────────────
        BarText {
            text: "Wi-Fi"
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 1
        }

        ListView {
            width: parent.width
            height: 170
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            model: {
                if (!root.wifiDevice) return [];
                return [...root.wifiDevice.networks.values]
                    .filter(n => n.name !== "")
                    .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
                    .slice(0, 30);
            }

            delegate: Rectangle {
                id: net
                required property var modelData

                width: ListView.view.width
                height: 30
                radius: Theme.popupRadius
                color: netHover.containsMouse ? Qt.alpha(Theme.green, 0.12) : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.modulePadH
                    anchors.rightMargin: Theme.modulePadH
                    spacing: Theme.iconGap

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        // nf-fa-check when joined, nf-fa-signal otherwise
                        text: net.modelData.connected ? "\uf00c" : "\uf012"
                        color: net.modelData.connected ? Theme.green : Theme.muted
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: net.width - 110
                        text: net.modelData.name
                        color: net.modelData.connected ? Theme.fg : Theme.muted
                        elide: Text.ElideRight
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: net.modelData.security === WifiSecurityType.None ? "" : "\uf023"
                        color: Theme.faint
                        font.pixelSize: Theme.fontSize - 2
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        // signalStrength is 0..1, like UPower's percentage
                        text: `${Math.round(net.modelData.signalStrength * 100)}%`
                        color: Theme.faint
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                MouseArea {
                    id: netHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.join(net.modelData)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: root.pendingNetwork ? 42 : 0
            visible: root.pendingNetwork !== null
            color: Qt.alpha(Theme.orange, 0.08)
            radius: Theme.popupRadius
            border.width: 1
            border.color: Theme.edge(Theme.orange)

            Row {
                anchors.fill: parent
                anchors.margins: 7
                spacing: 7

                BarText {
                    id: networkLabel
                    text: `\uf023 ${root.pendingNetwork?.name ?? "Wi-Fi"}`
                    color: Theme.orange
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: passwordField
                    // The label carries an SSID, so its width is not a constant:
                    // 150 assumed a short one and squeezed the field on a long one
                    width: parent.width - networkLabel.width - joinButton.width - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.password
                    onTextChanged: root.password = text
                    echoMode: TextInput.Password
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true
                    selectByMouse: true
                    Keys.onReturnPressed: root.submitPassword()
                }

                Pill {
                    id: joinButton
                    accent: Theme.green
                    bordered: true
                    onClicked: root.submitPassword()

                    BarText {
                        text: "\uf00c"
                        color: Theme.green
                    }
                }
            }
        }

        // ── Bluetooth ────────────────────────────────────────
        BarText {
            text: "Bluetooth"
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 1
        }

        ListView {
            width: parent.width
            height: 120
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Bluetooth.devices

            delegate: Rectangle {
                id: dev
                required property BluetoothDevice modelData

                // A shrinking model hands the delegate a null modelData while it
                // tears down, and every binding below threw reading through it.
                // Guarded with `&&` rather than `?.`, which would stop tracking.
                readonly property bool connected: dev.modelData && dev.modelData.connected
                readonly property string label: dev.modelData
                    ? (dev.modelData.deviceName || dev.modelData.address || "") : ""
                readonly property string charge: dev.modelData && dev.modelData.batteryAvailable
                    ? `${Math.round(dev.modelData.battery * 100)}%` : ""

                width: ListView.view.width
                height: 30
                radius: Theme.popupRadius
                color: devHover.containsMouse ? Qt.alpha(Theme.blue, 0.12) : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.modulePadH
                    spacing: Theme.iconGap

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dev.connected ? "\uf00c" : "\uf293"
                        color: dev.connected ? Theme.blue : Theme.muted
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: dev.width - 90
                        text: dev.label
                        color: dev.connected ? Theme.fg : Theme.muted
                        elide: Text.ElideRight
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dev.charge
                        color: Theme.faint
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                MouseArea {
                    id: devHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (dev.modelData) dev.modelData.connected = !dev.connected
                }
            }
        }

        // ── Output ───────────────────────────────────────────
        BarText {
            text: "Output"
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 1
        }

        ListView {
            // Three sinks at 28px plus spacing; 90 clipped the last row, which
            // is regularly the default one
            width: parent.width
            height: 122
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            model: [...Pipewire.nodes.values].filter(n => n.isSink && !n.isStream)

            delegate: Rectangle {
                id: sink
                required property var modelData

                // Compare by id; the default sink arrives as a different wrapper
                // object than the one in Pipewire.nodes, so === never matches
                readonly property bool isDefault: Pipewire.defaultAudioSink?.id === sink.modelData.id

                width: ListView.view.width
                height: 28
                radius: Theme.popupRadius
                color: sinkHover.containsMouse ? Qt.alpha(Theme.orange, 0.12) : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.modulePadH
                    spacing: Theme.iconGap

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sink.isDefault ? "\uf00c" : "\uf028"
                        color: sink.isDefault ? Theme.orange : Theme.muted
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: sink.width - 60
                        text: sink.modelData.description || sink.modelData.nickname || sink.modelData.name
                        color: sink.isDefault ? Theme.fg : Theme.muted
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: sinkHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Pipewire.preferredDefaultAudioSink = sink.modelData
                }
            }
        }
    }
}
