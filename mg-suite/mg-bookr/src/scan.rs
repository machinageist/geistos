// Author: Jeff
// Date: 2026-09-19
// Description: Walk the book folders and record what is there — the library's only way in
// Notes: Ebooks: EPUB, PDF, CBZ, CBR under the books root. Audiobooks under the audiobooks root:
//        any M4B/M4A file is one book, and any folder holding other audio files is one book
//        (its files are the tracks, and the walk does not go below it). Symlinks are not
//        followed and the walk stops at depth 8, so a loop or a huge tree cannot run away.
//        A book whose metadata cannot be read is still recorded under its file name.
//        Covers are cached under a key made from the book's place, size and change time, so a
//        replaced file gets a fresh cover and an unchanged one is not redone

use std::path::{Path, PathBuf};

use anyhow::Result;
use serde::Serialize;
use sha2::{Digest, Sha256};

use crate::meta::{self, Meta};
use crate::store::{Found, ScanMetadata, ScanRecord, Store};
use crate::terminal_text::sanitize_terminal_text;

pub const BOOKS: &str = "books";
pub const AUDIOBOOKS: &str = "audiobooks";
pub(crate) const MAX_DEPTH: usize = 8;
pub(crate) const EBOOK_EXTENSIONS: [&str; 4] = ["epub", "pdf", "cbz", "cbr"];
// single-file audiobooks; other audio files make their folder a book
const BOOK_AUDIO: [&str; 2] = ["m4b", "m4a"];

pub struct Roots {
    pub books: PathBuf,
    pub audiobooks: PathBuf,
}

// $MG_BOOKR_BOOKS and $MG_BOOKR_AUDIOBOOKS, else ~/books and ~/audiobooks
pub fn default_roots() -> Roots {
    let home = dirs::home_dir().unwrap_or_default();
    let from = |var: &str, default: &str| {
        std::env::var_os(var)
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(default))
    };
    Roots {
        books: from("MG_BOOKR_BOOKS", "books"),
        audiobooks: from("MG_BOOKR_AUDIOBOOKS", "audiobooks"),
    }
}

// $XDG_CACHE_HOME/mg-bookr/covers
pub fn default_cover_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("mg-bookr/covers")
}

#[derive(Debug, Default, Serialize)]
pub struct Report {
    pub found: usize,
    pub added: usize,
    pub updated: usize,
    pub unchanged: usize,
    pub missing: usize,
    pub forced: bool,
    pub unreadable: Vec<(String, String)>,
    pub incomplete_roots: Vec<String>,
    pub diagnostics: Vec<String>,
}

#[derive(Debug)]
struct Candidate {
    kind: String,
    relative_path: String,
    fingerprint: Option<String>,
}

#[derive(Debug, Default)]
struct WalkResult {
    candidates: Vec<Candidate>,
    diagnostics: Vec<String>,
    complete: bool,
}

fn file_stat(path: &Path) -> std::io::Result<String> {
    let metadata = std::fs::metadata(path)?;
    let modified = metadata
        .modified()?
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(std::io::Error::other)?;
    Ok(format!(
        "{}:{}:{}",
        metadata.len(),
        modified.as_secs(),
        modified.subsec_nanos()
    ))
}

fn fingerprint(root: &str, relative_path: &str, stat: &str) -> String {
    Sha256::digest(format!("{root}\0{relative_path}\0{stat}").as_bytes())
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

fn folder_fingerprint(root: &str, relative_path: &str, members: &[(String, String)]) -> String {
    let mut members = members.to_vec();
    members.sort();
    let mut digest = Sha256::new();
    digest.update(root.as_bytes());
    digest.update([0]);
    digest.update(relative_path.as_bytes());
    for (member, stat) in members {
        digest.update([0]);
        digest.update(member.as_bytes());
        digest.update([0]);
        digest.update(stat.as_bytes());
    }
    digest
        .finalize()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

// Walk without following symlinks. Any traversal/stat error makes reconciliation unsafe.
fn walk(root: &Path, logical_root: &str, audio: bool) -> WalkResult {
    let mut result = WalkResult {
        complete: true,
        ..WalkResult::default()
    };
    let mut stack = vec![(root.to_path_buf(), 0usize)];
    while let Some((dir, depth)) = stack.pop() {
        let dir_relative = dir
            .strip_prefix(root)
            .ok()
            .and_then(Path::to_str)
            .unwrap_or("");
        let entries = match std::fs::read_dir(&dir) {
            Ok(entries) => entries,
            Err(error) => {
                result.complete = false;
                result.diagnostics.push(format!(
                    "{}: cannot enumerate directory: {error}",
                    if dir_relative.is_empty() {
                        logical_root
                    } else {
                        dir_relative
                    }
                ));
                continue;
            }
        };
        let mut subdirs = Vec::new();
        let mut folder_audio = false;
        let mut folder_members = Vec::new();
        for entry in entries {
            let entry = match entry {
                Ok(entry) => entry,
                Err(error) => {
                    result.complete = false;
                    result.diagnostics.push(format!(
                        "{}: directory entry could not be read: {error}",
                        if dir_relative.is_empty() {
                            logical_root
                        } else {
                            dir_relative
                        }
                    ));
                    continue;
                }
            };
            let Some(name) = entry.file_name().to_str().map(str::to_owned) else {
                result.complete = false;
                result.diagnostics.push(format!(
                    "{}: non-UTF-8 entry name was skipped",
                    if dir_relative.is_empty() {
                        logical_root
                    } else {
                        dir_relative
                    }
                ));
                continue;
            };
            if name.starts_with('.') {
                continue;
            }
            let path = entry.path();
            let kind = match entry.file_type() {
                Ok(kind) => kind,
                Err(error) => {
                    result.complete = false;
                    result.diagnostics.push(format!(
                        "{}: file type could not be read: {error}",
                        path.display()
                    ));
                    continue;
                }
            };
            let relative_path = path
                .strip_prefix(root)
                .ok()
                .and_then(Path::to_str)
                .map(str::to_owned);
            let Some(relative_path) = relative_path else {
                result.complete = false;
                result
                    .diagnostics
                    .push(format!("{}: relative path is not UTF-8", path.display()));
                continue;
            };
            let extension = meta::extension(&name);
            if kind.is_dir() {
                subdirs.push(path);
            } else if kind.is_file() && !audio && EBOOK_EXTENSIONS.contains(&extension.as_str()) {
                let book_kind = match extension.as_str() {
                    "cbz" | "cbr" => "comic",
                    other => other,
                };
                let fingerprint = match file_stat(&path) {
                    Ok(stat) => Some(fingerprint(logical_root, &relative_path, &stat)),
                    Err(error) => {
                        result.complete = false;
                        result.diagnostics.push(format!(
                            "{logical_root}/{relative_path}: stat failed: {error}"
                        ));
                        None
                    }
                };
                result.candidates.push(Candidate {
                    kind: book_kind.to_string(),
                    relative_path,
                    fingerprint,
                });
            } else if kind.is_file() && audio {
                if BOOK_AUDIO.contains(&extension.as_str()) {
                    let file_fingerprint = match file_stat(&path) {
                        Ok(stat) => Some(fingerprint(logical_root, &relative_path, &stat)),
                        Err(error) => {
                            result.complete = false;
                            result.diagnostics.push(format!(
                                "{logical_root}/{relative_path}: stat failed: {error}"
                            ));
                            None
                        }
                    };
                    result.candidates.push(Candidate {
                        kind: "audio".into(),
                        relative_path: relative_path.clone(),
                        fingerprint: file_fingerprint,
                    });
                } else if meta::AUDIO_EXTENSIONS.contains(&extension.as_str()) {
                    folder_audio = true;
                }
                let is_cover = [
                    "cover.jpg",
                    "cover.png",
                    "folder.jpg",
                    "folder.png",
                    "front.jpg",
                ]
                .contains(&name.to_ascii_lowercase().as_str());
                if meta::AUDIO_EXTENSIONS.contains(&extension.as_str()) || is_cover {
                    match file_stat(&path) {
                        Ok(stat) => folder_members.push((name, stat)),
                        Err(error) => {
                            result.complete = false;
                            result.diagnostics.push(format!(
                                "{logical_root}/{relative_path}: stat failed: {error}"
                            ));
                            folder_members.push((name, "unavailable".into()));
                        }
                    }
                }
            }
        }
        // Folder audiobooks use direct member paths/stat data in their deterministic fingerprint.
        if folder_audio && !dir_relative.is_empty() {
            let member_stat_ok = folder_members.iter().all(|(_, stat)| stat != "unavailable");
            result.candidates.push(Candidate {
                kind: "audio-folder".into(),
                relative_path: dir_relative.to_owned(),
                fingerprint: member_stat_ok
                    .then(|| folder_fingerprint(logical_root, dir_relative, &folder_members)),
            });
            continue;
        }
        subdirs.sort();
        if depth < MAX_DEPTH {
            stack.extend(subdirs.into_iter().map(|subdir| (subdir, depth + 1)));
        } else if !subdirs.is_empty() {
            result.complete = false;
            result.diagnostics.push(format!(
                "{logical_root}/{}: traversal depth limit {MAX_DEPTH} reached",
                dir_relative
            ));
        }
    }
    result.candidates.sort_by(|left, right| {
        (&left.kind, &left.relative_path).cmp(&(&right.kind, &right.relative_path))
    });
    result
}

// Where a book's cover goes: a key from its place, size and change time
fn cover_key(root: &str, rel: &str, path: &Path) -> String {
    let stamp = std::fs::metadata(path)
        .map(|m| format!("{}:{:?}", m.len(), m.modified().ok()))
        .unwrap_or_default();
    Sha256::digest(format!("{root}/{rel}/{stamp}").as_bytes())
        .iter()
        .take(16)
        .map(|b| format!("{b:02x}"))
        .collect()
}

// Read one book's metadata by kind
pub(crate) fn read(kind: &str, path: &Path) -> Result<Meta> {
    match kind {
        "epub" => meta::epub(path),
        "pdf" => meta::pdf(path),
        "comic" if meta::extension(path.to_str().unwrap_or_default()) == "cbr" => meta::cbr(path),
        "comic" => meta::cbz(path),
        "audio" => meta::audio_file(path),
        _ => meta::audio_folder(path),
    }
}

// Save a cover to the cache (once) and return its path
fn store_cover(kind: &str, path: &Path, meta: &mut Meta, dir: &Path, key: &str) -> Option<String> {
    std::fs::create_dir_all(dir).ok()?;
    // an already cached cover for this exact file is reused
    for ext in ["jpg", "jpeg", "png", "webp", "gif"] {
        let existing = dir.join(format!("{key}.{ext}"));
        if existing.exists() {
            return Some(existing.display().to_string());
        }
    }
    if let Some((bytes, ext)) = meta.cover.take() {
        let ext = if meta::IMAGE_EXTENSIONS.contains(&ext.as_str()) {
            ext
        } else {
            "jpg".into()
        };
        let dest = dir.join(format!("{key}.{ext}"));
        let part = dir.join(format!(".{key}.part"));
        std::fs::write(&part, bytes).ok()?;
        std::fs::rename(&part, &dest).ok()?;
        return Some(dest.display().to_string());
    }
    // a PDF's cover is its first page, drawn by pdftoppm straight into the cache
    if kind == "pdf" && meta::pdf_cover(path, &dir.join(key)).is_ok() {
        let dest = dir.join(format!("{key}.jpg"));
        return dest.exists().then(|| dest.display().to_string());
    }
    None
}

// Walk both roots and reconcile only those whose traversal completed successfully.
pub fn scan(store: &Store, roots: &Roots, cover_dir: &Path) -> Result<Report> {
    scan_with_force(store, roots, cover_dir, false)
}

pub fn scan_with_force(
    store: &Store,
    roots: &Roots,
    cover_dir: &Path,
    force: bool,
) -> Result<Report> {
    let mut report = Report {
        forced: force,
        ..Report::default()
    };
    let mut records = Vec::new();
    let mut complete_roots = Vec::new();
    for (root_name, root, audio) in [
        (BOOKS, &roots.books, false),
        (AUDIOBOOKS, &roots.audiobooks, true),
    ] {
        let walked = walk(root, root_name, audio);
        let fingerprints = store.scan_fingerprints(root_name)?;
        if walked.complete {
            complete_roots.push(root_name.to_string());
        } else {
            report.incomplete_roots.push(format!(
                "{root_name}: {}",
                walked
                    .diagnostics
                    .first()
                    .map_or("traversal was incomplete", String::as_str)
            ));
        }
        report.diagnostics.extend(
            walked
                .diagnostics
                .iter()
                .map(|diagnostic| format!("{root_name}: {diagnostic}")),
        );
        report.found += walked.candidates.len();

        for candidate in walked.candidates {
            let Some(candidate_fingerprint) = candidate.fingerprint else {
                continue;
            };
            if !force
                && fingerprints
                    .get(&candidate.relative_path)
                    .is_some_and(|saved| saved == &candidate_fingerprint)
            {
                records.push(ScanRecord {
                    root: root_name.to_string(),
                    path: candidate.relative_path,
                    fingerprint: candidate_fingerprint,
                    metadata: ScanMetadata::Unchanged,
                });
                continue;
            }

            let path = root.join(&candidate.relative_path);
            let metadata = match read(&candidate.kind, &path) {
                Ok(mut metadata) => {
                    let key = if candidate.kind == "audio-folder" {
                        Sha256::digest(candidate_fingerprint.as_bytes())
                            .iter()
                            .take(16)
                            .map(|byte| format!("{byte:02x}"))
                            .collect()
                    } else {
                        cover_key(root_name, &candidate.relative_path, &path)
                    };
                    let cover = store_cover(&candidate.kind, &path, &mut metadata, cover_dir, &key);
                    let title = metadata
                        .title
                        .clone()
                        .unwrap_or_else(|| meta::title_from_name(&candidate.relative_path));
                    let found = Found {
                        kind: candidate.kind,
                        root: root_name.to_string(),
                        title: sanitize_terminal_text(&title),
                        path: candidate.relative_path.clone(),
                        author: metadata.author.as_deref().map(sanitize_terminal_text),
                        series: metadata.series.as_deref().map(sanitize_terminal_text),
                        series_index: metadata.series_index,
                        cover,
                        pages: metadata.pages,
                        duration_seconds: metadata.duration_seconds,
                        tracks: metadata.tracks,
                        chapters: metadata
                            .chapters
                            .into_iter()
                            .map(|(title, start)| (sanitize_terminal_text(&title), start))
                            .collect(),
                    };
                    ScanMetadata::Parsed(found)
                }
                Err(error) => {
                    let message = format!("{error:#}");
                    report.unreadable.push((
                        format!("{root_name}/{}", candidate.relative_path),
                        message.clone(),
                    ));
                    ScanMetadata::Failed {
                        fallback: Found {
                            kind: candidate.kind,
                            root: root_name.to_string(),
                            title: sanitize_terminal_text(&meta::title_from_name(
                                &candidate.relative_path,
                            )),
                            path: candidate.relative_path.clone(),
                            ..Found::default()
                        },
                        error: message,
                    }
                }
            };
            records.push(ScanRecord {
                root: root_name.to_string(),
                path: candidate.relative_path,
                fingerprint: candidate_fingerprint,
                metadata,
            });
        }
    }
    let saved = store.save_incremental_scan(&complete_roots, &records)?;
    report.added = saved.added;
    report.updated = saved.updated;
    report.unchanged = saved.unchanged;
    report.missing = saved.missing;
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::meta::tests::{write_cbz, write_epub};

    // A tiny one-page PDF; poppler repairs the missing cross-reference table
    const PDF: &[u8] = b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n";

    fn tool(name: &str) -> bool {
        std::process::Command::new("sh")
            .args(["-c", &format!("command -v {name}")])
            .output()
            .is_ok_and(|o| o.status.success())
    }

    #[test]
    fn a_scan_finds_every_kind_and_a_second_scan_changes_nothing() {
        let dir = tempfile::tempdir().unwrap();
        let (books, audio, covers) = (
            dir.path().join("books"),
            dir.path().join("audiobooks"),
            dir.path().join("covers"),
        );
        std::fs::create_dir_all(books.join("Le Guin")).unwrap();
        std::fs::create_dir_all(audio.join("Dune/disc 1")).unwrap();
        write_epub(&books.join("Le Guin/left-hand.epub"), false);
        write_cbz(&books.join("saga-01.cbz"));
        std::fs::write(books.join("paper.pdf"), PDF).unwrap();
        std::fs::write(books.join("notes.txt"), b"not a book").unwrap();
        std::fs::write(books.join(".hidden.epub"), b"skip").unwrap();
        for n in ["01.mp3", "02.mp3"] {
            std::fs::write(audio.join("Dune/disc 1").join(n), b"x").unwrap();
        }
        std::fs::write(audio.join("single.m4b"), b"x").unwrap();
        // a symlink loop must not be followed
        #[cfg(unix)]
        std::os::unix::fs::symlink(&books, books.join("loop")).unwrap();

        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let roots = Roots {
            books: books.clone(),
            audiobooks: audio.clone(),
        };
        let report = scan(&store, &roots, &covers).unwrap();
        let all = store.books(None, false).unwrap();
        let mut kinds: Vec<(String, String)> = all
            .iter()
            .map(|b| (b.kind.clone(), b.path.clone()))
            .collect();
        kinds.sort();
        assert_eq!(
            kinds,
            [
                ("audio".into(), "single.m4b".into()),
                ("audio-folder".into(), "Dune/disc 1".into()),
                ("comic".into(), "saga-01.cbz".into()),
                ("epub".into(), "Le Guin/left-hand.epub".into()),
                ("pdf".into(), "paper.pdf".into()),
            ]
        );
        assert_eq!((report.found, report.added, report.missing), (5, 5, 0));
        let epub = all.iter().find(|b| b.kind == "epub").unwrap();
        assert_eq!(epub.title, "The Left Hand of Darkness");
        assert!(
            epub.cover
                .as_ref()
                .is_some_and(|c| std::path::Path::new(c).exists())
        );
        let folder = all.iter().find(|b| b.kind == "audio-folder").unwrap();
        assert_eq!(store.tracks(folder.id).unwrap().len(), 2);
        if tool("pdfinfo") {
            let pdf = all.iter().find(|b| b.kind == "pdf").unwrap();
            assert_eq!(pdf.pages, Some(1));
        }
        let again = scan(&store, &roots, &covers).unwrap();
        assert_eq!((again.added, again.missing), (0, 0));

        // the comic moves away: missing, not gone
        std::fs::remove_file(books.join("saga-01.cbz")).unwrap();
        assert_eq!(scan(&store, &roots, &covers).unwrap().missing, 1);
        assert_eq!(store.books(None, true).unwrap().len(), 5);
    }

    #[test]
    fn unchanged_fingerprint_skips_parse_and_force_retries_without_erasing_history() {
        use std::fs::{File, FileTimes};

        let dir = tempfile::tempdir().unwrap();
        let books = dir.path().join("books");
        let audio = dir.path().join("audiobooks");
        std::fs::create_dir_all(&books).unwrap();
        std::fs::create_dir_all(&audio).unwrap();
        let book_path = books.join("a.epub");
        write_epub(&book_path, false);
        let roots = Roots {
            books,
            audiobooks: audio,
        };
        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let covers = dir.path().join("covers");

        let initial = scan(&store, &roots, &covers).unwrap();
        assert_eq!(
            (initial.added, initial.updated, initial.unchanged),
            (1, 0, 0)
        );
        let id = store.books(None, false).unwrap()[0].id;
        store
            .set_progress(id, "spine:0.5", 47.0, Some(false))
            .unwrap();
        store
            .set_status(id, crate::store::BookStatus::Paused)
            .unwrap();
        store
            .add_highlight(id, "spine:0.5", None, "kept", None, "yellow")
            .unwrap();
        store.create_collection("Saved").unwrap();
        store.add_to_collection("Saved", id).unwrap();

        // Make the archive unreadable while keeping the exact stat fingerprint.
        let modified = std::fs::metadata(&book_path).unwrap().modified().unwrap();
        let size = std::fs::metadata(&book_path).unwrap().len() as usize;
        std::fs::write(&book_path, vec![0_u8; size]).unwrap();
        File::options()
            .write(true)
            .open(&book_path)
            .unwrap()
            .set_times(FileTimes::new().set_modified(modified))
            .unwrap();
        let unchanged = scan(&store, &roots, &covers).unwrap();
        assert_eq!((unchanged.unchanged, unchanged.unreadable.len()), (1, 0));
        assert_eq!(store.book(id).unwrap().title, "The Left Hand of Darkness");

        // A force scan parses the same fingerprint, diagnoses the failure, and keeps prior data.
        let forced_bad = scan_with_force(&store, &roots, &covers, true).unwrap();
        assert_eq!((forced_bad.forced, forced_bad.unreadable.len()), (true, 1));
        assert_eq!(store.book(id).unwrap().title, "The Left Hand of Darkness");
        assert_eq!(
            store.book(id).unwrap().location.as_deref(),
            Some("spine:0.5")
        );
        assert_eq!(store.status(id).unwrap(), crate::store::BookStatus::Paused);
        assert_eq!(store.highlights(id).unwrap()[0].quote, "kept");
        assert_eq!(store.collection("Saved").unwrap()[0].id, id);

        // Repair with a valid changed archive at the same path; history remains attached to id.
        write_epub(&book_path, true);
        let changed = scan(&store, &roots, &covers).unwrap();
        assert_eq!(changed.updated, 1);
        assert_eq!(store.books(None, false).unwrap()[0].id, id);
        assert_eq!(
            store.book(id).unwrap().location.as_deref(),
            Some("spine:0.5")
        );
        assert_eq!(store.status(id).unwrap(), crate::store::BookStatus::Paused);
        assert_eq!(store.highlights(id).unwrap()[0].quote, "kept");
        assert_eq!(store.collection("Saved").unwrap()[0].id, id);
        let forced_valid = scan_with_force(&store, &roots, &covers, true).unwrap();
        assert_eq!((forced_valid.updated, forced_valid.unchanged), (1, 0));
    }

    #[test]
    fn folder_audiobook_fingerprint_changes_when_a_member_is_added() {
        let dir = tempfile::tempdir().unwrap();
        let books = dir.path().join("books");
        let audio = dir.path().join("audiobooks/Dune");
        std::fs::create_dir_all(&books).unwrap();
        std::fs::create_dir_all(&audio).unwrap();
        std::fs::write(audio.join("01.mp3"), b"one").unwrap();
        let roots = Roots {
            books,
            audiobooks: dir.path().join("audiobooks"),
        };
        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let covers = dir.path().join("covers");

        let first = scan(&store, &roots, &covers).unwrap();
        assert_eq!(first.added, 1);
        let book = store.books(None, false).unwrap().remove(0);
        assert_eq!(book.kind, "audio-folder");
        assert_eq!(store.tracks(book.id).unwrap().len(), 1);
        assert_eq!(scan(&store, &roots, &covers).unwrap().unchanged, 1);

        std::fs::write(audio.join("02.mp3"), b"two").unwrap();
        let changed = scan(&store, &roots, &covers).unwrap();
        assert_eq!(changed.updated, 1);
        assert_eq!(store.books(None, false).unwrap()[0].id, book.id);
        assert_eq!(store.tracks(book.id).unwrap().len(), 2);

        std::fs::write(audio.join("01.mp3"), b"one changed size").unwrap();
        let changed_member = scan(&store, &roots, &covers).unwrap();
        assert_eq!(changed_member.updated, 1);
        assert_eq!(store.books(None, false).unwrap()[0].id, book.id);
        assert_eq!(store.tracks(book.id).unwrap().len(), 2);
    }

    #[test]
    fn missing_and_incomplete_roots_never_reconcile_old_books_as_missing() {
        let dir = tempfile::tempdir().unwrap();
        let books = dir.path().join("books");
        let audio = dir.path().join("audiobooks");
        std::fs::create_dir_all(&books).unwrap();
        std::fs::create_dir_all(&audio).unwrap();
        write_epub(&books.join("known.epub"), false);
        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let covers = dir.path().join("covers");
        let roots = Roots {
            books: books.clone(),
            audiobooks: audio,
        };
        scan(&store, &roots, &covers).unwrap();
        let id = store.books(None, false).unwrap()[0].id;

        std::fs::remove_dir_all(&books).unwrap();
        let missing_root = scan(&store, &roots, &covers).unwrap();
        assert_eq!(missing_root.missing, 0);
        assert!(!missing_root.incomplete_roots.is_empty());
        assert!(!store.book(id).unwrap().missing);

        std::fs::create_dir_all(&books).unwrap();
        let mut deep = books.clone();
        for index in 0..=MAX_DEPTH {
            deep.push(format!("d{index}"));
        }
        std::fs::create_dir_all(&deep).unwrap();
        let incomplete = scan(&store, &roots, &covers).unwrap();
        assert_eq!(incomplete.missing, 0);
        assert!(
            incomplete
                .diagnostics
                .iter()
                .any(|line| line.contains("depth limit"))
        );
        assert!(!store.book(id).unwrap().missing);
    }

    #[test]
    fn a_root_that_does_not_exist_is_skipped_not_emptied() {
        let dir = tempfile::tempdir().unwrap();
        let books = dir.path().join("books");
        std::fs::create_dir_all(&books).unwrap();
        write_epub(&books.join("a.epub"), true);
        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let roots = Roots {
            books,
            audiobooks: dir.path().join("nope"),
        };
        let report = scan(&store, &roots, &dir.path().join("covers")).unwrap();
        assert_eq!((report.found, report.missing), (1, 0));
    }
}
