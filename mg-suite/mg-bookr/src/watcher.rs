use std::path::Path;
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use notify::{Event, EventKind, RecursiveMode, Watcher};
use serde::Serialize;
use serde_json::json;

use crate::scan::{self, Roots};
use crate::store::Store;

pub fn run(store: &Store, roots: &Roots, cover_dir: &Path, debounce: Duration) -> Result<()> {
    let (sender, receiver) = mpsc::channel();
    let mut watcher = notify::recommended_watcher(sender)?;
    let configured_roots = [
        (scan::BOOKS, roots.books.as_path()),
        (scan::AUDIOBOOKS, roots.audiobooks.as_path()),
    ];
    let mut watch_errors = Vec::new();
    for (name, root) in configured_roots {
        if !root.is_dir() {
            watch_errors.push(format!(
                "{name}: {} is not an accessible directory",
                root.display()
            ));
            continue;
        }
        if let Err(error) = watcher.watch(root, RecursiveMode::Recursive) {
            watch_errors.push(format!(
                "{name}: could not watch {}: {error}",
                root.display()
            ));
        }
    }

    emit(&json!({"event": "ready", "report": scan::scan(store, roots, cover_dir)?}))?;
    for error in watch_errors {
        emit(&json!({"event": "error", "error": error}))?;
    }

    loop {
        match receiver.recv() {
            Ok(Ok(event)) if relevant(&event, &roots.books, &roots.audiobooks) => {
                let (coalesced, errors) =
                    drain_debounced(&receiver, debounce, &roots.books, &roots.audiobooks);
                for error in errors {
                    emit(&json!({"event": "error", "error": error}))?;
                }
                match scan::scan(store, roots, cover_dir) {
                    Ok(report) => emit(&json!({
                        "event": "scan",
                        "coalesced": coalesced,
                        "report": report
                    }))?,
                    Err(error) => emit(&json!({"event": "error", "error": format!("{error:#}")}))?,
                }
            }
            Ok(Ok(_)) => {}
            Ok(Err(error)) => emit(&json!({"event": "error", "error": error.to_string()}))?,
            Err(error) => return Err(error).context("filesystem watcher channel closed"),
        }
    }
}

fn relevant(event: &Event, books: &Path, audiobooks: &Path) -> bool {
    if !matches!(
        &event.kind,
        EventKind::Any | EventKind::Create(_) | EventKind::Modify(_) | EventKind::Remove(_)
    ) {
        return false;
    }
    event.paths.is_empty()
        || event
            .paths
            .iter()
            .any(|path| path.starts_with(books) || path.starts_with(audiobooks))
}

fn drain_debounced(
    receiver: &Receiver<notify::Result<Event>>,
    debounce: Duration,
    books: &Path,
    audiobooks: &Path,
) -> (usize, Vec<String>) {
    let mut count = 1;
    let mut errors = Vec::new();
    let mut deadline = Instant::now() + debounce;
    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        match receiver.recv_timeout(remaining) {
            Ok(Ok(event)) if relevant(&event, books, audiobooks) => {
                count += 1;
                deadline = Instant::now() + debounce;
            }
            Ok(Ok(_)) => {}
            Ok(Err(error)) => errors.push(error.to_string()),
            Err(RecvTimeoutError::Timeout | RecvTimeoutError::Disconnected) => break,
        }
    }
    (count, errors)
}

fn emit(value: &impl Serialize) -> Result<()> {
    let stdout = std::io::stdout();
    let mut output = stdout.lock();
    serde_json::to_writer(&mut output, value)?;
    use std::io::Write;
    output.write_all(b"\n")?;
    output.flush()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use notify::event::{AccessKind, AccessMode, ModifyKind};
    use std::path::PathBuf;
    use std::thread;

    fn change(path: &Path) -> notify::Result<Event> {
        Ok(Event {
            kind: EventKind::Modify(ModifyKind::Any),
            paths: vec![path.to_path_buf()],
            attrs: Default::default(),
        })
    }

    #[test]
    fn watcher_debounce_coalesces_mutations_and_ignores_access_events() {
        let root = PathBuf::from("/books");
        let (sender, receiver) = mpsc::channel();
        sender.send(change(&root.join("a.epub"))).unwrap();
        let mut access = Event::new(EventKind::Access(AccessKind::Open(AccessMode::Any)));
        access.paths.push(root.join("a.epub"));
        sender.send(Ok(access)).unwrap();
        let root_for_sender = root.clone();
        let sender_thread = thread::spawn(move || {
            thread::sleep(Duration::from_millis(10));
            sender
                .send(change(&root_for_sender.join("a.epub")))
                .unwrap();
            thread::sleep(Duration::from_millis(10));
            sender
                .send(change(&root_for_sender.join("b.epub")))
                .unwrap();
        });

        let first = receiver.recv().unwrap().unwrap();
        assert!(relevant(&first, &root, Path::new("/audio")));
        let (count, errors) = drain_debounced(
            &receiver,
            Duration::from_millis(40),
            &root,
            Path::new("/audio"),
        );
        sender_thread.join().unwrap();
        assert_eq!(count, 3);
        assert!(errors.is_empty());
        assert!(!relevant(
            &Event::new(EventKind::Access(AccessKind::Open(AccessMode::Any))),
            &root,
            Path::new("/audio")
        ));
    }
}
