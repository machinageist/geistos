// Author: Jeff
// Date: 2026-08-23
// Description: Unified quiet dashboard for monitoring and operating the desktop
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root

    cardWidth: 760
    cardHeight: 620
    placement: "center"
    property string currentTab: "overview"
    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property UPowerDevice physicalBattery: {
        for (const device of UPower.devices.values)
            if (device.isLaptopBattery) return device;
        return battery;
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
                                      || battery?.state === UPowerDeviceState.FullyCharged
    readonly property int batteryPercent: battery?.isPresent ? Math.round(battery.percentage * 100) : 0
    readonly property int batteryHealthPercent: {
        if (!physicalBattery?.healthSupported) return 0;
        const value = Number(physicalBattery.healthPercentage);
        return Math.round(value <= 1 ? value * 100 : value);
    }
    readonly property var tabs: [
        { id: "overview", label: "Overview", glyph: "\uf0ae" },
        { id: "ai", label: "AI", glyph: "\uf0d0" },
        { id: "power", label: "Power", glyph: "\uf240" },
        { id: "maintenance", label: "Maintain", glyph: "\uf0ad" },
        { id: "security", label: "Security", glyph: "\uf3ed" }
    ]

    function showTab(name) {
        root.currentTab = root.tabs.some(tab => tab.id === name) ? name : "overview";
        root.show();
    }

    function duration(seconds) {
        const value = Number(seconds ?? 0);
        if (!(value > 0)) return "calculating";
        const hours = Math.floor(value / 3600);
        const minutes = Math.round((value % 3600) / 60);
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
    }

    function money(period, provider) {
        return Telemetry.money(period?.[provider] ?? ({}));
    }

    function providerLine(period, provider) {
        const data = period?.[provider] ?? ({});
        return `${Telemetry.money(data)}  •  ${Telemetry.tokens(data.inputTokens)} in  ${Telemetry.tokens(data.outputTokens)} out  ${Telemetry.tokens(data.cachedTokens)} cached`;
    }

    function launch(action) {
        Commands.run(action);
        root.close();
    }

    onOpenedChanged: if (open) Telemetry.refresh()

    component SectionTitle: BarText {
        required property string label
        required property color tone
        width: parent?.width ?? implicitWidth
        text: label
        color: tone
        font.bold: true
        font.pixelSize: Theme.fontSize + 1
    }

    component MetricRow: Row {
        required property string label
        required property string value
        property color tone: Theme.fg
        width: parent?.width ?? implicitWidth
        height: 24

        BarText {
            width: parent.width * 0.43
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.muted
        }
        BarText {
            width: parent.width * 0.57
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: parent.tone
            elide: Text.ElideRight
        }
    }

    component ActionTile: Rectangle {
        required property var action
        width: 180
        height: 44
        radius: Theme.popupRadius
        color: tileHit.containsMouse ? Qt.alpha(Theme.purple, 0.12) : "transparent"
        border.width: 1
        border.color: Theme.edge(Theme.muted)

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            BarText {
                id: tileGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: action.glyph
                color: Theme.purple
                font.family: Theme.iconFontFamily
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                // Whatever the glyph leaves, measured from it
                width: parent.width - tileGlyph.width - parent.spacing
                BarText { width: parent.width; text: action.name; color: Theme.fg; elide: Text.ElideRight }
                BarText { width: parent.width; text: action.subtitle; color: Theme.faint; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight }
            }
        }
        MouseArea { id: tileHit; anchors.fill: parent; hoverEnabled: true; onClicked: root.launch(action) }
    }

    Column {
        id: stack
        width: parent.width
        height: root.cardHeight - root.padding * 2
        spacing: 10

        // Tabs left, refresh anchored right. The spacer this replaces encoded both
        // the tab count and a guessed 104px tab width, and was already wrong:
        // the refresh pill sat ~135px short of the card's edge.
        Item {
            id: tabs
            width: parent.width
            height: Theme.pillHeight

            Row {
                anchors.left: parent.left
                anchors.right: refreshPill.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.tabs
                    Pill {
                        required property var modelData
                        accent: root.currentTab === modelData.id ? Theme.purple : Theme.muted
                        bordered: root.currentTab === modelData.id
                        onClicked: root.currentTab = modelData.id
                        Row {
                            spacing: Theme.iconGap
                            BarText {
                                text: modelData.glyph
                                color: root.currentTab === modelData.id ? Theme.purple : Theme.muted
                                font.family: Theme.iconFontFamily
                            }
                            BarText {
                                text: modelData.label
                                color: root.currentTab === modelData.id ? Theme.purple : Theme.muted
                            }
                        }
                    }
                }
            }

            Pill {
                id: refreshPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                accent: Telemetry.error !== "" ? Theme.red : Theme.cyan
                bordered: Telemetry.busy || Telemetry.error !== ""
                onClicked: Telemetry.refresh()
                BarText {
                    text: Telemetry.busy ? "\uf110" : "\uf021"
                    color: Telemetry.error !== "" ? Theme.red : Theme.cyan
                    font.family: Theme.iconFontFamily
                    RotationAnimation on rotation { running: Telemetry.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
            }
        }

        Rectangle { id: divider; width: parent.width; height: 1; color: Theme.edge(Theme.muted) }

        Flickable {
            id: scroll
            width: parent.width
            // Whatever the tabs and the divider leave. The 54 this replaces was
            // 5px more than they actually take, so the scroll area stopped short.
            height: stack.height - tabs.height - divider.height - stack.spacing * 2
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: scroll.width
                spacing: 10

                Column {
                    width: parent.width
                    spacing: 7
                    visible: root.currentTab === "overview"

                    SectionTitle { label: "At a glance"; tone: Theme.purple }
                    MetricRow {
                        label: "System"
                        value: `CPU ${Math.round(SysStats.cpuUsage * 100)}%  •  RAM ${Math.round(SysStats.memUsage * 100)}%  •  ${SysStats.tempC.toFixed(0)}°C`
                        tone: SysStats.tempC >= 85 ? Theme.red : Theme.fg
                    }
                    MetricRow {
                        label: "Battery"
                        value: root.battery?.isPresent ? `${root.batteryPercent}%  •  ${root.charging ? root.duration(root.battery.timeToFull) + " to full" : root.duration(root.battery.timeToEmpty) + " left"}` : "Desktop power"
                        tone: root.batteryPercent <= 15 && !root.charging ? Theme.red : root.charging ? Theme.green : Theme.fg
                    }
                    MetricRow {
                        label: "AI today"
                        value: `OpenAI ${root.money(Telemetry.today, "openai")}  •  Anthropic ${root.money(Telemetry.today, "anthropic")}`
                        tone: Theme.purple
                    }
                    MetricRow {
                        label: "Network"
                        value: `${SysStats.rate(SysStats.netRxRate)} down  •  ${SysStats.rate(SysStats.netTxRate)} up`
                        tone: Theme.green
                    }
                    MetricRow {
                        label: "Attention"
                        value: `${Telemetry.system.updates ?? 0} updates  •  ${(Telemetry.system.failedUserUnits ?? 0) + (Telemetry.system.failedSystemUnits ?? 0)} failed units  •  disk ${Telemetry.system.diskPercent ?? 0}%`
                        tone: ((Telemetry.system.failedUserUnits ?? 0) + (Telemetry.system.failedSystemUnits ?? 0)) > 0 ? Theme.red : Theme.fg
                    }

                    SectionTitle { label: "Quick actions"; tone: Theme.cyan }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: Commands.actions.filter(action => ["Quick settings", "System monitor TUI", "Notifications", "Clipboard history", "Focus mode", "Capture tools"].includes(action.name))
                            ActionTile { required property var modelData; action: modelData }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentTab === "ai"

                    SectionTitle { label: "AI usage and cost"; tone: Theme.purple }
                    BarText {
                        width: parent.width
                        text: "Provider invoices are authoritative. Subscription traffic is shown as $0 metered rather than assigned a fictional API price."
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }
                    SectionTitle { label: "Today"; tone: Theme.cyan }
                    MetricRow { label: "OpenAI"; value: root.providerLine(Telemetry.today, "openai"); tone: Theme.cyan }
                    MetricRow { label: "Anthropic"; value: root.providerLine(Telemetry.today, "anthropic"); tone: Theme.orange }
                    SectionTitle { label: "This week"; tone: Theme.cyan }
                    MetricRow { label: "OpenAI"; value: root.providerLine(Telemetry.week, "openai"); tone: Theme.cyan }
                    MetricRow { label: "Anthropic"; value: root.providerLine(Telemetry.week, "anthropic"); tone: Theme.orange }
                    SectionTitle { label: "This month"; tone: Theme.cyan }
                    MetricRow { label: "OpenAI"; value: root.providerLine(Telemetry.month, "openai"); tone: Theme.cyan }
                    MetricRow { label: "Anthropic"; value: root.providerLine(Telemetry.month, "anthropic"); tone: Theme.orange }

                    SectionTitle { label: "Most used models this month"; tone: Theme.purple }
                    Repeater {
                        model: [...(Telemetry.month.openai?.models ?? []), ...(Telemetry.month.anthropic?.models ?? [])].sort((a, b) => b.tokens - a.tokens).slice(0, 8)
                        MetricRow {
                            required property var modelData
                            label: modelData.name
                            value: `${Telemetry.tokens(modelData.tokens)} tokens`
                            tone: modelData.name.toLowerCase().includes("claude") ? Theme.orange : Theme.cyan
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentTab === "power"

                    SectionTitle { label: "Battery and power"; tone: Theme.green }
                    MetricRow { label: "State"; value: root.battery?.isPresent ? (root.charging ? "Charging" : "Discharging") : "No battery"; tone: root.charging ? Theme.green : Theme.fg }
                    MetricRow { label: "Charge"; value: `${root.batteryPercent}%`; tone: root.batteryPercent <= 15 ? Theme.red : Theme.green }
                    MetricRow { label: root.charging ? "Time to full" : "Time remaining"; value: root.duration(root.charging ? root.battery?.timeToFull : root.battery?.timeToEmpty); tone: Theme.cyan }
                    MetricRow { label: "Power rate"; value: `${Number(root.battery?.changeRate ?? 0).toFixed(1)} W`; tone: Theme.fg }
                    MetricRow { label: "Energy"; value: `${Number(root.battery?.energy ?? 0).toFixed(1)} / ${Number(root.battery?.energyCapacity ?? 0).toFixed(1)} Wh`; tone: Theme.fg }
                    MetricRow { label: "Battery health"; value: root.physicalBattery?.healthSupported ? `${root.batteryHealthPercent}%` : "Not reported"; tone: root.batteryHealthPercent < 70 ? Theme.red : root.batteryHealthPercent < 85 ? Theme.yellow : Theme.green }
                    BarMeter {
                        width: parent.width
                        visible: root.physicalBattery?.healthSupported ?? false
                        label: "Health compared with design capacity"
                        detail: `${root.batteryHealthPercent}%`
                        value: root.batteryHealthPercent / 100
                        accent: root.batteryHealthPercent < 70 ? Theme.red : root.batteryHealthPercent < 85 ? Theme.yellow : Theme.green
                        warnOnHigh: false
                    }

                    SectionTitle { label: "Power actions"; tone: Theme.cyan }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: [
                                { name: "Power saver", subtitle: "Reduce background power", glyph: "\uf06c", command: ["powerprofilesctl", "set", "power-saver"] },
                                { name: "Balanced", subtitle: "Normal desktop profile", glyph: "\uf24e", command: ["powerprofilesctl", "set", "balanced"] },
                                { name: "Performance", subtitle: "Prefer responsiveness", glyph: "\uf135", command: ["powerprofilesctl", "set", "performance"] },
                                { name: "Suspend", subtitle: "Sleep this system", glyph: "\uf186", command: ["systemctl", "suspend"] }
                            ]
                            ActionTile { required property var modelData; action: modelData }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentTab === "maintenance"

                    SectionTitle { label: "Maintenance"; tone: Theme.yellow }
                    MetricRow { label: "Package updates"; value: `${Telemetry.system.updates ?? 0}`; tone: (Telemetry.system.updates ?? 0) > 0 ? Theme.yellow : Theme.green }
                    MetricRow { label: "Root storage"; value: `${Telemetry.system.diskPercent ?? 0}% used  •  ${Telemetry.system.diskFreeGb ?? 0} GB free`; tone: (Telemetry.system.diskPercent ?? 0) >= 90 ? Theme.red : Theme.fg }
                    MetricRow { label: "Failed services"; value: `${Telemetry.system.failedSystemUnits ?? 0} system  •  ${Telemetry.system.failedUserUnits ?? 0} user`; tone: ((Telemetry.system.failedSystemUnits ?? 0) + (Telemetry.system.failedUserUnits ?? 0)) > 0 ? Theme.red : Theme.green }
                    MetricRow { label: "Backup service"; value: Telemetry.system.backup ?? "unknown"; tone: Telemetry.system.backup === "inactive" ? Theme.yellow : Theme.green }
                    MetricRow { label: "Telemetry checked"; value: `${Telemetry.updatedAt}${Telemetry.error ? "  •  " + Telemetry.error : ""}`; tone: Telemetry.error ? Theme.red : Theme.muted }

                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: Commands.actions.filter(action => ["Package updates", "System logs", "User service logs", "System monitor TUI", "Refresh desktop telemetry"].includes(action.name))
                            ActionTile { required property var modelData; action: modelData }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentTab === "security"

                    SectionTitle { label: "Security posture"; tone: Theme.red }
                    MetricRow { label: "Firewall"; value: Telemetry.system.firewall ?? "unknown"; tone: Telemetry.system.firewall === "inactive" ? Theme.red : Theme.green }
                    MetricRow { label: "VPN"; value: (Telemetry.system.vpn ?? []).length ? Telemetry.system.vpn.join(", ") : "Not connected"; tone: (Telemetry.system.vpn ?? []).length ? Theme.green : Theme.yellow }
                    MetricRow { label: "Login sessions"; value: `${Telemetry.system.loginSessions ?? 0}`; tone: (Telemetry.system.loginSessions ?? 0) > 1 ? Theme.yellow : Theme.fg }
                    MetricRow { label: "Failed system units"; value: `${Telemetry.system.failedSystemUnits ?? 0}`; tone: (Telemetry.system.failedSystemUnits ?? 0) > 0 ? Theme.red : Theme.green }
                    MetricRow { label: "Failed user units"; value: `${Telemetry.system.failedUserUnits ?? 0}`; tone: (Telemetry.system.failedUserUnits ?? 0) > 0 ? Theme.red : Theme.green }

                    BarText {
                        width: parent.width
                        text: "The card reports observable local posture. It does not claim that an active firewall or VPN alone makes the system secure."
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: Commands.actions.filter(action => ["Network TUI", "System logs", "User service logs", "Quick settings"].includes(action.name))
                            ActionTile { required property var modelData; action: modelData }
                        }
                    }
                }
            }
        }
    }
}
