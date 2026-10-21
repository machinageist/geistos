// Author: Jeff
// Date: 2026-09-19
// Description: mg-bookr command line — scan the book folders, list, progress, highlights, collections
// Notes: `--json` works everywhere; with it a failure is still JSON on stdout
//        ({"ok":false,"error":…}, exit 1), like the other suite tools the shell reads.
//        Reading happens in the reader window and listening through the audio commands; this
//        is the library's front desk

use std::process::ExitCode;

use anyhow::{Context, Result, bail};
use clap::{Parser, Subcommand};
use serde_json::json;

use mg_bookr::store::{self, Book, BookRecord, BookSort, BookStatus, Store};
use mg_bookr::terminal_text::sanitize_terminal_text;
use mg_bookr::{import, listen, reader, scan, vault, watcher};

const DEFAULT_CONTINUE: usize = 12;

#[derive(Parser)]
#[command(
    name = "mg-bookr",
    version,
    about = "Ebooks and audiobooks for the Geist suite"
)]
struct Cli {
    /// Print JSON instead of text
    #[arg(long, global = true)]
    json: bool,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Look through ~/books and ~/audiobooks and record what is there
    Scan {
        /// Re-read metadata even when a stored file fingerprint is unchanged
        #[arg(long)]
        force: bool,
    },
    /// Every book (by kind: epub, pdf, comic, audio)
    List {
        #[arg(long)]
        kind: Option<String>,
        /// Include books whose files have gone missing
        #[arg(long)]
        missing: bool,
        /// Order the library without changing its default recent-first order
        #[arg(long, value_enum, default_value = "recent")]
        sort: SortBy,
        /// Limit results to one global reading status
        #[arg(long, value_enum)]
        status: Option<BookStatus>,
    },
    /// Find books by title, author, series, or library path
    Search {
        text: String,
        #[arg(long)]
        kind: Option<String>,
        /// Include books whose files have gone missing
        #[arg(long)]
        missing: bool,
        #[arg(long, default_value_t = 100)]
        limit: usize,
        #[arg(long, value_enum, default_value = "recent")]
        sort: SortBy,
        /// Limit results to one global reading status
        #[arg(long, value_enum)]
        status: Option<BookStatus>,
    },
    /// Books started and not finished, most recent first
    Continue {
        #[arg(long, default_value_t = DEFAULT_CONTINUE)]
        limit: usize,
    },
    /// One book with its tracks, chapters and highlights
    Show { id: i64 },
    /// Everything the reader window or player needs to open a book (unpacks EPUBs and comics)
    Read { id: i64 },
    /// Record where you are in a book
    Progress {
        id: i64,
        location: String,
        percent: f64,
        #[arg(long, conflicts_with = "unfinished")]
        finished: bool,
        #[arg(long)]
        unfinished: bool,
    },
    Highlight {
        #[command(subcommand)]
        action: HighlightAction,
    },
    Collection {
        #[command(subcommand)]
        action: CollectionAction,
    },
    /// Reading lists: all of them, one in order, or a book from one (open <n> or next)
    Lists {
        /// A list to show
        name: Option<String>,
        /// open <n>: the book at place n; next: the first one not finished
        #[arg(value_enum)]
        action: Option<ListMove>,
        /// The book's place in the list, from 1
        position: Option<usize>,
    },
    /// Read or change global book status
    Status {
        #[command(subcommand)]
        action: StatusAction,
    },
    /// Run a recursive filesystem watcher until stopped (JSON lines on stdout)
    Watch {
        /// Quiet time before coalesced changes trigger a scan (50–5000 ms)
        #[arg(long, default_value_t = 500, value_parser = clap::value_parser!(u64).range(50..=5000))]
        debounce_ms: u64,
    },
    /// Write a book's highlights into mg-vault as one Markdown note (done after every highlight change too)
    Export { id: i64 },
    /// Open a book in the reader window
    Open { id: i64 },
    /// How a book is read: pages or scroll (with no words, it says which)
    Mode { id: i64, mode: Option<String> },
    /// The library in the terminal
    Tui,
    /// Audiobooks: play, pause, seek, speed, chapters and the sleep timer
    Listen {
        #[command(subcommand)]
        action: ListenAction,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, clap::ValueEnum)]
enum ListMove {
    /// The book at a place in the list
    Open,
    /// The first book in list order that is not finished
    Next,
}

#[derive(Clone, Copy, Debug, clap::ValueEnum)]
enum SortBy {
    Recent,
    Title,
    Author,
    Series,
}

impl From<SortBy> for BookSort {
    fn from(value: SortBy) -> Self {
        match value {
            SortBy::Recent => BookSort::Recent,
            SortBy::Title => BookSort::Title,
            SortBy::Author => BookSort::Author,
            SortBy::Series => BookSort::Series,
        }
    }
}

#[derive(Subcommand)]
enum ListenAction {
    /// Play a book from where you left it (or from --at track:seconds)
    Play {
        id: i64,
        #[arg(long)]
        at: Option<String>,
        /// 0.75 to 3; the book remembers it
        #[arg(long)]
        speed: Option<f64>,
    },
    /// What is playing
    Now,
    Pause,
    Resume,
    Toggle,
    /// Move within the track: 90, 1:02:03, +30 or -10
    Seek {
        #[arg(allow_hyphen_values = true)]
        time: String,
    },
    /// 0.75 to 3, pitch kept; the book remembers it
    Speed {
        speed: f64,
    },
    /// next, prev or a number from 1 (tracks when the file has no chapters)
    Chapter {
        which: String,
    },
    /// Stop after this many minutes, at the end of the chapter, or not: 30, chapter, off
    Sleep {
        when: String,
    },
    /// Stop listening; the place is saved
    Stop,
    /// One listening session: owns mpv and keeps the place (started by play)
    #[command(hide = true)]
    Session {
        id: i64,
        #[arg(long)]
        at: Option<String>,
        #[arg(long)]
        speed: Option<f64>,
    },
}

#[derive(Subcommand)]
enum HighlightAction {
    Add {
        book: i64,
        location: String,
        quote: String,
        #[arg(long)]
        chapter: Option<String>,
        #[arg(long)]
        note: Option<String>,
        #[arg(long, default_value = "yellow")]
        color: String,
    },
    List {
        book: i64,
    },
    /// Change a highlight's note (an empty note clears it)
    Note {
        id: i64,
        text: String,
    },
    Remove {
        id: i64,
    },
}

#[derive(Subcommand)]
enum CollectionAction {
    Create {
        name: String,
    },
    Rename {
        name: String,
        new_name: String,
    },
    Delete {
        name: String,
    },
    List,
    Show {
        name: String,
        #[arg(long, value_enum, default_value = "manual")]
        sort: CollectionOrder,
    },
    Add {
        name: String,
        book: i64,
    },
    Remove {
        name: String,
        book: i64,
    },
    AddMany {
        name: String,
        books: Vec<i64>,
    },
    RemoveMany {
        name: String,
        books: Vec<i64>,
    },
    Reorder {
        name: String,
        book: i64,
        position: usize,
    },
    /// Make a folder of books (and symlinks to books) a list named after it; new books are
    /// filed into ~/books/texts/<subject>/ under the library's naming and linked back
    Import {
        dir: std::path::PathBuf,
        /// Subject folder for new books (default: where most of the list already is)
        #[arg(long)]
        subject: Option<String>,
        /// Say what would happen and change nothing
        #[arg(long)]
        dry_run: bool,
    },
}

#[derive(Subcommand)]
enum StatusAction {
    Get { book: i64 },
    Set { book: i64, status: BookStatus },
    Bulk { status: BookStatus, books: Vec<i64> },
}

#[derive(Clone, Copy, Debug, clap::ValueEnum)]
enum CollectionOrder {
    Manual,
    Title,
}

impl From<CollectionOrder> for store::CollectionSort {
    fn from(value: CollectionOrder) -> Self {
        match value {
            CollectionOrder::Manual => store::CollectionSort::Manual,
            CollectionOrder::Title => store::CollectionSort::Title,
        }
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let json = cli.json || matches!(&cli.command, Command::Watch { .. });
    match run(cli) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            if json {
                println!("{}", json!({ "ok": false, "error": format!("{e:#}") }));
            } else {
                eprintln!("mg-bookr: {}", sanitize_terminal_text(&format!("{e:#}")));
            }
            ExitCode::FAILURE
        }
    }
}

fn run(cli: Cli) -> Result<()> {
    let json = cli.json;
    let store = Store::open(store::default_path())?;
    match cli.command {
        Command::Scan { force } => {
            let report = scan::scan_with_force(
                &store,
                &scan::default_roots(),
                &scan::default_cover_dir(),
                force,
            )?;
            if json {
                println!("{}", serde_json::to_string(&report)?);
            } else {
                println!(
                    "{} books: {} new, {} updated, {} unchanged, {} missing",
                    report.found, report.added, report.updated, report.unchanged, report.missing
                );
                for (path, why) in &report.unreadable {
                    println!(
                        "  could not read {}: {}",
                        sanitize_terminal_text(path),
                        sanitize_terminal_text(why)
                    );
                }
                for diagnostic in &report.diagnostics {
                    println!("  incomplete: {}", sanitize_terminal_text(diagnostic));
                }
            }
        }
        Command::List {
            kind,
            missing,
            sort,
            status,
        } => books(
            json,
            &store,
            &store.books_sorted(kind.as_deref(), missing, sort.into())?,
            status,
        )?,
        Command::Search {
            text,
            kind,
            missing,
            limit,
            sort,
            status,
        } => books(
            json,
            &store,
            &store.search_books(&text, kind.as_deref(), missing, sort.into(), limit)?,
            status,
        )?,
        Command::Continue { limit } => books(json, &store, &store.in_progress(limit)?, None)?,
        Command::Show { id } => {
            let book = store.book(id)?;
            let tracks = store.tracks(id)?;
            let chapters = store.chapters(id)?;
            let highlights = store.highlights(id)?;
            if json {
                println!(
                    "{}",
                    json!({ "book": store.book_record(id)?, "tracks": tracks, "chapters": chapters, "highlights": highlights })
                );
            } else {
                println!("{}", line(&book));
                for (title, start) in &chapters {
                    println!("  {:>8}  {}", clock(*start), sanitize_terminal_text(title));
                }
                for h in &highlights {
                    println!(
                        "  \u{201c}{}\u{201d}{}",
                        sanitize_terminal_text(&h.quote),
                        h.note.as_ref().map_or(String::new(), |n| {
                            format!(" \u{2014} {}", sanitize_terminal_text(n))
                        })
                    );
                }
            }
        }
        Command::Read { id } => {
            let plan = reader::plan(
                &store,
                id,
                &scan::default_roots(),
                &reader::default_unpack_dir(),
            )?;
            store.mark_opened(id)?;
            if json {
                let mut value = serde_json::to_value(&plan)?;
                value["book"] = serde_json::to_value(store.book_record(id)?)?;
                println!("{value}");
            } else {
                println!(
                    "{}  {}",
                    line(&plan.book),
                    sanitize_terminal_text(&plan.file)
                );
                if let Some(e) = &plan.epub {
                    println!(
                        "  {} pages, {} contents entries, unpacked in {}",
                        e.spine.len(),
                        e.toc.len(),
                        e.dir
                    );
                }
                if !plan.pages.is_empty() {
                    println!("  {} comic pages", plan.pages.len());
                }
            }
        }
        Command::Progress {
            id,
            location,
            percent,
            finished,
            unfinished,
        } => {
            let flag = if finished {
                Some(true)
            } else if unfinished {
                Some(false)
            } else {
                None
            };
            store.set_progress(id, &location, percent, flag)?;
            done(
                json,
                json!({ "ok": true, "book": store.book_record(id)? }),
                format!("saved: {percent:.1}%"),
            );
        }
        Command::Highlight { action } => match action {
            HighlightAction::Add {
                book,
                location,
                quote,
                chapter,
                note,
                color,
            } => {
                let id = store.add_highlight(
                    book,
                    &location,
                    chapter.as_deref(),
                    &quote,
                    note.as_deref(),
                    &color,
                )?;
                let vault = sync(&store, book);
                done(
                    json,
                    json!({ "ok": true, "id": id, "vault": vault }),
                    format!("highlight {id} saved; {vault}"),
                );
            }
            HighlightAction::List { book } => {
                let list = store.highlights(book)?;
                if json {
                    println!("{}", serde_json::to_string(&list)?);
                } else {
                    for h in &list {
                        println!(
                            "{:>5}  [{}] \u{201c}{}\u{201d}",
                            h.id,
                            sanitize_terminal_text(&h.color),
                            sanitize_terminal_text(&h.quote)
                        );
                    }
                }
            }
            HighlightAction::Note { id, text } => {
                let book = store.set_note(id, &text)?;
                let vault = sync(&store, book);
                done(
                    json,
                    json!({ "ok": true, "vault": vault }),
                    format!("note saved; {vault}"),
                );
            }
            HighlightAction::Remove { id } => {
                let book = store.remove_highlight(id)?;
                let vault = sync(&store, book);
                done(
                    json,
                    json!({ "ok": true, "vault": vault }),
                    format!("highlight removed; {vault}"),
                );
            }
        },
        Command::Collection { action } => match action {
            CollectionAction::Create { name } => {
                let id = store.create_collection(&name)?;
                done(
                    json,
                    json!({ "ok": true, "id": id, "name": name }),
                    format!("created {name}"),
                );
            }
            CollectionAction::Rename { name, new_name } => {
                store.rename_collection(&name, &new_name)?;
                done(
                    json,
                    json!({ "ok": true, "name": new_name }),
                    format!("renamed to {new_name}"),
                );
            }
            CollectionAction::Delete { name } => {
                store.delete_collection(&name)?;
                done(json, json!({ "ok": true }), format!("deleted {name}"));
            }
            CollectionAction::List => {
                let list = store.collections()?;
                if json {
                    println!(
                        "{}",
                        json!(
                            list.iter()
                                .map(|(n, c)| json!({ "name": n, "books": c }))
                                .collect::<Vec<_>>()
                        )
                    );
                } else {
                    for (name, count) in &list {
                        println!("{}  ({count})", sanitize_terminal_text(name));
                    }
                }
            }
            CollectionAction::Show { name, sort } => {
                let list = store.collection_sorted(&name, sort.into())?;
                books(json, &store, &list, None)?;
            }
            CollectionAction::Add { name, book } => {
                // Keep the legacy add behavior: this single-book command creates a missing list.
                store.collect(&name, book)?;
                done(json, json!({ "ok": true }), format!("added to {name}"));
            }
            CollectionAction::Remove { name, book } => {
                store.uncollect(&name, book)?;
                done(json, json!({ "ok": true }), format!("removed from {name}"));
            }
            CollectionAction::AddMany { name, books: ids } => {
                let added = store.add_many_to_collection(&name, &ids)?;
                done(
                    json,
                    json!({ "ok": true, "added": added }),
                    format!("added {added} books to {name}"),
                );
            }
            CollectionAction::RemoveMany { name, books: ids } => {
                let removed = store.remove_many_from_collection(&name, &ids)?;
                done(
                    json,
                    json!({ "ok": true, "removed": removed }),
                    format!("removed {removed} books from {name}"),
                );
            }
            CollectionAction::Reorder {
                name,
                book,
                position,
            } => {
                store.reorder_collection(&name, book, position)?;
                done(
                    json,
                    json!({ "ok": true }),
                    format!("moved book {book} to position {position}"),
                );
            }
            CollectionAction::Import {
                dir,
                subject,
                dry_run,
            } => {
                let report = import::import(
                    &store,
                    &scan::default_roots(),
                    &scan::default_cover_dir(),
                    &dir,
                    subject.as_deref(),
                    dry_run,
                )?;
                if json {
                    let mut value = serde_json::to_value(&report)?;
                    value["ok"] = json!(true);
                    println!("{value}");
                } else {
                    imported(&report);
                }
            }
        },
        Command::Lists { name: None, .. } => {
            let summaries = store.collection_summaries()?;
            if json {
                println!("{}", serde_json::to_string(&summaries)?);
            } else {
                let names = summaries
                    .iter()
                    .map(|summary| sanitize_terminal_text(&summary.name))
                    .collect::<Vec<_>>();
                let width = names.iter().map(|n| n.chars().count()).max().unwrap_or(0);
                for (name, summary) in names.iter().zip(&summaries) {
                    println!(
                        "{name:<width$}  {} books \u{b7} {} reading \u{b7} {} finished",
                        summary.books, summary.reading, summary.finished
                    );
                }
            }
        }
        Command::Lists {
            name: Some(name),
            action: None,
            ..
        } => {
            let records = store.collection_records(&name)?;
            if json {
                let numbered = records
                    .iter()
                    .enumerate()
                    .map(|(at, record)| {
                        let mut value = serde_json::to_value(record)?;
                        value["position"] = json!(at + 1);
                        Ok(value)
                    })
                    .collect::<Result<Vec<_>>>()?;
                println!("{}", json!(numbered));
            } else {
                for (at, record) in records.iter().enumerate() {
                    println!(
                        "{:>3}  {:<8}  {}",
                        at + 1,
                        record.status.as_str(),
                        line(&record.book)
                    );
                }
            }
        }
        Command::Lists {
            name: Some(name),
            action: Some(how),
            position,
        } => {
            let records = store.collection_records(&name)?;
            let book = pick(&records, &name, how, position)?.book.clone();
            if book.kind.starts_with("audio") {
                let play = ListenAction::Play {
                    id: book.id,
                    at: None,
                    speed: None,
                };
                listen_command(json, &store, play)?;
            } else {
                open_book(json, &store, book.id)?;
            }
        }
        Command::Status { action } => match action {
            StatusAction::Get { book } => {
                let status = store.status(book)?;
                done(
                    json,
                    json!({ "ok": true, "status": status, "book": store.book_record(book)? }),
                    format!("{status}"),
                );
            }
            StatusAction::Set { book, status } => {
                store.set_status(book, status)?;
                done(
                    json,
                    json!({ "ok": true, "book": store.book_record(book)? }),
                    format!("set status to {status}"),
                );
            }
            StatusAction::Bulk { status, books: ids } => {
                let updated = store.set_status_many(&ids, status)?;
                let selected = ids
                    .iter()
                    .map(|id| store.book(*id))
                    .collect::<Result<Vec<_>>>()?;
                let records = store.records_for_books(&selected)?;
                done(
                    json,
                    json!({ "ok": true, "updated": updated, "books": records }),
                    format!("set {updated} books to {status}"),
                );
            }
        },
        Command::Watch { debounce_ms } => watcher::run(
            &store,
            &scan::default_roots(),
            &scan::default_cover_dir(),
            std::time::Duration::from_millis(debounce_ms),
        )?,
        Command::Export { id } => {
            let book = store.book(id)?;
            let (path, outcome) =
                vault::export(&vault::RealVault::from_env(), &book, &store.highlights(id)?)?;
            let what = match outcome {
                vault::Outcome::Created => "created",
                vault::Outcome::Updated => "updated",
                vault::Outcome::Unchanged => "already up to date",
            };
            done(
                json,
                json!({ "ok": true, "path": path, "outcome": what }),
                format!("{path}: {what}"),
            );
        }
        Command::Open { id } => open_book(json, &store, id)?,
        Command::Mode { id, mode } => {
            if let Some(mode) = &mode {
                store.set_mode(id, mode)?;
            }
            let mode = store.mode(id)?.unwrap_or_else(|| "unset".into());
            done(json, json!({ "ok": true, "mode": mode }), mode);
        }
        Command::Tui => mg_bookr::tui::run()?,
        Command::Listen { action } => listen_command(json, &store, action)?,
    }
    Ok(())
}

// The audiobook commands
fn listen_command(json: bool, store: &Store, action: ListenAction) -> Result<()> {
    let plan = |id| listen::plan_for(store, id);
    let at = |at: Option<String>| {
        at.map(|a| listen::parse_location(&a).context("--at is track:seconds, like 2:95.5"))
            .transpose()
    };
    match action {
        ListenAction::Play {
            id,
            at: place,
            speed,
        } => {
            // checked here, so a mistake is said now rather than in the session's log
            at(place.clone())?;
            speed.map(listen::check_speed).transpose()?;
            let mut session = listen::session_command(id)?;
            if let Some(place) = place {
                session.extend(["--at".into(), place]);
            }
            if let Some(speed) = speed {
                session.extend(["--speed".into(), speed.to_string()]);
            }
            listen::play(&plan(id)?, &session)?;
            let now = listen::now(store)?;
            let text = now.as_ref().map_or("started".into(), playing);
            done(json, json!({ "ok": true, "now": now }), text);
        }
        ListenAction::Now => {
            let now = listen::now(store)?;
            let text = now.as_ref().map_or("nothing is playing".into(), playing);
            done(json, json!({ "ok": true, "now": now }), text);
        }
        ListenAction::Pause | ListenAction::Resume | ListenAction::Toggle => {
            let on = match action {
                ListenAction::Pause => Some(true),
                ListenAction::Resume => Some(false),
                _ => None,
            };
            let paused = listen::pause(on)?;
            let text = if paused { "paused" } else { "playing" };
            done(json, json!({ "ok": true, "paused": paused }), text.into());
        }
        ListenAction::Seek { time } => {
            listen::seek(&time)?;
            done(json, json!({ "ok": true }), "moved".into());
        }
        ListenAction::Speed { speed } => {
            let speed = listen::speed(speed)?;
            done(
                json,
                json!({ "ok": true, "speed": speed }),
                format!("speed {speed}\u{d7}"),
            );
        }
        ListenAction::Chapter { which } => {
            listen::chapter(&which)?;
            done(json, json!({ "ok": true }), "moved".into());
        }
        ListenAction::Sleep { when } => {
            let text = match listen::sleep(&when)? {
                listen::Sleep::Off => "sleep timer off".into(),
                listen::Sleep::EndOfChapter => "stopping at the end of this chapter".into(),
                listen::Sleep::At(_) if when.trim() == "1" => "stopping in 1 minute".into(),
                listen::Sleep::At(_) => format!("stopping in {} minutes", when.trim()),
            };
            done(json, json!({ "ok": true }), text);
        }
        ListenAction::Stop => {
            listen::stop()?;
            done(
                json,
                json!({ "ok": true }),
                "stopped; the place is saved".into(),
            );
        }
        ListenAction::Session {
            id,
            at: place,
            speed,
        } => {
            listen::session(store, &plan(id)?, at(place)?, speed)?;
        }
    }
    Ok(())
}

// "▶ Title — Chapter 3 — 12:34 / 45:00, track 2 of 10, 1.5×, sleep in 12 min"
fn playing(now: &listen::Now) -> String {
    let mut text = format!(
        "{} {}",
        if now.paused { "\u{23f8}" } else { "\u{25b6}" },
        sanitize_terminal_text(&now.book.title)
    );
    if let Some(chapter) = &now.chapter {
        text += &format!(" \u{2014} {}", sanitize_terminal_text(chapter));
    }
    text += &format!(
        " \u{2014} {} / {}",
        clock(now.position),
        clock(now.duration)
    );
    if now.tracks > 1 {
        text += &format!(", track {} of {}", now.track + 1, now.tracks);
    }
    text += &format!(", {}\u{d7}", now.speed);
    if let Some(left) = now.sleep_left {
        text += &format!(", sleep in {} min", (left / 60.0).ceil());
    } else if now.sleep_chapter {
        text += ", sleep at chapter end";
    }
    text
}

// After a highlight change: rewrite the book's vault note, and say how it went (never fails the change)
fn sync(store: &Store, book_id: i64) -> String {
    let result = store.book(book_id).and_then(|book| {
        let highlights = store.highlights(book_id)?;
        vault::export(&vault::RealVault::from_env(), &book, &highlights)
    });
    match result {
        Ok((path, _)) => format!("vault note {path} updated"),
        Err(e) => format!("vault note not written: {e:#}"),
    }
}

// Open a book in the reader window and note that it was opened
fn open_book(json: bool, store: &Store, id: i64) -> Result<()> {
    let book = store.book(id)?;
    reader::open(&book)?;
    store.mark_opened(id)?;
    done(
        json,
        json!({ "ok": true, "book": store.book_record(id)? }),
        format!("opening {}", book.title),
    );
    Ok(())
}

// The book `lists <name> open <n>` or `lists <name> next` means
fn pick<'a>(
    records: &'a [BookRecord],
    name: &str,
    how: ListMove,
    position: Option<usize>,
) -> Result<&'a BookRecord> {
    if records.is_empty() {
        bail!("{name} has no books")
    }
    match (how, position) {
        (ListMove::Open, Some(at)) => at
            .checked_sub(1)
            .and_then(|index| records.get(index))
            .with_context(|| format!("{name}'s places are 1 to {}", records.len())),
        (ListMove::Open, None) => bail!("open needs the book's place in the list, from 1"),
        (ListMove::Next, None) => records
            .iter()
            .find(|record| record.status != BookStatus::Finished && !record.book.missing)
            .with_context(|| format!("nothing in {name} is left to read")),
        (ListMove::Next, Some(_)) => bail!("next takes no place; open <n> picks one"),
    }
}

// What an import did, or would do on a dry run
fn imported(report: &import::Report) {
    for member in &report.books {
        let what = match (member.action, report.dry_run) {
            (import::Action::Shelved, _) => "in library",
            (import::Action::Duplicate, false) => "linked",
            (import::Action::Duplicate, true) => "would link",
            (import::Action::Imported, false) => "imported",
            (import::Action::Imported, true) => "would import",
        };
        println!(
            "  {what:<12}  {}  \u{2192}  {}",
            sanitize_terminal_text(&member.source),
            sanitize_terminal_text(&member.path)
        );
    }
    for skipped in &report.skipped {
        println!(
            "  {:<12}  {}: {}",
            "skipped",
            sanitize_terminal_text(&skipped.source),
            sanitize_terminal_text(&skipped.reason)
        );
    }
    let filed = report.subject.as_ref().map_or(String::new(), |subject| {
        format!("; new books go to {}", sanitize_terminal_text(subject))
    });
    let list = sanitize_terminal_text(&report.list);
    if report.dry_run {
        println!(
            "dry run: {list} would list {} books{filed}; nothing was changed",
            report.books.len()
        );
    } else {
        println!(
            "{list}: {} books, {} newly listed{filed}",
            report.books.len(),
            report.added
        );
    }
}

// An action's answer: JSON, or one line
fn done(json: bool, value: serde_json::Value, text: String) {
    if json {
        println!("{value}");
    } else {
        println!("{}", sanitize_terminal_text(&text));
    }
}

fn books(
    json: bool,
    store: &Store,
    list: &[Book],
    status_filter: Option<BookStatus>,
) -> Result<()> {
    let records = store.records_for_books(list)?;
    let records = records
        .into_iter()
        .filter(|record| status_filter.is_none_or(|status| record.status == status))
        .collect::<Vec<_>>();
    if json {
        println!("{}", serde_json::to_string(&records)?);
    } else {
        for record in &records {
            println!("{}", line(&record.book));
        }
    }
    Ok(())
}

// "  12  [epub]  Title — Author  (40%)"
fn line(b: &Book) -> String {
    let by = b.author.as_ref().map_or(String::new(), |a| {
        format!(" \u{2014} {}", sanitize_terminal_text(a))
    });
    let at = b.percent.map_or(String::new(), |p| {
        if b.finished {
            "  (finished)".into()
        } else {
            format!("  ({p:.0}%)")
        }
    });
    let gone = if b.missing { "  [missing]" } else { "" };
    format!(
        "{:>4}  [{}]  {}{by}{at}{gone}",
        b.id,
        sanitize_terminal_text(&b.kind),
        sanitize_terminal_text(&b.title)
    )
}

// 3725 s → "1:02:05"
fn clock(seconds: f64) -> String {
    let s = seconds.max(0.0) as u64;
    format!("{}:{:02}:{:02}", s / 3600, s % 3600 / 60, s % 60)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn list_and_search_sort_options_parse_with_the_legacy_default() {
        let default_list = Cli::try_parse_from(["mg-bookr", "list"]).unwrap();
        assert!(matches!(
            default_list.command,
            Command::List {
                kind: None,
                missing: false,
                sort: SortBy::Recent,
                status: None
            }
        ));

        let search = Cli::try_parse_from([
            "mg-bookr",
            "search",
            "Earthsea",
            "--kind",
            "epub",
            "--missing",
            "--sort",
            "series",
            "--limit",
            "25",
        ])
        .unwrap();
        assert!(matches!(
            search.command,
            Command::Search {
                text,
                kind: Some(kind),
                missing: true,
                limit: 25,
                sort: SortBy::Series,
                status: None
            } if text == "Earthsea" && kind == "epub"
        ));
    }

    #[test]
    fn authority_commands_parse_manual_title_bulk_status_force_and_watch() {
        let collection = Cli::try_parse_from([
            "mg-bookr",
            "collection",
            "show",
            "Reading now",
            "--sort",
            "title",
        ])
        .unwrap();
        assert!(matches!(
            collection.command,
            Command::Collection {
                action: CollectionAction::Show {
                    name,
                    sort: CollectionOrder::Title
                }
            } if name == "Reading now"
        ));

        let status =
            Cli::try_parse_from(["mg-bookr", "status", "bulk", "paused", "7", "9"]).unwrap();
        assert!(matches!(
            status.command,
            Command::Status {
                action: StatusAction::Bulk {
                    status: BookStatus::Paused,
                    books
                }
            } if books == [7, 9]
        ));

        let force = Cli::try_parse_from(["mg-bookr", "scan", "--force"]).unwrap();
        assert!(matches!(force.command, Command::Scan { force: true }));
        let watch = Cli::try_parse_from(["mg-bookr", "watch", "--debounce-ms", "250"]).unwrap();
        assert!(matches!(watch.command, Command::Watch { debounce_ms: 250 }));
    }

    #[test]
    fn collection_import_takes_a_folder_a_subject_and_a_dry_run() {
        let import = Cli::try_parse_from([
            "mg-bookr",
            "collection",
            "import",
            "/lists/ccna-weekly/",
            "--subject",
            "Networking, Cloud & DevOps",
            "--dry-run",
        ])
        .unwrap();
        assert!(matches!(
            import.command,
            Command::Collection {
                action: CollectionAction::Import {
                    dir,
                    subject: Some(subject),
                    dry_run: true
                }
            } if dir == std::path::Path::new("/lists/ccna-weekly")
                && subject == "Networking, Cloud & DevOps"
        ));
        let plain =
            Cli::try_parse_from(["mg-bookr", "collection", "import", "ccna-weekly"]).unwrap();
        assert!(matches!(
            plain.command,
            Command::Collection {
                action: CollectionAction::Import {
                    subject: None,
                    dry_run: false,
                    ..
                }
            }
        ));
    }

    #[test]
    fn lists_takes_a_name_then_open_n_or_next() {
        let lists = |args: &[&str]| {
            let mut argv = vec!["mg-bookr", "lists"];
            argv.extend(args);
            match Cli::try_parse_from(argv).map(|cli| cli.command) {
                Ok(Command::Lists {
                    name,
                    action,
                    position,
                }) => Ok((name, action, position)),
                Ok(_) => panic!("not lists"),
                Err(error) => Err(error.kind()),
            }
        };
        assert_eq!(lists(&[]), Ok((None, None, None)));
        assert_eq!(
            lists(&["ccna-weekly"]),
            Ok((Some("ccna-weekly".into()), None, None))
        );
        assert_eq!(
            lists(&["ccna-weekly", "open", "3"]),
            Ok((Some("ccna-weekly".into()), Some(ListMove::Open), Some(3)))
        );
        assert_eq!(
            lists(&["ccna-weekly", "next"]),
            Ok((Some("ccna-weekly".into()), Some(ListMove::Next), None))
        );
        assert!(lists(&["ccna-weekly", "read"]).is_err());
    }

    fn record(id: i64, status: BookStatus, missing: bool) -> BookRecord {
        BookRecord {
            book: Book {
                id,
                kind: "epub".into(),
                root: "books".into(),
                path: format!("{id}.epub"),
                title: format!("Book {id}"),
                author: None,
                series: None,
                series_index: None,
                cover: None,
                pages: None,
                duration_seconds: None,
                missing,
                location: None,
                percent: None,
                finished: false,
                updated_at: None,
            },
            status,
        }
    }

    #[test]
    fn open_picks_a_place_and_next_the_first_unfinished_present_book() {
        let records = [
            record(1, BookStatus::Finished, false),
            record(2, BookStatus::ToRead, true),
            record(3, BookStatus::Reading, false),
            record(4, BookStatus::ToRead, false),
        ];
        let id = |how, at| pick(&records, "ccna", how, at).map(|r| r.book.id);
        assert_eq!(id(ListMove::Open, Some(1)).unwrap(), 1);
        assert_eq!(id(ListMove::Open, Some(4)).unwrap(), 4);
        assert_eq!(
            id(ListMove::Next, None).unwrap(),
            3,
            "finished and missing are passed"
        );
        for (how, at, said) in [
            (ListMove::Open, Some(0), "ccna's places are 1 to 4"),
            (ListMove::Open, Some(5), "ccna's places are 1 to 4"),
            (ListMove::Open, None, "open needs the book's place"),
            (ListMove::Next, Some(2), "next takes no place"),
        ] {
            assert!(format!("{:#}", id(how, at).unwrap_err()).contains(said));
        }
        let done = [record(1, BookStatus::Finished, false)];
        let error = pick(&done, "ccna", ListMove::Next, None).unwrap_err();
        assert!(format!("{error:#}").contains("nothing in ccna is left to read"));
        let error = pick(&[], "ccna", ListMove::Next, None).unwrap_err();
        assert!(format!("{error:#}").contains("ccna has no books"));
    }

    #[test]
    fn plain_book_rows_remove_terminal_active_metadata() {
        let book = Book {
            id: 1,
            kind: "epub\u{1b}[2J".into(),
            root: "books".into(),
            path: "book.epub".into(),
            title: "title\u{202e}spoof".into(),
            author: Some("author\nsecond-line".into()),
            series: None,
            series_index: None,
            cover: None,
            pages: None,
            duration_seconds: None,
            missing: false,
            location: None,
            percent: None,
            finished: false,
            updated_at: None,
        };
        let rendered = line(&book);
        assert_eq!(
            rendered,
            "   1  [epub[2J]  titlespoof \u{2014} authorsecond-line"
        );
    }
}
