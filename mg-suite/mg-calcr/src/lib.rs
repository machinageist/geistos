use std::fmt;

use serde::Serialize;
use thiserror::Error;

pub const MAX_GRAPH_POINTS: usize = 5_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AngleMode {
    Radians,
    Degrees,
}

impl AngleMode {
    #[must_use]
    pub fn from_name(name: &str) -> Self {
        if name.eq_ignore_ascii_case("degrees") || name.eq_ignore_ascii_case("deg") {
            Self::Degrees
        } else {
            Self::Radians
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct EvalOptions {
    pub angle: AngleMode,
    pub variable_x: Option<f64>,
}

impl Default for EvalOptions {
    fn default() -> Self {
        Self {
            angle: AngleMode::Radians,
            variable_x: None,
        }
    }
}

#[derive(Debug, Error, Clone, PartialEq)]
pub enum CalcError {
    #[error("empty expression")]
    EmptyExpression,
    #[error("unexpected character '{character}' at character {position}")]
    UnexpectedCharacter { character: char, position: usize },
    #[error("expected {expected} at character {position}")]
    Expected { expected: String, position: usize },
    #[error("unknown name '{name}' at character {position}")]
    UnknownName { name: String, position: usize },
    #[error("unknown function '{name}' at character {position}")]
    UnknownFunction { name: String, position: usize },
    #[error("wrong argument count for '{name}' at character {position}")]
    WrongArgumentCount { name: String, position: usize },
    #[error("division by zero at character {position}")]
    DivisionByZero { position: usize },
    #[error("factorial needs a non-negative integer at character {position}")]
    InvalidFactorial { position: usize },
    #[error("factorial is too large at character {position}")]
    FactorialTooLarge { position: usize },
    #[error("result is not finite")]
    NonFinite,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct GraphPoint {
    pub x: f64,
    pub y: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Evaluation {
    pub value: f64,
    pub formatted: String,
}

#[derive(Debug, Clone, PartialEq)]
enum TokenKind {
    Number(f64),
    Name(String),
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Caret,
    LeftParen,
    RightParen,
    Comma,
    Bang,
    End,
}

#[derive(Debug, Clone, PartialEq)]
struct Token {
    kind: TokenKind,
    position: usize,
}

impl fmt::Display for TokenKind {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            Self::Number(_) => "a number",
            Self::Name(_) => "a name",
            Self::Plus => "'+'",
            Self::Minus => "'-'",
            Self::Star => "'*'",
            Self::Slash => "'/'",
            Self::Percent => "'%'",
            Self::Caret => "'^'",
            Self::LeftParen => "'('",
            Self::RightParen => "')'",
            Self::Comma => "','",
            Self::Bang => "'!'",
            Self::End => "the end of the expression",
        };
        formatter.write_str(name)
    }
}

fn tokenize(source: &str) -> Result<Vec<Token>, CalcError> {
    let mut tokens = Vec::new();
    let mut chars = source.char_indices().peekable();
    while let Some((position, character)) = chars.peek().copied() {
        if character.is_whitespace() {
            chars.next();
            continue;
        }
        let simple = match character {
            '+' => Some(TokenKind::Plus),
            '-' => Some(TokenKind::Minus),
            '*' => Some(TokenKind::Star),
            '/' => Some(TokenKind::Slash),
            '%' => Some(TokenKind::Percent),
            '^' => Some(TokenKind::Caret),
            '(' => Some(TokenKind::LeftParen),
            ')' => Some(TokenKind::RightParen),
            ',' => Some(TokenKind::Comma),
            '!' => Some(TokenKind::Bang),
            _ => None,
        };
        if let Some(kind) = simple {
            chars.next();
            tokens.push(Token { kind, position });
            continue;
        }
        if character.is_ascii_digit() || character == '.' {
            let start = position;
            let mut end = position;
            while let Some((index, value)) = chars.peek().copied() {
                if value.is_ascii_digit() || value == '.' {
                    end = index + value.len_utf8();
                    chars.next();
                } else {
                    break;
                }
            }
            if matches!(chars.peek().map(|(_, value)| *value), Some('e' | 'E')) {
                if let Some((index, value)) = chars.next() {
                    end = index + value.len_utf8();
                }
                if matches!(chars.peek().map(|(_, value)| *value), Some('+' | '-')) {
                    if let Some((index, value)) = chars.next() {
                        end = index + value.len_utf8();
                    }
                }
                while let Some((index, value)) = chars.peek().copied() {
                    if value.is_ascii_digit() {
                        end = index + value.len_utf8();
                        chars.next();
                    } else {
                        break;
                    }
                }
            }
            let text = &source[start..end];
            let value = text.parse::<f64>().map_err(|_| CalcError::Expected {
                expected: "a valid number".to_owned(),
                position: start,
            })?;
            tokens.push(Token {
                kind: TokenKind::Number(value),
                position: start,
            });
            continue;
        }
        if character.is_ascii_alphabetic() || character == '_' {
            let start = position;
            let mut end = position;
            while let Some((index, value)) = chars.peek().copied() {
                if value.is_ascii_alphanumeric() || value == '_' {
                    end = index + value.len_utf8();
                    chars.next();
                } else {
                    break;
                }
            }
            tokens.push(Token {
                kind: TokenKind::Name(source[start..end].to_ascii_lowercase()),
                position: start,
            });
            continue;
        }
        return Err(CalcError::UnexpectedCharacter {
            character,
            position,
        });
    }
    tokens.push(Token {
        kind: TokenKind::End,
        position: source.len(),
    });
    Ok(tokens)
}

struct Parser {
    tokens: Vec<Token>,
    index: usize,
    options: EvalOptions,
}

impl Parser {
    fn new(tokens: Vec<Token>, options: EvalOptions) -> Self {
        Self {
            tokens,
            index: 0,
            options,
        }
    }

    fn peek(&self) -> &Token {
        &self.tokens[self.index]
    }

    fn take(&mut self, expected: &TokenKind) -> Result<(), CalcError> {
        if std::mem::discriminant(&self.peek().kind) == std::mem::discriminant(expected) {
            self.index += 1;
            Ok(())
        } else {
            Err(CalcError::Expected {
                expected: expected.to_string(),
                position: self.peek().position,
            })
        }
    }

    fn expression(&mut self) -> Result<f64, CalcError> {
        let mut value = self.term()?;
        loop {
            let operator = match self.peek().kind {
                TokenKind::Plus => 1,
                TokenKind::Minus => -1,
                _ => break,
            };
            self.index += 1;
            let right = self.term()?;
            value += f64::from(operator) * right;
        }
        Ok(value)
    }

    fn term(&mut self) -> Result<f64, CalcError> {
        let mut value = self.unary()?;
        loop {
            let operator = self.peek().kind.clone();
            match operator {
                TokenKind::Star => {
                    self.index += 1;
                    value *= self.unary()?;
                }
                TokenKind::Slash => {
                    let position = self.peek().position;
                    self.index += 1;
                    let right = self.unary()?;
                    if right == 0.0 {
                        return Err(CalcError::DivisionByZero { position });
                    }
                    value /= right;
                }
                TokenKind::Percent => {
                    self.index += 1;
                    value %= self.unary()?;
                }
                _ => break,
            }
        }
        Ok(value)
    }

    fn unary(&mut self) -> Result<f64, CalcError> {
        match self.peek().kind {
            TokenKind::Plus => {
                self.index += 1;
                self.unary()
            }
            TokenKind::Minus => {
                self.index += 1;
                Ok(-self.unary()?)
            }
            _ => self.power(),
        }
    }

    fn power(&mut self) -> Result<f64, CalcError> {
        let value = self.postfix()?;
        if matches!(self.peek().kind, TokenKind::Caret) {
            self.index += 1;
            Ok(value.powf(self.unary()?))
        } else {
            Ok(value)
        }
    }

    fn postfix(&mut self) -> Result<f64, CalcError> {
        let mut value = self.primary()?;
        while matches!(self.peek().kind, TokenKind::Bang) {
            let position = self.peek().position;
            self.index += 1;
            if value < 0.0 || value.fract() != 0.0 || !value.is_finite() {
                return Err(CalcError::InvalidFactorial { position });
            }
            if value > 170.0 {
                return Err(CalcError::FactorialTooLarge { position });
            }
            let mut result = 1.0;
            let mut factor = 2.0;
            while factor <= value {
                result *= factor;
                factor += 1.0;
            }
            value = result;
        }
        Ok(value)
    }

    fn primary(&mut self) -> Result<f64, CalcError> {
        let token = self.peek().clone();
        match token.kind {
            TokenKind::Number(value) => {
                self.index += 1;
                Ok(value)
            }
            TokenKind::LeftParen => {
                self.index += 1;
                let value = self.expression()?;
                self.take(&TokenKind::RightParen)?;
                Ok(value)
            }
            TokenKind::Name(name) => {
                self.index += 1;
                if matches!(self.peek().kind, TokenKind::LeftParen) {
                    self.index += 1;
                    let mut args = Vec::new();
                    if !matches!(self.peek().kind, TokenKind::RightParen) {
                        args.push(self.expression()?);
                        while matches!(self.peek().kind, TokenKind::Comma) {
                            self.index += 1;
                            args.push(self.expression()?);
                        }
                    }
                    self.take(&TokenKind::RightParen)?;
                    apply_function(&name, &args, self.options.angle, token.position)
                } else {
                    match name.as_str() {
                        "e" => Ok(std::f64::consts::E),
                        "pi" => Ok(std::f64::consts::PI),
                        "tau" => Ok(std::f64::consts::TAU),
                        "x" => self.options.variable_x.ok_or(CalcError::UnknownName {
                            name,
                            position: token.position,
                        }),
                        _ => Err(CalcError::UnknownName {
                            name,
                            position: token.position,
                        }),
                    }
                }
            }
            _ => Err(CalcError::Expected {
                expected: "a value".to_owned(),
                position: token.position,
            }),
        }
    }
}

fn apply_function(
    name: &str,
    args: &[f64],
    angle: AngleMode,
    position: usize,
) -> Result<f64, CalcError> {
    let unary = |function: fn(f64) -> f64| {
        if args.len() == 1 {
            Ok(function(args[0]))
        } else {
            Err(CalcError::WrongArgumentCount {
                name: name.to_owned(),
                position,
            })
        }
    };
    let trig = |function: fn(f64) -> f64| {
        if args.len() == 1 {
            Ok(function(angle_to_radians(args[0], angle)))
        } else {
            Err(CalcError::WrongArgumentCount {
                name: name.to_owned(),
                position,
            })
        }
    };
    match name {
        "abs" => unary(f64::abs),
        "acos" => {
            if args.len() == 1 {
                Ok(angle_from_radians(args[0].acos(), angle))
            } else {
                Err(CalcError::WrongArgumentCount {
                    name: name.to_owned(),
                    position,
                })
            }
        }
        "asin" => {
            if args.len() == 1 {
                Ok(angle_from_radians(args[0].asin(), angle))
            } else {
                Err(CalcError::WrongArgumentCount {
                    name: name.to_owned(),
                    position,
                })
            }
        }
        "atan" => {
            if args.len() == 1 {
                Ok(angle_from_radians(args[0].atan(), angle))
            } else {
                Err(CalcError::WrongArgumentCount {
                    name: name.to_owned(),
                    position,
                })
            }
        }
        "ceil" => unary(f64::ceil),
        "cos" => trig(f64::cos),
        "exp" => unary(f64::exp),
        "floor" => unary(f64::floor),
        "ln" => unary(f64::ln),
        "log" => unary(f64::log10),
        "round" => unary(f64::round),
        "sin" => trig(f64::sin),
        "sqrt" => unary(f64::sqrt),
        "tan" => trig(f64::tan),
        "min" | "max" if !args.is_empty() => Ok(if name == "min" {
            args.iter().copied().fold(f64::INFINITY, f64::min)
        } else {
            args.iter().copied().fold(f64::NEG_INFINITY, f64::max)
        }),
        "min" | "max" => Err(CalcError::WrongArgumentCount {
            name: name.to_owned(),
            position,
        }),
        _ => Err(CalcError::UnknownFunction {
            name: name.to_owned(),
            position,
        }),
    }
}

fn angle_to_radians(value: f64, angle: AngleMode) -> f64 {
    match angle {
        AngleMode::Radians => value,
        AngleMode::Degrees => value.to_radians(),
    }
}

fn angle_from_radians(value: f64, angle: AngleMode) -> f64 {
    match angle {
        AngleMode::Radians => value,
        AngleMode::Degrees => value.to_degrees(),
    }
}

fn graph_expression_source(source: &str) -> &str {
    let trimmed = source.trim();
    if let Some((left, right)) = trimmed.split_once('=') {
        if left.trim().eq_ignore_ascii_case("y") {
            return right.trim();
        }
    }
    trimmed
}

/// Evaluate an expression using the supplied angle mode and optional `x` value.
///
/// # Errors
///
/// Returns a [`CalcError`] for invalid syntax, unknown names, invalid function
/// arity, division by zero, non-finite results, or invalid factorial input.
pub fn evaluate(source: &str, options: EvalOptions) -> Result<f64, CalcError> {
    if source.trim().is_empty() {
        return Err(CalcError::EmptyExpression);
    }
    let mut parser = Parser::new(tokenize(source)?, options);
    let value = parser.expression()?;
    if !matches!(parser.peek().kind, TokenKind::End) {
        return Err(CalcError::Expected {
            expected: "the end of the expression".to_owned(),
            position: parser.peek().position,
        });
    }
    if value.is_finite() {
        Ok(value)
    } else {
        Err(CalcError::NonFinite)
    }
}

/// Evaluate and format an expression for display.
///
/// # Errors
///
/// Returns the same [`CalcError`] variants as [`evaluate`].
pub fn evaluate_formatted(source: &str, options: EvalOptions) -> Result<Evaluation, CalcError> {
    let value = evaluate(source, options)?;
    Ok(Evaluation {
        value,
        formatted: format_value(value),
    })
}

#[must_use]
pub fn format_value(value: f64) -> String {
    if value == 0.0 {
        return "0".to_owned();
    }
    if value.fract() == 0.0 && value.abs() < 1e15 {
        return format!("{value:.0}");
    }
    let formatted = format!("{value:.12}");
    formatted
        .trim_end_matches('0')
        .trim_end_matches('.')
        .to_owned()
}

/// Sample a function across a finite x range.
///
/// Invalid or non-finite samples are represented as `None` so graph renderers
/// can preserve discontinuities without connecting unrelated segments.
///
/// # Errors
///
/// Returns a [`CalcError`] when the range is not finite or ordered, or when the
/// requested point count is outside `2..=MAX_GRAPH_POINTS`.
pub fn sample_graph(
    source: &str,
    minimum: f64,
    maximum: f64,
    count: usize,
    angle: AngleMode,
) -> Result<Vec<GraphPoint>, CalcError> {
    if !(2..=MAX_GRAPH_POINTS).contains(&count)
        || !minimum.is_finite()
        || !maximum.is_finite()
        || minimum >= maximum
    {
        return Err(CalcError::Expected {
            expected: format!("a valid graph range with between two and {MAX_GRAPH_POINTS} points"),
            position: 0,
        });
    }
    let source = graph_expression_source(source);
    let denominator = u32::try_from(count - 1).map_err(|_| CalcError::Expected {
        expected: format!("a graph with no more than {MAX_GRAPH_POINTS} points"),
        position: 0,
    })?;
    let step = (maximum - minimum) / f64::from(denominator);
    let mut points = Vec::with_capacity(count);
    for index in 0..=denominator {
        let x = minimum + step * f64::from(index);
        let y = evaluate(
            source,
            EvalOptions {
                angle,
                variable_x: Some(x),
            },
        )
        .ok();
        points.push(GraphPoint {
            x,
            y: y.filter(|value| value.is_finite()),
        });
    }
    Ok(points)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn evaluates_precedence_constants_and_functions() {
        assert!(
            (evaluate("2 + 3 * 4", EvalOptions::default()).unwrap() - 14.0).abs() < f64::EPSILON
        );
        assert!(
            (evaluate(
                "sin(90)",
                EvalOptions {
                    angle: AngleMode::Degrees,
                    variable_x: None
                }
            )
            .unwrap()
                - 1.0)
                .abs()
                < 1e-12
        );
        assert!((evaluate("5!", EvalOptions::default()).unwrap() - 120.0).abs() < f64::EPSILON);
    }

    #[test]
    fn reports_safe_errors() {
        assert!(matches!(
            evaluate("1 / 0", EvalOptions::default()),
            Err(CalcError::DivisionByZero { .. })
        ));
        assert!(matches!(
            evaluate("unknown", EvalOptions::default()),
            Err(CalcError::UnknownName { .. })
        ));
    }

    #[test]
    fn formats_and_samples() {
        assert_eq!(format_value(4.0), "4");
        let points = sample_graph("x^2", -1.0, 1.0, 5, AngleMode::Radians).unwrap();
        assert_eq!(points.len(), 5);
        assert_eq!(points[2].y, Some(0.0));
    }

    #[test]
    fn accepts_the_documented_graph_equation_prefix() {
        let points = sample_graph("Y = x^2", -1.0, 1.0, 3, AngleMode::Radians).unwrap();
        assert_eq!(
            points.iter().map(|point| point.y).collect::<Vec<_>>(),
            vec![Some(1.0), Some(0.0), Some(1.0)]
        );
    }

    #[test]
    fn refuses_impractically_large_graph_allocations() {
        assert_eq!(
            sample_graph("x", -1.0, 1.0, MAX_GRAPH_POINTS, AngleMode::Radians)
                .unwrap()
                .len(),
            MAX_GRAPH_POINTS
        );
        assert!(sample_graph("x", -1.0, 1.0, 5_001, AngleMode::Radians).is_err());
    }

    #[test]
    fn scalar_error_positions_stay_relative_to_the_original_expression() {
        assert_eq!(
            evaluate("   1 / 0", EvalOptions::default()),
            Err(CalcError::DivisionByZero { position: 5 })
        );
    }
}
