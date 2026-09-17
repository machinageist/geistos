"""Small, dependency-free math engine for Geistos desktop consumers.

The evaluator accepts a deliberately limited Python-expression-shaped grammar,
then walks the parsed AST. It never executes arbitrary Python. QML and future
CLI/UI consumers should call this module or the geist-math command rather than
implementing expression semantics themselves.
"""
from __future__ import annotations

import ast
import math
import operator
import re
from dataclasses import dataclass
from typing import Callable, cast


class MathError(ValueError):
    """A user-facing parse or evaluation error."""


@dataclass(frozen=True)
class Sample:
    x: float
    y: float | None


_CONSTANTS = {"pi": math.pi, "e": math.e, "tau": math.tau}
_FUNCTIONS: dict[str, Callable[[float], float]] = {
    "abs": lambda value: float(abs(value)),
    "ceil": lambda value: float(math.ceil(value)),
    "cos": math.cos,
    "exp": math.exp,
    "floor": lambda value: float(math.floor(value)),
    "ln": math.log,
    "log": math.log10,
    "sqrt": math.sqrt,
    "tan": math.tan,
}

_BINOPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.Pow: operator.pow,
    ast.Mod: operator.mod,
}
_UNARYOPS = {ast.UAdd: operator.pos, ast.USub: operator.neg}


def _normalize(expression: str) -> str:
    text = expression.strip()
    if text.startswith("y=") or text.startswith("y ="):
        text = text.split("=", 1)[1].strip()
    if not text or len(text) > 512:
        raise MathError("expression is empty or too long")
    if "!" in text:
        text = re.sub(r"(\d+(?:\.\d+)?)!", r"factorial(\1)", text)
    text = text.replace("^", "**")
    text = re.sub(r"(?<![\w.])(\d+(?:\.\d+)?)%(?!\w)", r"(\1/100)", text)
    return text


def _function(name: str, angle_mode: str) -> Callable[..., float]:
    if name in {"sin", "cos", "tan"}:
        fn = getattr(math, name)
        if angle_mode == "degrees":
            return lambda value: fn(math.radians(value))
        return fn
    if name in {"asin", "acos", "atan"}:
        fn = getattr(math, name)
        if angle_mode == "degrees":
            return lambda value: math.degrees(fn(value))
        return fn
    if name in {"asin", "acos", "atan"}:
        return getattr(math, name)
    if name == "factorial":
        return lambda value: math.factorial(int(value)) if value >= 0 and value.is_integer() else (_ for _ in ()).throw(MathError("factorial requires a non-negative integer"))
    try:
        return _FUNCTIONS[name]
    except KeyError as exc:
        raise MathError(f"unknown function: {name}") from exc


def _evaluate(node: ast.AST, angle_mode: str, variables: dict[str, float]) -> float:
    if isinstance(node, ast.Expression):
        return _evaluate(node.body, angle_mode, variables)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return float(node.value)
    if isinstance(node, ast.Name):
        if node.id in variables:
            return float(variables[node.id])
        try:
            return _CONSTANTS[node.id]
        except KeyError as exc:
            raise MathError(f"unknown name: {node.id}") from exc
    if isinstance(node, ast.BinOp) and type(node.op) in _BINOPS:
        left = _evaluate(node.left, angle_mode, variables)
        right = _evaluate(node.right, angle_mode, variables)
        try:
            return float(_BINOPS[type(node.op)](left, right))
        except (ArithmeticError, OverflowError) as exc:
            raise MathError("invalid arithmetic") from exc
    if isinstance(node, ast.UnaryOp) and type(node.op) in _UNARYOPS:
        return float(_UNARYOPS[type(node.op)](_evaluate(node.operand, angle_mode, variables)))
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
        if node.keywords or len(node.args) > 2:
            raise MathError("unsupported function arguments")
        fn = _function(node.func.id, angle_mode)
        try:
            return float(fn(*[_evaluate(arg, angle_mode, variables) for arg in node.args]))
        except (ArithmeticError, ValueError, TypeError, OverflowError) as exc:
            if isinstance(exc, MathError):
                raise
            raise MathError("function domain error") from exc
    raise MathError("unsupported expression")


def evaluate(expression: str, *, angle_mode: str = "radians", variables: dict[str, float] | None = None) -> float:
    """Evaluate one expression using radians or degrees for trig functions."""
    if angle_mode not in {"radians", "degrees"}:
        raise MathError("angle mode must be radians or degrees")
    try:
        tree = ast.parse(_normalize(expression), mode="eval")
    except (SyntaxError, ValueError) as exc:
        raise MathError("invalid expression") from exc
    result = _evaluate(tree, angle_mode, variables or {})
    if not math.isfinite(result):
        raise MathError("result is not finite")
    return result


def sample(expression: str, start: float = -10.0, end: float = 10.0, steps: int = 401, *, angle_mode: str = "radians") -> list[Sample]:
    """Generate graph samples, returning None for invalid individual points."""
    if steps < 2 or steps > 10000 or not math.isfinite(start) or not math.isfinite(end) or start >= end:
        raise MathError("invalid graph range")
    values: list[Sample] = []
    for index in range(steps):
        x = start + (end - start) * index / (steps - 1)
        try:
            y = evaluate(expression, angle_mode=angle_mode, variables={"x": x})
            values.append(Sample(x, y if math.isfinite(y) else None))
        except MathError:
            values.append(Sample(x, None))
    return values
