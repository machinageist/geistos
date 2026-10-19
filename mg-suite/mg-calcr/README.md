# mg-calcr

`mg-calcr` is the Rust-owned calculator core for the Geist workstation. It is
an independent suite application: expression parsing, safe evaluation,
formatting, angle handling, and graph sampling live here rather than in the
Quickshell UI.

## Current surface

- arithmetic, precedence, parentheses, constants, variables, functions, and
  factorials;
- radians and degrees for trigonometric functions;
- finite-result and division-by-zero validation;
- deterministic result formatting;
- graph expressions with either `y = expression` or a bare expression;
- graph sampling capped at 5,000 points, with `null` points for discontinuities
  or invalid samples;
- plain-text and JSON CLI output.

Examples:

```sh
cargo run -- evaluate '2 + 2'
cargo run -- evaluate --angle degrees 'sin(90)' --json
cargo run -- sample 'y = x^2' --minimum -10 --maximum 10 --points 240 --json
```

The production Quickshell launcher and dedicated calculator call this binary's
JSON interface. Development currently resolves it through `MG_CALCR_BIN` or the
checkout build artifact; installing a stable `PATH` binary remains packaging
work and is not solved by this crate.

## Verification

```sh
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets --all-features
cargo run -- evaluate '2 + 3 * 4'
cargo run -- sample 'x^2' --points 5 --json
```

## License

MIT. See `LICENSE`.
