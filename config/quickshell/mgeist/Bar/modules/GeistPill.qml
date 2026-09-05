// Suite entry point for the paged Geist application card.
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: GeistStatus.error !== "" ? Theme.red
        : GeistStatus.busy ? Theme.cyan : Theme.purple
    hoverTitle: "Geist applications"
    hoverDetail: `Calendar ${GeistStatus.calendar.status} • Todo ${GeistStatus.todo.status} • Brief ${GeistStatus.brief.status}\nVault ${GeistStatus.vault.status} • Contacts ${GeistStatus.contacts.status}\nClick: suite • right-click: vault`

    BarText {
        text: GeistStatus.busy ? "\uf110" : "\uf1b2"
        color: root.accent
        font.family: Theme.iconFontFamily
    }
}
