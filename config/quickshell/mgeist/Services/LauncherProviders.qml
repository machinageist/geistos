// Author: Jeff
// Description: Shared launcher provider/result contract.
// Notes: Providers produce one result shape; the launcher owns presentation and
//        selection. New providers should add results here without changing the
//        launcher delegate or keyboard behavior.

pragma Singleton

import Quickshell

Singleton {
    id: root

    // Common result fields:
    // provider, kind, name, genericName, comment, keywords, icon, glyph,
    // entry/action/command. The presentation layer deliberately consumes the
    // existing name/genericName fields while the provider identity remains
    // available for future provider-specific actions.
    function applicationResults() {
        return DesktopEntries.applications.values
            .filter(entry => !entry.noDisplay)
            .map(entry => ({
                provider: "applications",
                kind: "application",
                name: entry.name,
                genericName: entry.genericName || "",
                comment: entry.comment || "",
                keywords: entry.keywords || [],
                icon: entry.icon,
                entry: entry
            }));
    }

    function commandResults() {
        return Commands.actions.map(action => ({
            provider: "commands",
            kind: "action",
            name: action.name,
            genericName: action.subtitle,
            comment: action.subtitle,
            keywords: `${action.tags} system action command`.split(" "),
            glyph: action.glyph,
            action: action
        }));
    }

    function score(entry, query) {
        if (query === "") return 0;
        const name = entry.name.toLowerCase();
        const generic = (entry.genericName || "").toLowerCase();
        const keywords = (entry.keywords || []).join(" ").toLowerCase();
        if (name.startsWith(query)) return 100 - name.length * 0.01;
        if (name.split(/[\s-]/).some(word => word.startsWith(query))) return 80;
        if (name.includes(query)) return 60;
        if (generic.includes(query)) return 40;
        if (keywords.includes(query)) return 20;
        return -1;
    }

    function calculatorResults() {
        if (MathProvider.result === null) return [];
        return [{
            provider: "calculator",
            kind: "calculator",
            name: `${MathProvider.result}`,
            genericName: `Calculator result for ${MathProvider.query}`,
            comment: "Press Enter to copy the result",
            keywords: ["calculator", "math", "result"],
            glyph: "\\uf1ec",
            value: `${MathProvider.result}`
        }];
    }

    function setQuery(text) {
        MathProvider.setQuery(text);
    }

    function results(text) {
        const query = text.trim().toLowerCase();
        const sourceActions = query === "" ? commandResults().slice(0, 6) : commandResults();
        return [...calculatorResults(), ...sourceActions, ...applicationResults()]
            .map(entry => ({ entry: entry, score: root.score(entry, query) }))
            .filter(item => item.score >= 0)
            .map(item => ({ entry: item.entry,
                score: item.score + (item.entry.provider === "commands" ? 5 : 0) }))
            .sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
            .slice(0, 60)
            .map(item => item.entry);
    }

    function activate(item) {
        if (!item) return;
        if (item.provider === "calculator") {
            Quickshell.clipboardText = item.value;
        } else if (item.provider === "commands") {
            Commands.run(item.action);
        } else if (item.provider === "applications") {
            if (item.entry.runInTerminal)
                Quickshell.execDetached(["ghostty", "-e", ...item.entry.command]);
            else
                Quickshell.execDetached(item.entry.command);
        }
    }
}
