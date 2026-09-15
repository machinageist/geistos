// Author: Jeff
// Description: Provider/result helpers shared by the launcher sources.

function result(fields) {
    return Object.assign({
        kind: "utility",
        name: "",
        genericName: "",
        comment: "",
        keywords: [],
        glyph: "\uf013",
        icon: "",
    }, fields);
}

function action(action) {
    return result({
        kind: "action",
        name: action.name,
        genericName: action.subtitle,
        comment: action.subtitle,
        keywords: `${action.tags} system action command`.split(" "),
        glyph: action.glyph,
        action,
    });
}

function application(entry) {
    return result({
        kind: "application",
        name: entry.name,
        genericName: entry.genericName || "",
        comment: entry.comment || "",
        keywords: entry.keywords || [],
        icon: entry.icon,
        entry,
    });
}

function calculator(query, MathEngine) {
    if (query === "") return null;
    try {
        const value = MathEngine.evaluate(query);
        const formatted = MathEngine.format(value);
        return result({
            kind: "calculator",
            name: formatted,
            genericName: `Calculator · ${query}`,
            comment: "Press Enter to copy result",
            keywords: ["calculator", "math", "arithmetic", "scientific"],
            glyph: "\uf1ec",
            value: formatted,
            expression: query,
        });
    } catch (_) {
        return null;
    }
}

function calculatorResult(query, formatted) {
    return result({
        kind: "calculator",
        name: formatted,
        genericName: `Calculator · ${query}`,
        comment: "Press Enter to copy result",
        keywords: ["calculator", "math", "arithmetic", "scientific"],
        glyph: "\uf1ec",
        value: formatted,
        expression: query,
    });
}

function unitConversion(query, MathEngine) {
    const match = String(query).toLowerCase().match(/^\s*(-?(?:\d+(?:\.\d*)?|\.\d+))\s*([a-z°]+)\s+(?:to|in)\s+([a-z°]+)\s*$/);
    if (!match) return null;
    const aliases = {
        c: "c", celsius: "c", cm: "cm", ft: "ft", f: "f", fahrenheit: "f",
        g: "g", in: "in", inch: "in", inches: "in", kg: "kg", km: "km",
        lb: "lb", lbs: "lb", m: "m", mi: "mi", mile: "mi", miles: "mi",
        mm: "mm", oz: "oz", yd: "yd",
    };
    const from = aliases[match[2]];
    const to = aliases[match[3]];
    if (!from || !to) return null;
    const value = Number(match[1]);
    let resultValue;
    const temperature = ["c", "f"];
    if (temperature.includes(from) || temperature.includes(to)) {
        if (!temperature.includes(from) || !temperature.includes(to)) return null;
        const celsius = from === "f" ? (value - 32) * 5 / 9 : value;
        resultValue = to === "f" ? celsius * 9 / 5 + 32 : celsius;
    } else {
        const factors = { mm: 0.001, cm: 0.01, m: 1, km: 1000, in: 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344,
            g: 0.001, kg: 1, oz: 0.028349523125, lb: 0.45359237 };
        if (factors[from] === undefined || factors[to] === undefined) return null;
        const lengthUnits = ["mm", "cm", "m", "km", "in", "ft", "yd", "mi"];
        const massUnits = ["g", "kg", "oz", "lb"];
        if ((lengthUnits.includes(from) !== lengthUnits.includes(to)) || (massUnits.includes(from) !== massUnits.includes(to))) return null;
        resultValue = value * factors[from] / factors[to];
    }
    const formatted = MathEngine.format(resultValue);
    return result({
        kind: "converter",
        name: `${formatted} ${to}`,
        genericName: `Unit conversion · ${query}`,
        comment: "Press Enter to copy result",
        keywords: ["convert", "conversion", "units", from, to],
        glyph: "\uf1ec",
        value: `${formatted} ${to}`,
    });
}

function lexicalLookup(query) {
    const match = String(query).trim().match(/^(define|definition|synonym|synonyms|thesaurus)\s+(.+)$/i);
    if (!match) return null;
    const command = match[1].toLowerCase();
    const kind = command === "synonym" || command === "synonyms" || command === "thesaurus" ? "thesaurus" : "dictionary";
    const word = match[2].trim();
    if (word === "") return null;
    return result({
        kind: "lookup",
        name: kind === "dictionary" ? `Define ${word}` : `Synonyms for ${word}`,
        genericName: kind === "dictionary" ? "Dictionary lookup" : "Thesaurus lookup",
        comment: "Press Enter to look up",
        keywords: [kind, "word", "language", word.toLowerCase()],
        glyph: "\uf02d",
        lookupType: kind,
        lookupQuery: word,
    });
}

function score(entry, query) {
    if (entry.kind === "calculator" || entry.kind === "converter" || entry.kind === "lookup") return 120;
    if (query === "") return entry.kind === "action" ? 5 : 0;
    const name = entry.name.toLowerCase();
    const generic = (entry.genericName || "").toLowerCase();
    const keywords = (entry.keywords || []).join(" ").toLowerCase();
    if (name.startsWith(query)) return 100 - name.length * 0.01;
    if (name.split(/[\\s-]/).some(word => word.startsWith(query))) return 80;
    if (name.includes(query)) return 60;
    if (generic.includes(query)) return 40;
    if (keywords.includes(query)) return 20;
    return -1;
}

function search(sources, query, limit = 60) {
    return sources
        .map(entry => ({ entry, score: score(entry, query) }))
        .filter(item => item.score >= 0)
        .sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
        .slice(0, limit)
        .map(item => item.entry);
}
