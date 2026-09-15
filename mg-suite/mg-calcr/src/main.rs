use std::process::ExitCode;

use clap::{Parser, Subcommand, ValueEnum};
use mg_calcr::{AngleMode, EvalOptions, evaluate_formatted, sample_graph};
use serde::Serialize;

#[derive(Debug, Parser)]
#[command(
    name = "mg-calcr",
    about = "Safe local calculator core and graph sampler"
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Evaluate {
        expression: String,
        #[arg(long, value_enum, default_value_t = Angle::Radians)]
        angle: Angle,
        #[arg(long)]
        json: bool,
    },
    Sample {
        expression: String,
        #[arg(long, default_value_t = -10.0)]
        minimum: f64,
        #[arg(long, default_value_t = 10.0)]
        maximum: f64,
        #[arg(long, default_value_t = 240)]
        points: usize,
        #[arg(long, value_enum, default_value_t = Angle::Radians)]
        angle: Angle,
        #[arg(long)]
        json: bool,
    },
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum Angle {
    Radians,
    Degrees,
}

impl From<Angle> for AngleMode {
    fn from(angle: Angle) -> Self {
        match angle {
            Angle::Radians => Self::Radians,
            Angle::Degrees => Self::Degrees,
        }
    }
}

#[derive(Debug, Serialize)]
struct ErrorOutput {
    error: String,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match run(cli) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(2)
        }
    }
}

fn run(cli: Cli) -> Result<(), Box<dyn std::error::Error>> {
    match cli.command {
        Command::Evaluate {
            expression,
            angle,
            json,
        } => {
            match evaluate_formatted(
                &expression,
                EvalOptions {
                    angle: angle.into(),
                    variable_x: None,
                },
            ) {
                Ok(result) if json => println!("{}", serde_json::to_string(&result)?),
                Ok(result) => println!("{}", result.formatted),
                Err(error) if json => println!(
                    "{}",
                    serde_json::to_string(&ErrorOutput {
                        error: error.to_string()
                    })?
                ),
                Err(error) => return Err(error.into()),
            }
        }
        Command::Sample {
            expression,
            minimum,
            maximum,
            points,
            angle,
            json,
        } => {
            let result = sample_graph(&expression, minimum, maximum, points, angle.into())?;
            if json {
                println!("{}", serde_json::to_string(&result)?);
            } else {
                for point in result {
                    println!(
                        "{}\t{}",
                        point.x,
                        point.y.map_or_else(String::new, |value| value.to_string())
                    );
                }
            }
        }
    }
    Ok(())
}
