// Author: Jeff
// Description: Safe shared math parser/evaluator for launcher and calculator UIs.
// Notes: No eval or Function constructor. The module is presentation-independent
//        and also exposes graph samples for a future Canvas/graphing view.

// This file intentionally uses plain JavaScript declarations so Quickshell and
// the Node test harness can load the same implementation.

const FUNCTIONS = {
    abs: Math.abs,
    acos: Math.acos,
    asin: Math.asin,
    atan: Math.atan,
    ceil: Math.ceil,
    cos: Math.cos,
    exp: Math.exp,
    floor: Math.floor,
    ln: Math.log,
    log: Math.log10,
    max: Math.max,
    min: Math.min,
    round: Math.round,
    sin: Math.sin,
    sqrt: Math.sqrt,
    tan: Math.tan,
};

const CONSTANTS = {
    e: Math.E,
    pi: Math.PI,
    tau: Math.PI * 2,
};

function fail(message, position) {
    throw new Error(`${message} at character ${position}`);
}

function tokenize(source) {
    const tokens = [];
    let i = 0;
    while (i < source.length) {
        const c = source[i];
        if (/\s/.test(c)) { i += 1; continue; }
        if (/[0-9.]/.test(c)) {
            const match = source.slice(i).match(/^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/);
            if (!match) fail("invalid number", i);
            tokens.push({ kind: "number", value: Number(match[0]), position: i });
            i += match[0].length;
            continue;
        }
        if (/[A-Za-z_]/.test(c)) {
            const match = source.slice(i).match(/^[A-Za-z_]\w*/);
            tokens.push({ kind: "name", value: match[0].toLowerCase(), position: i });
            i += match[0].length;
            continue;
        }
        if ("+-*/%^(),!".includes(c)) {
            tokens.push({ kind: c, value: c, position: i });
            i += 1;
            continue;
        }
        fail(`unexpected character '${c}'`, i);
    }
    tokens.push({ kind: "eof", value: "", position: source.length });
    return tokens;
}

function factorial(value, position) {
    if (!Number.isFinite(value) || value < 0 || Math.floor(value) !== value) fail("factorial needs a non-negative integer", position);
    if (value > 170) fail("factorial is too large", position);
    let result = 1;
    for (let i = 2; i <= value; i += 1) result *= i;
    return result;
}

function toAngle(value, mode) { return mode === "degrees" ? value * Math.PI / 180 : value; }
function fromAngle(value, mode) { return mode === "degrees" ? value * 180 / Math.PI : value; }

function parse(source, options = {}) {
    const tokens = tokenize(source);
    let index = 0;
    const mode = options.angle === "degrees" ? "degrees" : "radians";
    const variable = options.variables || {};
    const peek = () => tokens[index];
    const take = kind => {
        if (peek().kind !== kind) fail(`expected '${kind}'`, peek().position);
        return tokens[index++];
    };

    function expression() {
        let value = term();
        while (peek().kind === "+" || peek().kind === "-") {
            const operator = tokens[index++].kind;
            const right = term();
            value = operator === "+" ? value + right : value - right;
        }
        return value;
    }

    function term() {
        let value = unary();
        while (peek().kind === "*" || peek().kind === "/" || peek().kind === "%") {
            const operator = tokens[index++].kind;
            const right = unary();
            if (operator === "*") value *= right;
            else if (operator === "/") {
                if (right === 0) fail("division by zero", peek().position);
                value /= right;
            } else value %= right;
        }
        return value;
    }

    function unary() {
        if (peek().kind === "+") { index += 1; return unary(); }
        if (peek().kind === "-") { index += 1; return -unary(); }
        return power();
    }

    function power() {
        let value = postfix();
        if (peek().kind === "^") {
            index += 1;
            value = Math.pow(value, unary());
        }
        return value;
    }

    function postfix() {
        let value = primary();
        while (peek().kind === "!") {
            value = factorial(value, tokens[index++].position);
        }
        return value;
    }

    function primary() {
        const token = peek();
        if (token.kind === "number") { index += 1; return token.value; }
        if (token.kind === "(") {
            index += 1;
            const value = expression();
            take(")");
            return value;
        }
        if (token.kind === "name") {
            index += 1;
            const name = token.value;
            if (peek().kind === "(") {
                index += 1;
                const args = [];
                if (peek().kind !== ")") {
                    args.push(expression());
                    while (peek().kind === ",") { index += 1; args.push(expression()); }
                }
                take(")");
                if (!FUNCTIONS[name]) fail(`unknown function '${name}'`, token.position);
                if (["min", "max"].includes(name) ? args.length < 1 : args.length !== 1) fail(`wrong argument count for '${name}'`, token.position);
                if (["sin", "cos", "tan"].includes(name)) return FUNCTIONS[name](toAngle(args[0], mode));
                if (["asin", "acos", "atan"].includes(name)) return fromAngle(FUNCTIONS[name](args[0]), mode);
                return FUNCTIONS[name].apply(null, args);
            }
            if (Object.prototype.hasOwnProperty.call(variable, name)) return Number(variable[name]);
            if (Object.prototype.hasOwnProperty.call(CONSTANTS, name)) return CONSTANTS[name];
            fail(`unknown name '${name}'`, token.position);
        }
        fail("expected a number, name, or parentheses", token.position);
    }

    const value = expression();
    if (peek().kind !== "eof") fail(`unexpected '${peek().value}'`, peek().position);
    if (!Number.isFinite(value)) fail("result is not finite", 0);
    return value;
}

function evaluate(source, options = {}) {
    const expression = String(source).trim().replace(/^y\s*=\s*/i, "");
    if (expression === "") throw new Error("empty expression");
    return parse(expression, options);
}

function sample(source, start = -10, end = 10, steps = 200, options = {}) {
    const count = Math.max(2, Math.min(5000, Math.floor(Number(steps))));
    const points = [];
    for (let i = 0; i < count; i += 1) {
        const x = Number(start) + (Number(end) - Number(start)) * i / (count - 1);
        try {
            const variables = Object.assign({}, options.variables || {}, { x });
            const y = evaluate(source, Object.assign({}, options, { variables }));
            points.push(Number.isFinite(y) ? { x, y } : { x, y: null });
        } catch (_) {
            points.push({ x, y: null });
        }
    }
    return points;
}

function format(value, digits = 12) {
    if (!Number.isFinite(value)) return "error";
    return Number(value.toPrecision(digits)).toString();
}
