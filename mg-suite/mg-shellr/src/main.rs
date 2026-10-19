use std::env;
use std::io::{self, Write};
use std::path::Path;
use std::process::Command;

fn main() {
    loop {
        // -----------------------------------------------------------------
        // Prompt
        // -----------------------------------------------------------------

        print!("rust-shell> ");

        if let Err(e) = io::stdout().flush() {
            eprintln!("Error flushing stdout: {}", e);
            continue;
        }

        // -----------------------------------------------------------------
        // Read command line
        // -----------------------------------------------------------------

        let mut input = String::new();

        match io::stdin().read_line(&mut input) {
            Ok(0) => {
                // EOF / Ctrl-D
                break;
            }

            Ok(_) => {}

            Err(e) => {
                eprintln!("Error reading input: {}", e);
                continue;
            }
        }

        let input = input.trim();

        if input.is_empty() {
            continue;
        }

        // -----------------------------------------------------------------
        // Basic argument parsing
        // -----------------------------------------------------------------

        let mut parts = input.split_whitespace();

        let Some(command) = parts.next() else {
            continue;
        };

        let args: Vec<&str> = parts.collect();

        // -----------------------------------------------------------------
        // Built-ins
        // -----------------------------------------------------------------

        match command {
            "exit" => {
                break;
            }

            "cd" => {
                let new_dir = match args.first() {
                    Some(path) => (*path).to_string(),

                    None => match env::var("HOME") {
                        Ok(home) => home,
                        Err(_) => "/".to_string(),
                    },
                };

                let path = Path::new(&new_dir);

                if let Err(e) = env::set_current_dir(path) {
                    eprintln!("cd: {}: {}", new_dir, e);
                }
            }

            // -----------------------------------------------------------------
            // External commands
            // -----------------------------------------------------------------
            external_cmd => match Command::new(external_cmd).args(&args).spawn() {
                Ok(mut child) => {
                    if let Err(e) = child.wait() {
                        eprintln!("Command failed during execution: {}", e);
                    }
                }

                Err(e) if e.kind() == io::ErrorKind::NotFound => {
                    eprintln!("{}: command not found.", external_cmd);
                }

                Err(e) => {
                    eprintln!("Failed to execute process: {}", e);
                }
            },
        }
    }
}
