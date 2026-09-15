use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn evaluate_json_is_machine_readable() {
    let mut command = Command::cargo_bin("mg-calcr").expect("binary should build");
    command
        .args(["evaluate", "2 + 3 * 4", "--json"])
        .assert()
        .success()
        .stdout(predicate::str::contains(r#""value":14.0"#))
        .stdout(predicate::str::contains(r#""formatted":"14""#));
}

#[test]
fn invalid_expression_returns_json_error_without_panic() {
    let mut command = Command::cargo_bin("mg-calcr").expect("binary should build");
    command
        .args(["evaluate", "sin()", "--json"])
        .assert()
        .success()
        .stdout(predicate::str::contains(r#""error":"#));
}

#[test]
fn graph_json_preserves_requested_samples() {
    let mut command = Command::cargo_bin("mg-calcr").expect("binary should build");
    command
        .args([
            "sample",
            "x^2",
            "--minimum=-1",
            "--maximum",
            "1",
            "--points",
            "3",
            "--json",
        ])
        .assert()
        .success()
        .stdout(predicate::str::contains(r#""x":-1.0"#))
        .stdout(predicate::str::contains(r#""x":0.0,"#))
        .stdout(predicate::str::contains(r#""y":1.0"#));
}
