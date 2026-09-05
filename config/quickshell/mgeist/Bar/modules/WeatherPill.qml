// Weather status pill with a stable, interactive forecast/location card.
import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Weather.error !== "" ? Theme.red : Theme.cyan
    property bool cardOpen: false
    property bool cardHovered: false
    property bool pinned: false
    property bool settingsPage: false


    function closeCard() {
        showCard.stop();
        hideCard.stop();
        root.cardOpen = false;
        root.pinned = false;
    }

    function pinCard(showSettings) {
        showCard.stop();
        hideCard.stop();
        root.settingsPage = showSettings;
        const alreadyOpen = root.cardOpen;
        root.pinned = true;

        // PopupWindow.grabFocus is fixed when mapped. Remap a card that was
        // already visible from hover so outside-click dismissal is enabled.
        if (alreadyOpen) {
            root.cardOpen = false;
            Qt.callLater(() => root.cardOpen = true);
        } else {
            root.cardOpen = true;
        }
    }

    function icon(description) {
        const text = String(description || "").toLowerCase();
        if (text.includes("thunder") || text.includes("lightning")) return "\udb81\udd93"; // nf-md-weather_lightning
        if (text.includes("sleet") || text.includes("snowy rain")) return "\udb81\udd9f"; // nf-md-weather_snowy_rainy
        if (text.includes("snow")) return "\udb81\udd98";                                // nf-md-weather_snowy
        if (text.includes("heavy rain") || text.includes("pour")) return "\udb81\udd96"; // nf-md-weather_pouring
        if (text.includes("rain") || text.includes("drizzle")) return "\udb81\udd97";    // nf-md-weather_rainy
        if (text.includes("fog") || text.includes("mist")) return "\udb81\udd91";        // nf-md-weather_fog
        if (text.includes("partly") || text.includes("mostly cloudy")) return "\udb81\udd95"; // nf-md-weather_partly_cloudy
        if (text.includes("cloud") || text.includes("overcast")) return "\udb81\udd90";  // nf-md-weather_cloudy
        if (text.includes("wind")) return "\udb81\udd9d";                                // nf-md-weather_windy
        return "\udb81\udd99";                                                            // nf-md-weather_sunny
    }

    onClicked: {
        if (root.cardOpen && root.pinned) {
            root.closeCard();
        } else {
            root.pinCard(false);
        }
    }
    onRightClicked: root.pinCard(true)
    onHoveredChanged: {
        if (root.hovered) {
            hideCard.stop();
            showCard.restart();
        } else {
            showCard.stop();
            hideCard.restart();
        }
    }

    Timer { id: showCard; interval: 160; onTriggered: root.cardOpen = true }
    Timer {
        id: hideCard
        interval: 320
        onTriggered: if (!root.pinned && !root.hovered && !root.cardHovered) root.cardOpen = false
    }

    Connections {
        target: Weather
        function onCardOpenRequested() { root.pinCard(false); }
        function onSettingsOpenRequested() { root.pinCard(true); }
    }

    Row {
        spacing: Theme.iconGap
        BarText {
            text: Weather.busy && !Weather.current.tempF ? "\uf110" : root.icon(Weather.current.description)
            color: root.accent
            font.family: Theme.iconFontFamily
            RotationAnimation on rotation {
                running: Weather.busy && !Weather.current.tempF
                from: 0; to: 360; duration: 900; loops: Animation.Infinite
            }
        }
        BarText {
            text: `${Weather.current.tempF || "--"}°`
            color: root.accent
            font.family: Theme.fontFamily
        }
    }

    PopupWindow {
        id: card
        anchor.item: root
        anchor.rect.x: -(implicitWidth - root.width) / 2
        anchor.rect.y: root.height + Theme.barMargin
        visible: root.cardOpen
        grabFocus: root.pinned
        implicitWidth: 390
        implicitHeight: panel.implicitHeight + 8
        color: "transparent"
        onVisibleChanged: if (!visible && root.cardOpen) root.closeCard()

        Rectangle {
            id: panel
            anchors.fill: parent
            anchors.margins: 4
            implicitHeight: body.implicitHeight + 24
            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.edge(root.accent)

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onContainsMouseChanged: {
                    root.cardHovered = containsMouse;
                    if (containsMouse) hideCard.stop(); else hideCard.restart();
                }
                onClicked: if (!root.pinned) root.pinCard(root.settingsPage)
            }

            Column {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 8
                    BarText {
                        width: parent.width - 76
                        text: root.settingsPage ? "Weather location" : Weather.location
                        color: root.accent
                        font.bold: true
                        font.pixelSize: Theme.fontSize + 2
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        width: 30; height: 26; radius: Theme.radius
                        color: settingsHit.containsMouse ? Qt.alpha(root.accent, 0.16) : "transparent"
                        border.width: 1; border.color: Theme.edge(root.accent)
                        BarText { anchors.centerIn: parent; text: root.settingsPage ? "\uf00c" : "\uf013"; color: root.accent; font.family: Theme.iconFontFamily }
                        MouseArea {
                            id: settingsHit
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const nextPage = !root.settingsPage;
                                // Settings contain text editors, so promote a
                                // hover-open card to a keyboard-focused popup
                                // before showing them.
                                if (!root.pinned) root.pinCard(nextPage);
                                else root.settingsPage = nextPage;
                            }
                        }
                    }
                    Rectangle {
                        width: 30; height: 26; radius: Theme.radius
                        color: refreshHit.containsMouse ? Qt.alpha(Theme.cyan, 0.16) : "transparent"
                        border.width: 1; border.color: Theme.edge(Theme.cyan)
                        BarText { anchors.centerIn: parent; text: Weather.busy ? "\uf110" : "\uf021"; color: Theme.cyan; font.family: Theme.iconFontFamily }
                        MouseArea { id: refreshHit; anchors.fill: parent; hoverEnabled: true; onClicked: Weather.refresh() }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: !root.settingsPage

                    Row {
                        width: parent.width
                        spacing: 12
                        BarText { text: root.icon(Weather.current.description); color: root.accent; font.family: Theme.iconFontFamily; font.pixelSize: 34 }
                        Column {
                            width: parent.width - 58
                            BarText { text: `${Weather.current.tempF || "--"}°F  •  ${Weather.current.description || "Unavailable"}`; color: Theme.fg; font.bold: true }
                            BarText { text: `Feels ${Weather.current.feelsF || "--"}°  •  Humidity ${Weather.current.humidity || "--"}%  •  ${Weather.current.windDir || ""} ${Weather.current.windMph || "--"} mph`; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.edge(Theme.muted) }
                    Repeater {
                        model: Weather.forecast
                        Row {
                            required property var modelData
                            width: parent.width
                            height: 26
                            BarText { width: 92; text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd MMM d"); color: Theme.muted }
                            BarText { width: 46; text: root.icon(modelData.description); color: root.accent; font.family: Theme.iconFontFamily }
                            BarText { width: 105; text: `${modelData.highF}° / ${modelData.lowF}°`; color: Theme.fg }
                            BarText { width: parent.width - 243; text: `${String(modelData.description).trim()} • ${modelData.chanceRain}%`; color: Theme.muted; elide: Text.ElideRight }
                        }
                    }
                    BarText {
                        width: parent.width
                        text: Weather.error !== "" ? Weather.error : `${Weather.mode === "ip" ? "Approximate location by IP" : Weather.mode === "query" ? "Fixed city/ZIP" : "Fixed coordinates"} • ${Weather.provider} • updated ${Weather.updatedAt || "—"}`
                        color: Weather.error !== "" ? Theme.red : Theme.faint
                        font.pixelSize: Theme.fontSize - 2
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.settingsPage

                    BarText { text: "Default"; color: Theme.muted; font.bold: true }
                    Rectangle {
                        width: parent.width; height: 34; radius: Theme.radius
                        color: ipHit.containsMouse || Weather.mode === "ip" ? Qt.alpha(Theme.cyan, 0.14) : "transparent"
                        border.width: 1; border.color: Theme.edge(Weather.mode === "ip" ? Theme.cyan : Theme.muted)
                        BarText { anchors.centerIn: parent; text: "Use approximate location from IP"; color: Weather.mode === "ip" ? Theme.cyan : Theme.fg }
                        MouseArea { id: ipHit; anchors.fill: parent; hoverEnabled: true; onClicked: Weather.setByIp() }
                    }

                    BarText { text: "Optional fixed city or ZIP"; color: Theme.muted; font.bold: true }
                    Row {
                        width: parent.width; spacing: 8
                        Rectangle {
                            width: parent.width - 80; height: 34; radius: Theme.radius
                            color: Theme.surface; border.width: 1; border.color: Theme.edge(Theme.muted)
                            BarText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; visible: queryInput.text === ""; text: "City or ZIP"; color: Theme.faint }
                            TextInput {
                                id: queryInput
                                anchors.fill: parent
                                anchors.margins: 8
                                // Keep the editor as the source of truth while
                                // typing. Feeding every keystroke back through
                                // another bound property resets selection and
                                // cursor state in Qt's TextInput.
                                text: Weather.query
                                onAccepted: Weather.setQuery(text)
                                activeFocusOnPress: true
                                selectByMouse: true
                                color: Theme.fg
                                selectionColor: Theme.edge(Theme.cyan)
                                selectedTextColor: Theme.fg
                                font.family: Theme.fontFamily
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                            }
                        }
                        Rectangle {
                            width: 72; height: 34; radius: Theme.radius; color: queryHit.containsMouse ? Qt.alpha(Theme.cyan, 0.14) : "transparent"; border.width: 1; border.color: Theme.edge(Theme.cyan)
                            BarText { anchors.centerIn: parent; text: "Apply"; color: Theme.cyan }
                            MouseArea { id: queryHit; anchors.fill: parent; hoverEnabled: true; onClicked: Weather.setQuery(queryInput.text) }
                        }
                    }

                    BarText { text: "Optional fixed coordinates"; color: Theme.muted; font.bold: true }
                    Row {
                        width: parent.width; spacing: 8
                        Rectangle {
                            width: 118; height: 34; radius: Theme.radius
                            color: Theme.surface; border.width: 1; border.color: Theme.edge(Theme.muted)
                            BarText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; visible: latitudeInput.text === ""; text: "Latitude"; color: Theme.faint }
                            TextInput {
                                id: latitudeInput
                                anchors.fill: parent; anchors.margins: 8
                                text: Weather.latitude
                                onAccepted: longitudeInput.forceActiveFocus()
                                activeFocusOnPress: true
                                selectByMouse: true
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                color: Theme.fg; selectionColor: Theme.edge(Theme.cyan); selectedTextColor: Theme.fg
                                font.family: Theme.fontFamily
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                            }
                        }
                        Rectangle {
                            width: 118; height: 34; radius: Theme.radius
                            color: Theme.surface; border.width: 1; border.color: Theme.edge(Theme.muted)
                            BarText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; visible: longitudeInput.text === ""; text: "Longitude"; color: Theme.faint }
                            TextInput {
                                id: longitudeInput
                                anchors.fill: parent; anchors.margins: 8
                                text: Weather.longitude
                                onAccepted: Weather.setCoordinates(latitudeInput.text, text)
                                activeFocusOnPress: true
                                selectByMouse: true
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                color: Theme.fg; selectionColor: Theme.edge(Theme.cyan); selectedTextColor: Theme.fg
                                font.family: Theme.fontFamily
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                            }
                        }
                        Rectangle {
                            width: parent.width - 252; height: 34; radius: Theme.radius; color: coordsHit.containsMouse ? Qt.alpha(Theme.cyan, 0.14) : "transparent"; border.width: 1; border.color: Theme.edge(Theme.cyan)
                            BarText { anchors.centerIn: parent; text: "Apply"; color: Theme.cyan }
                            MouseArea { id: coordsHit; anchors.fill: parent; hoverEnabled: true; onClicked: Weather.setCoordinates(latitudeInput.text, longitudeInput.text) }
                        }
                    }
                    BarText { width: parent.width; text: "The by-IP mode sends no configured address. Fixed modes persist only in Quickshell state and are sent to the same weather provider."; color: Theme.faint; wrapMode: Text.WordWrap; font.pixelSize: Theme.fontSize - 2 }
                }
            }
        }
    }
}
