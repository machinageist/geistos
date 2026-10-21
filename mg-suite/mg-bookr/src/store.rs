// Author: Jeff
// Date: 2026-09-19
// Description: mg-bookr's records — books, where you are in each, highlights, collections, chapters
// Notes: One SQLite file, $MG_BOOKR_DB or $XDG_DATA_HOME/mg-bookr/bookr.sqlite, WAL, foreign keys.
//        A book is known by its root ("books" | "audiobooks") and its path inside that root, so
//        pointing a root somewhere else keeps every book's history. A book that vanishes is
//        marked missing, never deleted: its progress and highlights wait for it to come back.
//        Migrations are append-only and recorded

use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{Context, Result, bail};
use chrono::Utc;
use rusqlite::{Connection, OptionalExtension, params};
use serde::Serialize;

use crate::secure_db;

const MIGRATIONS: &[&str] = &[
    "\
CREATE TABLE books (id INTEGER PRIMARY KEY, kind TEXT NOT NULL, root TEXT NOT NULL, path TEXT NOT NULL, \
  title TEXT NOT NULL, author TEXT, series TEXT, series_index REAL, cover TEXT, pages INTEGER, \
  duration_seconds REAL, added_at TEXT NOT NULL, missing INTEGER NOT NULL DEFAULT 0, UNIQUE(root, path)); \
CREATE TABLE progress (book_id INTEGER PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE, location TEXT NOT NULL, \
  percent REAL NOT NULL, finished INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL); \
CREATE TABLE highlights (id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE, \
  location TEXT NOT NULL, chapter TEXT, quote TEXT NOT NULL, note TEXT, color TEXT NOT NULL DEFAULT 'yellow', \
  created_at TEXT NOT NULL); \
CREATE TABLE collections (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE); \
CREATE TABLE collection_books (collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE, \
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE, PRIMARY KEY(collection_id, book_id)); \
CREATE TABLE tracks (book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE, idx INTEGER NOT NULL, \
  path TEXT NOT NULL, duration_seconds REAL, PRIMARY KEY(book_id, idx)); \
CREATE TABLE chapters (book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE, idx INTEGER NOT NULL, \
  title TEXT NOT NULL, start_seconds REAL NOT NULL, PRIMARY KEY(book_id, idx));",
    // M2: the speed an audiobook was last played at; a scan never touches it
    "ALTER TABLE books ADD COLUMN speed REAL;",
    // M3: how this book is read, pages or scroll; unset means the reader's own default
    "ALTER TABLE books ADD COLUMN reading_mode TEXT;",
    // M4: global reading status, manual per-list order, and persistent scan fingerprints
    "\
ALTER TABLE books ADD COLUMN status TEXT NOT NULL DEFAULT 'to-read'; \
UPDATE books SET status=CASE \
  WHEN EXISTS(SELECT 1 FROM progress p WHERE p.book_id=books.id AND p.finished=1) THEN 'finished' \
  WHEN EXISTS(SELECT 1 FROM progress p WHERE p.book_id=books.id AND p.percent<>0) THEN 'reading' \
  ELSE 'to-read' END; \
ALTER TABLE collection_books ADD COLUMN position INTEGER NOT NULL DEFAULT 0; \
UPDATE collection_books AS cb SET position=( \
  SELECT COUNT(*) FROM collection_books AS earlier \
  JOIN books AS eb ON eb.id=earlier.book_id \
  JOIN books AS current ON current.id=cb.book_id \
  WHERE earlier.collection_id=cb.collection_id AND \
    (eb.title COLLATE NOCASE < current.title COLLATE NOCASE OR \
     (eb.title COLLATE NOCASE=current.title COLLATE NOCASE AND earlier.book_id<cb.book_id))); \
CREATE INDEX collection_books_order ON collection_books(collection_id,position,book_id); \
CREATE TABLE scan_fingerprints (root TEXT NOT NULL, path TEXT NOT NULL, fingerprint TEXT NOT NULL, \
  PRIMARY KEY(root,path), FOREIGN KEY(root,path) REFERENCES books(root,path) ON DELETE CASCADE);",
];

// how a book can be read
pub const READING_MODES: [&str; 2] = ["pages", "scroll"];

// what kinds of book there are
pub const KINDS: [&str; 5] = ["epub", "pdf", "comic", "audio", "audio-folder"];
pub const MAX_BOOK_SEARCH_CHARS: usize = 200;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, clap::ValueEnum)]
#[serde(rename_all = "kebab-case")]
pub enum BookStatus {
    #[value(name = "to-read")]
    ToRead,
    Reading,
    Paused,
    Finished,
}

impl BookStatus {
    pub const ALL: [Self; 4] = [Self::ToRead, Self::Reading, Self::Paused, Self::Finished];

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::ToRead => "to-read",
            Self::Reading => "reading",
            Self::Paused => "paused",
            Self::Finished => "finished",
        }
    }

    pub fn parse(value: &str) -> Result<Self> {
        match value {
            "to-read" => Ok(Self::ToRead),
            "reading" => Ok(Self::Reading),
            "paused" => Ok(Self::Paused),
            "finished" => Ok(Self::Finished),
            _ => bail!("status is one of to-read, reading, paused, finished"),
        }
    }
}

impl std::fmt::Display for BookStatus {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(self.as_str())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CollectionSort {
    Manual,
    Title,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum BookSort {
    #[default]
    Recent,
    Title,
    Author,
    Series,
}

impl BookSort {
    pub fn label(self) -> &'static str {
        match self {
            BookSort::Recent => "recent",
            BookSort::Title => "title",
            BookSort::Author => "author",
            BookSort::Series => "series",
        }
    }

    fn order_by(self) -> &'static str {
        match self {
            // Keep the existing default order exactly as-is.
            BookSort::Recent => "p.updated_at IS NULL, p.updated_at DESC, b.title COLLATE NOCASE",
            BookSort::Title => "b.title COLLATE NOCASE, b.id",
            BookSort::Author => {
                "b.author IS NULL, b.author COLLATE NOCASE, b.title COLLATE NOCASE, b.id"
            }
            BookSort::Series => {
                "b.series IS NULL, b.series COLLATE NOCASE, b.series_index IS NULL, \
                b.series_index, b.title COLLATE NOCASE, b.id"
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Book {
    pub id: i64,
    pub kind: String,
    pub root: String,
    pub path: String,
    pub title: String,
    pub author: Option<String>,
    pub series: Option<String>,
    pub series_index: Option<f64>,
    pub cover: Option<String>,
    pub pages: Option<i64>,
    pub duration_seconds: Option<f64>,
    pub missing: bool,
    // progress, when there is any
    pub location: Option<String>,
    pub percent: Option<f64>,
    pub finished: bool,
    pub updated_at: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BookRecord {
    #[serde(flatten)]
    pub book: Book,
    pub status: BookStatus,
}

impl Book {
    pub fn matches_text(&self, query: &str) -> bool {
        let needle = query.trim().to_lowercase();
        needle.is_empty() || self.matches_folded(&needle)
    }

    fn matches_folded(&self, needle: &str) -> bool {
        std::iter::once(self.title.as_str())
            .chain(self.author.as_deref())
            .chain(self.series.as_deref())
            .chain(std::iter::once(self.path.as_str()))
            .any(|field| field.to_lowercase().contains(needle))
    }
}

// What a scan learned about one book, before it has an id
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Found {
    pub kind: String,
    pub root: String,
    pub path: String,
    pub title: String,
    pub author: Option<String>,
    pub series: Option<String>,
    pub series_index: Option<f64>,
    pub cover: Option<String>,
    pub pages: Option<i64>,
    pub duration_seconds: Option<f64>,
    // audiobooks: the files, in order, with their lengths
    pub tracks: Vec<(String, Option<f64>)>,
    // audiobooks: (title, start seconds) across the whole book
    pub chapters: Vec<(String, f64)>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ScanMetadata {
    Unchanged,
    Parsed(Found),
    Failed { fallback: Found, error: String },
}

#[derive(Debug, Clone, PartialEq)]
pub struct ScanRecord {
    pub root: String,
    pub path: String,
    pub fingerprint: String,
    pub metadata: ScanMetadata,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct ScanSaveReport {
    pub added: usize,
    pub updated: usize,
    pub unchanged: usize,
    pub missing: usize,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Highlight {
    pub id: i64,
    pub book_id: i64,
    pub location: String,
    pub chapter: Option<String>,
    pub quote: String,
    pub note: Option<String>,
    pub color: String,
    pub created_at: String,
}

pub struct Store {
    path: PathBuf,
}

// Resolve the application-owned data directory without falling back to a relative path
fn application_data_dir() -> PathBuf {
    dirs::data_dir()
        .or_else(|| dirs::home_dir().map(|home| home.join(".local/share")))
        .unwrap_or_else(|| PathBuf::from("/var/empty"))
        .join("mg-bookr")
}

// Accept an override only when it remains a database leaf in this application's data directory
fn approved_database_override(candidate: PathBuf, directory: &Path) -> Option<PathBuf> {
    (candidate.is_absolute()
        && candidate.file_name().is_some_and(|name| !name.is_empty())
        && candidate.parent() == Some(directory))
    .then_some(candidate)
}

// $MG_BOOKR_DB may select a file name in the app directory, else use the XDG data folder
pub fn default_path() -> PathBuf {
    let directory = application_data_dir();
    std::env::var_os("MG_BOOKR_DB")
        .map(PathBuf::from)
        .and_then(|candidate| approved_database_override(candidate, &directory))
        .unwrap_or_else(|| directory.join("bookr.sqlite"))
}

const BOOK_SELECT: &str = "SELECT b.id,b.kind,b.root,b.path,b.title,b.author,b.series,b.series_index,b.cover,b.pages, \
    b.duration_seconds,b.missing,p.location,p.percent,COALESCE(p.finished,0),p.updated_at \
    FROM books b LEFT JOIN progress p ON p.book_id=b.id";

fn book_from_row(r: &rusqlite::Row<'_>) -> rusqlite::Result<Book> {
    Ok(Book {
        id: r.get(0)?,
        kind: r.get(1)?,
        root: r.get(2)?,
        path: r.get(3)?,
        title: r.get(4)?,
        author: r.get(5)?,
        series: r.get(6)?,
        series_index: r.get(7)?,
        cover: r.get(8)?,
        pages: r.get(9)?,
        duration_seconds: r.get(10)?,
        missing: r.get::<_, i64>(11)? != 0,
        location: r.get(12)?,
        percent: r.get(13)?,
        finished: r.get::<_, i64>(14)? != 0,
        updated_at: r.get(15)?,
    })
}

fn highlight_from_row(r: &rusqlite::Row<'_>) -> rusqlite::Result<Highlight> {
    Ok(Highlight {
        id: r.get(0)?,
        book_id: r.get(1)?,
        location: r.get(2)?,
        chapter: r.get(3)?,
        quote: r.get(4)?,
        note: r.get(5)?,
        color: r.get(6)?,
        created_at: r.get(7)?,
    })
}

// highlight colours the reader offers
pub const COLORS: [&str; 5] = ["yellow", "green", "blue", "pink", "purple"];

impl Store {
    // Open (creating) the store and bring its schema up to date
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref().to_path_buf();
        let store = Store { path };
        let mut c = store.conn()?;
        let mode: String = c.query_row("PRAGMA journal_mode=WAL", [], |r| r.get(0))?;
        if !mode.eq_ignore_ascii_case("wal") {
            bail!("store could not switch to WAL (journal mode {mode})")
        }
        secure_db::ensure_database_sidecars(&store.path)?;
        let tx = c.transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)?;
        tx.execute_batch(
            "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY)",
        )?;
        let applied: i64 =
            tx.query_row("SELECT COUNT(*) FROM schema_migrations", [], |r| r.get(0))?;
        if applied as usize > MIGRATIONS.len() {
            bail!("this store was written by a newer mg-bookr")
        }
        for (index, sql) in MIGRATIONS.iter().enumerate().skip(applied as usize) {
            tx.execute_batch(sql)?;
            tx.execute(
                "INSERT INTO schema_migrations(version) VALUES (?1)",
                params![index as i64 + 1],
            )?;
        }
        tx.commit()?;
        Ok(store)
    }

    fn conn(&self) -> Result<Connection> {
        secure_db::prepare_database_path(&self.path)?;
        let c = secure_db::open_database(&self.path)
            .with_context(|| format!("opening {}", self.path.display()))?;
        c.busy_timeout(Duration::from_secs(5))?;
        c.execute_batch("PRAGMA foreign_keys = ON;")?;
        Ok(c)
    }

    // Record what a scan found: new books added, known ones refreshed (their history untouched),
    // and every book of these roots not seen this time marked missing. Returns (added, missing)
    pub fn save_scan(&self, roots: &[&str], found: &[Found]) -> Result<(usize, usize)> {
        let mut c = self.conn()?;
        let tx = c.transaction()?;
        let now = Utc::now().to_rfc3339();
        // everything starts presumed gone; each book found is marked back
        for root in roots {
            tx.execute(
                "UPDATE books SET missing=2 WHERE root=?1 AND missing=0",
                params![root],
            )?;
        }
        let mut added = 0;
        for f in found {
            let known: Option<i64> = tx
                .query_row(
                    "SELECT id FROM books WHERE root=?1 AND path=?2",
                    params![f.root, f.path],
                    |r| r.get(0),
                )
                .optional()?;
            let id = match known {
                Some(id) => {
                    tx.execute(
                        "UPDATE books SET kind=?1,title=?2,author=?3,series=?4,series_index=?5,cover=?6,pages=?7, \
                         duration_seconds=?8,missing=0 WHERE id=?9",
                        params![f.kind, f.title, f.author, f.series, f.series_index, f.cover, f.pages, f.duration_seconds, id],
                    )?;
                    id
                }
                None => {
                    tx.execute(
                        "INSERT INTO books(kind,root,path,title,author,series,series_index,cover,pages,duration_seconds,added_at) \
                         VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11)",
                        params![f.kind, f.root, f.path, f.title, f.author, f.series, f.series_index, f.cover, f.pages, f.duration_seconds, now],
                    )?;
                    added += 1;
                    tx.last_insert_rowid()
                }
            };
            // an audiobook's files and chapters are whatever the scan saw now
            tx.execute("DELETE FROM tracks WHERE book_id=?1", params![id])?;
            for (i, (path, duration)) in f.tracks.iter().enumerate() {
                tx.execute(
                    "INSERT INTO tracks(book_id,idx,path,duration_seconds) VALUES (?1,?2,?3,?4)",
                    params![id, i as i64, path, duration],
                )?;
            }
            tx.execute("DELETE FROM chapters WHERE book_id=?1", params![id])?;
            for (i, (title, start)) in f.chapters.iter().enumerate() {
                tx.execute(
                    "INSERT INTO chapters(book_id,idx,title,start_seconds) VALUES (?1,?2,?3,?4)",
                    params![id, i as i64, title, start],
                )?;
            }
        }
        let missing = tx.execute("UPDATE books SET missing=1 WHERE missing=2", [])?;
        tx.commit()?;
        Ok((added, missing))
    }

    // Incremental scan save: only complete roots participate in missing-book reconciliation.
    pub fn save_incremental_scan(
        &self,
        complete_roots: &[String],
        records: &[ScanRecord],
    ) -> Result<ScanSaveReport> {
        let mut connection = self.conn()?;
        let tx = connection.transaction()?;
        let now = Utc::now().to_rfc3339();
        for root in complete_roots {
            tx.execute(
                "UPDATE books SET missing=2 WHERE root=?1 AND missing=0",
                params![root],
            )?;
        }

        let mut report = ScanSaveReport::default();
        for record in records {
            let known: Option<i64> = tx
                .query_row(
                    "SELECT id FROM books WHERE root=?1 AND path=?2",
                    params![record.root, record.path],
                    |row| row.get(0),
                )
                .optional()?;
            match &record.metadata {
                ScanMetadata::Unchanged => {
                    let id = known.with_context(|| {
                        format!(
                            "unchanged fingerprint has no book {}/{}",
                            record.root, record.path
                        )
                    })?;
                    let saved: Option<String> = tx
                        .query_row(
                            "SELECT fingerprint FROM scan_fingerprints WHERE root=?1 AND path=?2",
                            params![record.root, record.path],
                            |row| row.get(0),
                        )
                        .optional()?;
                    if saved.as_deref() != Some(record.fingerprint.as_str()) {
                        bail!(
                            "stale unchanged fingerprint for {}/{}",
                            record.root,
                            record.path
                        )
                    }
                    tx.execute("UPDATE books SET missing=0 WHERE id=?1", params![id])?;
                    report.unchanged += 1;
                }
                ScanMetadata::Parsed(found) => {
                    if found.root != record.root || found.path != record.path {
                        bail!("scan metadata path does not match its fingerprint key")
                    }
                    let id = match known {
                        Some(id) => {
                            tx.execute(
                                "UPDATE books SET kind=?1,title=?2,author=?3,series=?4,series_index=?5,cover=?6,pages=?7, \
                                 duration_seconds=?8,missing=0 WHERE id=?9",
                                params![found.kind, found.title, found.author, found.series, found.series_index, found.cover, found.pages, found.duration_seconds, id],
                            )?;
                            report.updated += 1;
                            id
                        }
                        None => {
                            tx.execute(
                                "INSERT INTO books(kind,root,path,title,author,series,series_index,cover,pages,duration_seconds,added_at) \
                                 VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11)",
                                params![found.kind, found.root, found.path, found.title, found.author, found.series, found.series_index, found.cover, found.pages, found.duration_seconds, now],
                            )?;
                            report.added += 1;
                            tx.last_insert_rowid()
                        }
                    };
                    Self::replace_scan_children(&tx, id, found)?;
                    tx.execute(
                        "INSERT INTO scan_fingerprints(root,path,fingerprint) VALUES (?1,?2,?3) \
                         ON CONFLICT(root,path) DO UPDATE SET fingerprint=excluded.fingerprint",
                        params![record.root, record.path, record.fingerprint],
                    )?;
                }
                ScanMetadata::Failed { fallback, error: _ } => {
                    if fallback.root != record.root || fallback.path != record.path {
                        bail!("failed scan path does not match its fingerprint key")
                    }
                    if let Some(id) = known {
                        // Preserve the last good metadata, tracks, chapters and fingerprint.
                        tx.execute("UPDATE books SET missing=0 WHERE id=?1", params![id])?;
                    } else {
                        tx.execute(
                            "INSERT INTO books(kind,root,path,title,author,series,series_index,cover,pages,duration_seconds,added_at) \
                             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11)",
                            params![fallback.kind, fallback.root, fallback.path, fallback.title, fallback.author, fallback.series, fallback.series_index, fallback.cover, fallback.pages, fallback.duration_seconds, now],
                        )?;
                        report.added += 1;
                    }
                }
            }
        }
        report.missing = tx.execute("UPDATE books SET missing=1 WHERE missing=2", [])?;
        tx.commit()?;
        Ok(report)
    }

    fn replace_scan_children(tx: &rusqlite::Transaction<'_>, id: i64, found: &Found) -> Result<()> {
        tx.execute("DELETE FROM tracks WHERE book_id=?1", params![id])?;
        for (index, (path, duration)) in found.tracks.iter().enumerate() {
            tx.execute(
                "INSERT INTO tracks(book_id,idx,path,duration_seconds) VALUES (?1,?2,?3,?4)",
                params![id, index as i64, path, duration],
            )?;
        }
        tx.execute("DELETE FROM chapters WHERE book_id=?1", params![id])?;
        for (index, (title, start)) in found.chapters.iter().enumerate() {
            tx.execute(
                "INSERT INTO chapters(book_id,idx,title,start_seconds) VALUES (?1,?2,?3,?4)",
                params![id, index as i64, title, start],
            )?;
        }
        Ok(())
    }

    pub fn scan_fingerprint(&self, root: &str, path: &str) -> Result<Option<String>> {
        Ok(self
            .conn()?
            .query_row(
                "SELECT fingerprint FROM scan_fingerprints WHERE root=?1 AND path=?2",
                params![root, path],
                |row| row.get(0),
            )
            .optional()?)
    }

    pub fn scan_fingerprints(
        &self,
        root: &str,
    ) -> Result<std::collections::HashMap<String, String>> {
        let connection = self.conn()?;
        let mut statement = connection.prepare(
            "SELECT path,fingerprint FROM scan_fingerprints WHERE root=?1 ORDER BY path",
        )?;
        let rows = statement
            .query_map(params![root], |row| Ok((row.get(0)?, row.get(1)?)))?
            .collect::<rusqlite::Result<std::collections::HashMap<_, _>>>()?;
        Ok(rows)
    }

    // Keep the current default ordering and missing-book policy for existing callers.
    pub fn books(&self, kind: Option<&str>, include_missing: bool) -> Result<Vec<Book>> {
        self.books_sorted(kind, include_missing, BookSort::Recent)
    }

    pub fn books_sorted(
        &self,
        kind: Option<&str>,
        include_missing: bool,
        sort: BookSort,
    ) -> Result<Vec<Book>> {
        let c = self.conn()?;
        let query = format!(
            "{BOOK_SELECT} WHERE (?1 IS NULL OR b.kind=?1 OR (?1='audio' AND b.kind='audio-folder')) AND (?2=1 OR b.missing=0) \
             ORDER BY {}",
            sort.order_by()
        );
        let mut st = c.prepare(&query)?;
        let rows = st
            .query_map(params![kind, include_missing as i64], book_from_row)?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(rows)
    }

    // Search the existing library metadata without changing stored records or scan behavior.
    pub fn search_books(
        &self,
        query: &str,
        kind: Option<&str>,
        include_missing: bool,
        sort: BookSort,
        limit: usize,
    ) -> Result<Vec<Book>> {
        let query = query.trim();
        let characters = query.chars().count();
        if characters == 0 || characters > MAX_BOOK_SEARCH_CHARS {
            bail!("search text is 1–{MAX_BOOK_SEARCH_CHARS} characters")
        }
        let needle = query.to_lowercase();
        Ok(self
            .books_sorted(kind, include_missing, sort)?
            .into_iter()
            .filter(|book| book.matches_folded(&needle))
            .take(limit.clamp(1, 1000))
            .collect())
    }

    pub fn book(&self, id: i64) -> Result<Book> {
        self.conn()?
            .query_row(
                &format!("{BOOK_SELECT} WHERE b.id=?1"),
                params![id],
                book_from_row,
            )
            .optional()?
            .with_context(|| format!("no book {id}"))
    }

    pub fn status(&self, id: i64) -> Result<BookStatus> {
        let status: Option<String> = self
            .conn()?
            .query_row("SELECT status FROM books WHERE id=?1", params![id], |row| {
                row.get(0)
            })
            .optional()?;
        BookStatus::parse(&status.with_context(|| format!("no book {id}"))?)
    }

    pub fn records_for_books(&self, books: &[Book]) -> Result<Vec<BookRecord>> {
        let connection = self.conn()?;
        let mut statement = connection.prepare("SELECT status FROM books WHERE id=?1")?;
        books
            .iter()
            .map(|book| {
                let status: String = statement
                    .query_row(params![book.id], |row| row.get(0))
                    .with_context(|| format!("no book {}", book.id))?;
                Ok(BookRecord {
                    book: book.clone(),
                    status: BookStatus::parse(&status)?,
                })
            })
            .collect()
    }

    pub fn book_record(&self, id: i64) -> Result<BookRecord> {
        let book = self.book(id)?;
        Ok(self.records_for_books(&[book])?.remove(0))
    }

    // Books started and not finished, most recent first — "continue reading / listening"
    pub fn in_progress(&self, limit: usize) -> Result<Vec<Book>> {
        let c = self.conn()?;
        let mut st = c.prepare(&format!(
            "{BOOK_SELECT} WHERE p.book_id IS NOT NULL AND p.finished=0 AND b.missing=0 ORDER BY p.updated_at DESC LIMIT ?1"
        ))?;
        let rows = st
            .query_map(params![limit.clamp(1, 100) as i64], book_from_row)?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(rows)
    }

    pub fn set_status(&self, id: i64, status: BookStatus) -> Result<()> {
        let changed = self.conn()?.execute(
            "UPDATE books SET status=?2 WHERE id=?1",
            params![id, status.as_str()],
        )?;
        if changed != 1 {
            bail!("no book {id}")
        }
        Ok(())
    }

    pub fn set_status_many(&self, ids: &[i64], status: BookStatus) -> Result<usize> {
        if ids.is_empty() {
            bail!("at least one book id is required")
        }
        let mut c = self.conn()?;
        let tx = c.transaction()?;
        let mut unique = std::collections::HashSet::new();
        for id in ids.iter().copied().filter(|id| unique.insert(*id)) {
            let exists: bool = tx.query_row(
                "SELECT EXISTS(SELECT 1 FROM books WHERE id=?1)",
                params![id],
                |row| row.get(0),
            )?;
            if !exists {
                bail!("no book {id}")
            }
            tx.execute(
                "UPDATE books SET status=?2 WHERE id=?1",
                params![id, status.as_str()],
            )?;
        }
        let count = unique.len();
        tx.commit()?;
        Ok(count)
    }

    // Opening a to-read or paused book starts it; explicit statuses otherwise stay untouched.
    pub fn mark_opened(&self, id: i64) -> Result<()> {
        let mut c = self.conn()?;
        let tx = c.transaction()?;
        let changed = tx.execute(
            "UPDATE books SET status='reading' WHERE id=?1 AND status IN ('to-read','paused')",
            params![id],
        )?;
        let exists: bool = tx.query_row(
            "SELECT EXISTS(SELECT 1 FROM books WHERE id=?1)",
            params![id],
            |row| row.get(0),
        )?;
        if !exists {
            bail!("no book {id}")
        }
        let _ = changed;
        tx.commit()?;
        Ok(())
    }

    // Remember where you are; 99.5% or more counts as finished unless told otherwise
    pub fn set_progress(
        &self,
        id: i64,
        location: &str,
        percent: f64,
        finished: Option<bool>,
    ) -> Result<()> {
        if location.is_empty() || location.len() > 200 {
            bail!("a location is 1–200 characters")
        }
        let percent = percent.clamp(0.0, 100.0);
        let finished = finished.unwrap_or(percent >= 99.5);
        let mut c = self.conn()?;
        let tx = c.transaction()?;
        let changed = tx.execute(
            "INSERT INTO progress(book_id,location,percent,finished,updated_at) SELECT id,?2,?3,?4,?5 FROM books WHERE id=?1 \
             ON CONFLICT(book_id) DO UPDATE SET location=excluded.location,percent=excluded.percent, \
             finished=excluded.finished,updated_at=excluded.updated_at",
            params![id, location, percent, finished as i64, Utc::now().to_rfc3339()],
        )?;
        if changed == 0 {
            bail!("no book {id}")
        }
        if finished {
            tx.execute(
                "UPDATE books SET status='finished' WHERE id=?1",
                params![id],
            )?;
        }
        tx.commit()?;
        Ok(())
    }

    pub fn tracks(&self, id: i64) -> Result<Vec<(String, Option<f64>)>> {
        let c = self.conn()?;
        let mut st =
            c.prepare("SELECT path,duration_seconds FROM tracks WHERE book_id=?1 ORDER BY idx")?;
        let rows = st
            .query_map(params![id], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(rows)
    }

    pub fn chapters(&self, id: i64) -> Result<Vec<(String, f64)>> {
        let c = self.conn()?;
        let mut st =
            c.prepare("SELECT title,start_seconds FROM chapters WHERE book_id=?1 ORDER BY idx")?;
        let rows = st
            .query_map(params![id], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(rows)
    }

    // Remember the speed an audiobook was last played at
    pub fn set_speed(&self, id: i64, speed: f64) -> Result<()> {
        if !speed.is_finite() || speed <= 0.0 {
            bail!("a speed is a positive number")
        }
        let changed = self
            .conn()?
            .execute("UPDATE books SET speed=?2 WHERE id=?1", params![id, speed])?;
        if changed == 0 {
            bail!("no book {id}")
        }
        Ok(())
    }

    // The speed an audiobook was last played at, if it has been played
    pub fn speed(&self, id: i64) -> Result<Option<f64>> {
        self.conn()?
            .query_row("SELECT speed FROM books WHERE id=?1", params![id], |r| {
                r.get(0)
            })
            .optional()?
            .with_context(|| format!("no book {id}"))
    }

    // Remember whether this book is read in pages or as one scroll
    pub fn set_mode(&self, id: i64, mode: &str) -> Result<()> {
        if !READING_MODES.contains(&mode) {
            bail!("a reading mode is {}", READING_MODES.join(" or "))
        }
        let changed = self.conn()?.execute(
            "UPDATE books SET reading_mode=?2 WHERE id=?1",
            params![id, mode],
        )?;
        if changed == 0 {
            bail!("no book {id}")
        }
        Ok(())
    }

    // How this book is read, if it has been said
    pub fn mode(&self, id: i64) -> Result<Option<String>> {
        self.conn()?
            .query_row(
                "SELECT reading_mode FROM books WHERE id=?1",
                params![id],
                |r| r.get(0),
            )
            .optional()?
            .with_context(|| format!("no book {id}"))
    }

    // ── Highlights ──

    pub fn add_highlight(
        &self,
        book_id: i64,
        location: &str,
        chapter: Option<&str>,
        quote: &str,
        note: Option<&str>,
        color: &str,
    ) -> Result<i64> {
        if quote.trim().is_empty() || quote.len() > 10_000 {
            bail!("a highlight quotes 1–10000 characters")
        }
        if !COLORS.contains(&color) {
            bail!("colour is one of {}", COLORS.join(", "))
        }
        let c = self.conn()?;
        c.execute(
            "INSERT INTO highlights(book_id,location,chapter,quote,note,color,created_at) SELECT id,?2,?3,?4,?5,?6,?7 FROM books WHERE id=?1",
            params![book_id, location, chapter, quote.trim(), note.map(str::trim).filter(|n| !n.is_empty()), color, Utc::now().to_rfc3339()],
        )?;
        if c.changes() == 0 {
            bail!("no book {book_id}")
        }
        Ok(c.last_insert_rowid())
    }

    pub fn highlights(&self, book_id: i64) -> Result<Vec<Highlight>> {
        let c = self.conn()?;
        let mut st = c.prepare(
            "SELECT id,book_id,location,chapter,quote,note,color,created_at FROM highlights WHERE book_id=?1 ORDER BY id",
        )?;
        let rows = st
            .query_map(params![book_id], highlight_from_row)?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(rows)
    }

    // Change a highlight's note (empty clears it); returns its book
    pub fn set_note(&self, id: i64, note: &str) -> Result<i64> {
        let c = self.conn()?;
        let note = Some(note.trim()).filter(|n| !n.is_empty());
        if c.execute(
            "UPDATE highlights SET note=?1 WHERE id=?2",
            params![note, id],
        )? != 1
        {
            bail!("no highlight {id}")
        }
        Ok(c.query_row(
            "SELECT book_id FROM highlights WHERE id=?1",
            params![id],
            |r| r.get(0),
        )?)
    }

    // Remove a highlight; returns its book
    pub fn remove_highlight(&self, id: i64) -> Result<i64> {
        let c = self.conn()?;
        let book: i64 = c
            .query_row(
                "SELECT book_id FROM highlights WHERE id=?1",
                params![id],
                |r| r.get(0),
            )
            .optional()?
            .with_context(|| format!("no highlight {id}"))?;
        c.execute("DELETE FROM highlights WHERE id=?1", params![id])?;
        Ok(book)
    }

    // ── Collections ──

    fn checked_collection_name(name: &str) -> Result<&str> {
        let name = name.trim();
        if name.is_empty() || name.len() > 80 {
            bail!("a collection name is 1–80 characters")
        }
        Ok(name)
    }

    fn collection_id_in(connection: &rusqlite::Connection, name: &str) -> Result<i64> {
        connection
            .query_row(
                "SELECT id FROM collections WHERE name=?1",
                params![name],
                |row| row.get(0),
            )
            .optional()?
            .with_context(|| format!("no collection {name}"))
    }

    fn normalize_collection_order(
        tx: &rusqlite::Transaction<'_>,
        collection_id: i64,
    ) -> Result<()> {
        let ids = {
            let mut statement = tx.prepare(
                "SELECT book_id FROM collection_books WHERE collection_id=?1 ORDER BY position,book_id",
            )?;
            statement
                .query_map(params![collection_id], |row| row.get::<_, i64>(0))?
                .collect::<rusqlite::Result<Vec<_>>>()?
        };
        for (position, book_id) in ids.into_iter().enumerate() {
            tx.execute(
                "UPDATE collection_books SET position=?3 WHERE collection_id=?1 AND book_id=?2",
                params![collection_id, book_id, position as i64],
            )?;
        }
        Ok(())
    }

    pub fn create_collection(&self, name: &str) -> Result<i64> {
        let name = Self::checked_collection_name(name)?;
        let connection = self.conn()?;
        connection.execute("INSERT INTO collections(name) VALUES (?1)", params![name])?;
        Ok(connection.last_insert_rowid())
    }

    pub fn collection_id(&self, name: &str) -> Result<i64> {
        Self::collection_id_in(&self.conn()?, name)
    }

    pub fn rename_collection(&self, old_name: &str, new_name: &str) -> Result<()> {
        let old_name = old_name.trim();
        let new_name = Self::checked_collection_name(new_name)?;
        let connection = self.conn()?;
        if connection.execute(
            "UPDATE collections SET name=?2 WHERE name=?1",
            params![old_name, new_name],
        )? != 1
        {
            bail!("no collection {old_name}")
        }
        Ok(())
    }

    pub fn delete_collection(&self, name: &str) -> Result<()> {
        let connection = self.conn()?;
        if connection.execute(
            "DELETE FROM collections WHERE name=?1",
            params![name.trim()],
        )? != 1
        {
            bail!("no collection {}", name.trim())
        }
        Ok(())
    }

    pub fn add_to_collection(&self, name: &str, book_id: i64) -> Result<usize> {
        self.add_many_to_collection(name, &[book_id])
    }

    pub fn add_many_to_collection(&self, name: &str, book_ids: &[i64]) -> Result<usize> {
        let name = name.trim();
        if book_ids.is_empty() {
            bail!("at least one book id is required")
        }
        let mut connection = self.conn()?;
        let tx = connection.transaction()?;
        let collection_id = Self::collection_id_in(&tx, name)?;
        let mut unique = std::collections::HashSet::new();
        let ids = book_ids
            .iter()
            .copied()
            .filter(|id| unique.insert(*id))
            .collect::<Vec<_>>();
        for book_id in &ids {
            let exists: bool = tx.query_row(
                "SELECT EXISTS(SELECT 1 FROM books WHERE id=?1)",
                params![book_id],
                |row| row.get(0),
            )?;
            if !exists {
                bail!("no book {book_id}")
            }
        }
        let mut position: i64 = tx.query_row(
            "SELECT COALESCE(MAX(position)+1,0) FROM collection_books WHERE collection_id=?1",
            params![collection_id],
            |row| row.get(0),
        )?;
        let mut added = 0;
        for book_id in ids {
            let inserted = tx.execute(
                "INSERT OR IGNORE INTO collection_books(collection_id,book_id,position) VALUES (?1,?2,?3)",
                params![collection_id, book_id, position],
            )?;
            if inserted == 1 {
                position += 1;
                added += 1;
            }
        }
        tx.commit()?;
        Ok(added)
    }

    pub fn remove_from_collection(&self, name: &str, book_id: i64) -> Result<usize> {
        self.remove_many_from_collection(name, &[book_id])
    }

    pub fn remove_many_from_collection(&self, name: &str, book_ids: &[i64]) -> Result<usize> {
        if book_ids.is_empty() {
            bail!("at least one book id is required")
        }
        let mut connection = self.conn()?;
        let tx = connection.transaction()?;
        let collection_id = Self::collection_id_in(&tx, name.trim())?;
        let mut unique = std::collections::HashSet::new();
        let mut removed = 0;
        for book_id in book_ids.iter().copied().filter(|id| unique.insert(*id)) {
            removed += tx.execute(
                "DELETE FROM collection_books WHERE collection_id=?1 AND book_id=?2",
                params![collection_id, book_id],
            )?;
        }
        Self::normalize_collection_order(&tx, collection_id)?;
        tx.commit()?;
        Ok(removed)
    }

    pub fn reorder_collection(&self, name: &str, book_id: i64, position: usize) -> Result<()> {
        let mut connection = self.conn()?;
        let tx = connection.transaction()?;
        let collection_id = Self::collection_id_in(&tx, name.trim())?;
        let mut ids = {
            let mut statement = tx.prepare(
                "SELECT book_id FROM collection_books WHERE collection_id=?1 ORDER BY position,book_id",
            )?;
            statement
                .query_map(params![collection_id], |row| row.get::<_, i64>(0))?
                .collect::<rusqlite::Result<Vec<_>>>()?
        };
        let current = ids
            .iter()
            .position(|id| *id == book_id)
            .with_context(|| format!("book {book_id} is not in collection {name}"))?;
        if position >= ids.len() {
            bail!(
                "collection position must be between 0 and {}",
                ids.len() - 1
            )
        }
        let moved = ids.remove(current);
        ids.insert(position, moved);
        for (new_position, id) in ids.into_iter().enumerate() {
            tx.execute(
                "UPDATE collection_books SET position=?3 WHERE collection_id=?1 AND book_id=?2",
                params![collection_id, id, new_position as i64],
            )?;
        }
        tx.commit()?;
        Ok(())
    }

    // Compatibility helper: older callers can still create a list implicitly.
    pub fn collect(&self, name: &str, book_id: i64) -> Result<()> {
        let name = Self::checked_collection_name(name)?;
        let mut connection = self.conn()?;
        let tx = connection.transaction()?;
        let exists: bool = tx.query_row(
            "SELECT EXISTS(SELECT 1 FROM books WHERE id=?1)",
            params![book_id],
            |row| row.get(0),
        )?;
        if !exists {
            bail!("no book {book_id}")
        }
        tx.execute(
            "INSERT INTO collections(name) VALUES (?1) ON CONFLICT(name) DO NOTHING",
            params![name],
        )?;
        let collection_id = Self::collection_id_in(&tx, name)?;
        let position: i64 = tx.query_row(
            "SELECT COALESCE(MAX(position)+1,0) FROM collection_books WHERE collection_id=?1",
            params![collection_id],
            |row| row.get(0),
        )?;
        tx.execute(
            "INSERT OR IGNORE INTO collection_books(collection_id,book_id,position) VALUES (?1,?2,?3)",
            params![collection_id, book_id, position],
        )?;
        tx.commit()?;
        Ok(())
    }

    pub fn uncollect(&self, name: &str, book_id: i64) -> Result<()> {
        let mut connection = self.conn()?;
        let tx = connection.transaction()?;
        let maybe_id: Option<i64> = tx
            .query_row(
                "SELECT id FROM collections WHERE name=?1",
                params![name],
                |row| row.get(0),
            )
            .optional()?;
        if let Some(collection_id) = maybe_id {
            tx.execute(
                "DELETE FROM collection_books WHERE book_id=?2 AND collection_id=?1",
                params![collection_id, book_id],
            )?;
            Self::normalize_collection_order(&tx, collection_id)?;
        }
        tx.commit()?;
        Ok(())
    }

    // Each collection with how many books it holds
    pub fn collections(&self) -> Result<Vec<(String, i64)>> {
        let c = self.conn()?;
        let mut st = c.prepare(
            "SELECT c.name, COUNT(cb.book_id) FROM collections c LEFT JOIN collection_books cb ON cb.collection_id=c.id GROUP BY c.id ORDER BY c.name COLLATE NOCASE",
        )?;
        let rows = st
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(rows)
    }

    // Manual membership order is the default. Title order is a view only.
    pub fn collection(&self, name: &str) -> Result<Vec<Book>> {
        self.collection_sorted(name, CollectionSort::Manual)
    }

    pub fn collection_sorted(&self, name: &str, sort: CollectionSort) -> Result<Vec<Book>> {
        let order = match sort {
            CollectionSort::Manual => "cb.position,cb.book_id",
            CollectionSort::Title => "b.title COLLATE NOCASE,b.id",
        };
        let query = format!(
            "{BOOK_SELECT} JOIN collection_books cb ON cb.book_id=b.id JOIN collections c ON c.id=cb.collection_id WHERE c.name=?1 ORDER BY {order}"
        );
        let connection = self.conn()?;
        let mut statement = connection.prepare(&query)?;
        let rows = statement
            .query_map(params![name], book_from_row)?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(rows)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn found(root: &str, path: &str, title: &str) -> Found {
        Found {
            kind: "epub".into(),
            root: root.into(),
            path: path.into(),
            title: title.into(),
            ..Default::default()
        }
    }

    fn store() -> (tempfile::TempDir, Store) {
        let dir = tempfile::tempdir().unwrap();
        let s = Store::open(dir.path().join("b.sqlite")).unwrap();
        (dir, s)
    }

    #[test]
    fn a_rescan_keeps_history_and_a_vanished_book_waits_as_missing() {
        let (_d, s) = store();
        assert_eq!(
            s.save_scan(
                &["books"],
                &[found("books", "a.epub", "A"), found("books", "b.epub", "B")]
            )
            .unwrap(),
            (2, 0)
        );
        let a = s
            .books(None, false)
            .unwrap()
            .into_iter()
            .find(|b| b.title == "A")
            .unwrap();
        s.set_progress(a.id, "3:0.5", 40.0, None).unwrap();
        s.add_highlight(a.id, "3:0.5", Some("Ch 3"), "a line", None, "yellow")
            .unwrap();
        // a.epub disappears
        assert_eq!(
            s.save_scan(&["books"], &[found("books", "b.epub", "B")])
                .unwrap(),
            (0, 1)
        );
        assert_eq!(s.books(None, false).unwrap().len(), 1);
        assert!(s.book(a.id).unwrap().missing);
        // and comes back with everything intact
        assert_eq!(
            s.save_scan(
                &["books"],
                &[
                    found("books", "a.epub", "A2"),
                    found("books", "b.epub", "B")
                ]
            )
            .unwrap(),
            (0, 0)
        );
        let back = s.book(a.id).unwrap();
        assert_eq!(
            (back.title.as_str(), back.missing, back.location.as_deref()),
            ("A2", false, Some("3:0.5"))
        );
        assert_eq!(s.highlights(a.id).unwrap().len(), 1);
    }

    #[test]
    fn a_speed_is_kept_per_book_and_survives_a_rescan() {
        let (_d, s) = store();
        let roots = [crate::scan::AUDIOBOOKS];
        s.save_scan(&roots, &[found(crate::scan::AUDIOBOOKS, "a.m4b", "A")])
            .unwrap();
        let id = s.books(None, false).unwrap()[0].id;
        assert_eq!(s.speed(id).unwrap(), None);
        s.set_speed(id, 1.75).unwrap();
        s.save_scan(
            &roots,
            &[found(crate::scan::AUDIOBOOKS, "a.m4b", "A again")],
        )
        .unwrap();
        assert_eq!(s.speed(id).unwrap(), Some(1.75));
        assert!(s.set_speed(id, f64::NAN).is_err());
        assert!(s.set_speed(999, 1.0).is_err());
        assert!(s.speed(999).is_err());
    }

    #[test]
    fn a_reading_mode_is_kept_per_book() {
        let (_d, s) = store();
        s.save_scan(&["books"], &[found("books", "a.epub", "A")])
            .unwrap();
        let id = s.books(None, false).unwrap()[0].id;
        assert_eq!(
            s.mode(id).unwrap(),
            None,
            "the reader decides until it is said"
        );
        s.set_mode(id, "scroll").unwrap();
        s.save_scan(&["books"], &[found("books", "a.epub", "A")])
            .unwrap();
        assert_eq!(
            s.mode(id).unwrap().as_deref(),
            Some("scroll"),
            "a rescan keeps it"
        );
        assert!(s.set_mode(id, "sideways").is_err());
        assert!(s.mode(999).is_err());
    }

    #[test]
    fn a_scan_of_one_root_leaves_the_other_alone() {
        let (_d, s) = store();
        s.save_scan(
            &["books", "audiobooks"],
            &[found("books", "a.epub", "A"), found("audiobooks", "x", "X")],
        )
        .unwrap();
        s.save_scan(&["books"], &[found("books", "a.epub", "A")])
            .unwrap();
        assert_eq!(
            s.books(None, false).unwrap().len(),
            2,
            "the audiobook was not in this scan's roots"
        );
    }

    #[test]
    fn book_search_matches_existing_metadata_case_insensitively_and_respects_filters() {
        let (_d, store) = store();
        let mut left = found(
            "books",
            "science-fiction/left-hand.epub",
            "The Left Hand of Darkness",
        );
        left.author = Some("Ursula K. Le Guin".into());
        left.series = Some("Hainish Cycle".into());
        let mut wizard = found("books", "fantasy/wizard.epub", "A Wizard of Earthsea");
        wizard.author = Some("Ursula K. Le Guin".into());
        wizard.series = Some("Earthsea".into());
        let mut atuan = found("books", "fantasy/atuan.epub", "The Tombs of Atuan");
        atuan.author = Some("Ursula K. Le Guin".into());
        atuan.series = Some("Earthsea".into());
        let mut audio = found("audiobooks", "earthsea.m4b", "Earthsea Audiobook");
        audio.kind = "audio".into();
        audio.author = Some("Ursula K. Le Guin".into());
        audio.series = Some("Earthsea".into());
        store
            .save_scan(&["books", "audiobooks"], &[left, wizard, atuan, audio])
            .unwrap();

        let all = store
            .search_books("  URSULA K. LE GUIN  ", None, false, BookSort::Title, 10)
            .unwrap();
        assert_eq!(all.len(), 4);
        assert_eq!(all[0].title, "A Wizard of Earthsea");
        assert_eq!(all[3].title, "The Tombs of Atuan");

        let series = store
            .search_books("earthsea", Some("epub"), false, BookSort::Series, 10)
            .unwrap();
        assert_eq!(
            series
                .iter()
                .map(|book| book.title.as_str())
                .collect::<Vec<_>>(),
            ["A Wizard of Earthsea", "The Tombs of Atuan"]
        );
        let by_path = store
            .search_books("SCIENCE-FICTION", None, false, BookSort::Title, 10)
            .unwrap();
        assert_eq!(by_path.len(), 1);
        assert_eq!(by_path[0].title, "The Left Hand of Darkness");
        store.save_scan(&["books"], &[]).unwrap();
        assert!(
            store
                .search_books("left-hand", None, false, BookSort::Title, 10)
                .unwrap()
                .is_empty(),
            "missing books stay hidden unless requested"
        );
        assert_eq!(
            store
                .search_books("left-hand", None, true, BookSort::Title, 10)
                .unwrap()
                .len(),
            1
        );
        assert!(
            store
                .search_books("   ", None, false, BookSort::Recent, 10)
                .is_err()
        );
        assert!(
            store
                .search_books(&"x".repeat(201), None, false, BookSort::Recent, 10)
                .is_err()
        );
    }

    #[test]
    fn library_sorts_are_explicit_and_recent_remains_the_default() {
        let (_d, store) = store();
        let mut z = found("books", "z.epub", "Zulu");
        z.author = Some("Zed".into());
        z.series = Some("Later Series".into());
        z.series_index = Some(2.0);
        let mut a = found("books", "a.epub", "Alpha");
        a.author = Some("Ada".into());
        a.series = Some("Earlier Series".into());
        a.series_index = Some(1.0);
        let mut unknown = found("books", "m.epub", "Middle");
        unknown.series = None;
        store.save_scan(&["books"], &[z, a, unknown]).unwrap();

        let recent = store.books(None, false).unwrap();
        assert_eq!(
            recent
                .iter()
                .map(|book| book.title.as_str())
                .collect::<Vec<_>>(),
            ["Alpha", "Middle", "Zulu"],
            "no-progress books keep the existing title tie-break order"
        );
        assert_eq!(
            recent.iter().map(|book| book.id).collect::<Vec<_>>(),
            store
                .books_sorted(None, false, BookSort::Recent)
                .unwrap()
                .iter()
                .map(|book| book.id)
                .collect::<Vec<_>>()
        );
        assert_eq!(
            store
                .books_sorted(None, false, BookSort::Title)
                .unwrap()
                .iter()
                .map(|book| book.title.as_str())
                .collect::<Vec<_>>(),
            ["Alpha", "Middle", "Zulu"]
        );
        assert_eq!(
            store
                .books_sorted(None, false, BookSort::Author)
                .unwrap()
                .iter()
                .map(|book| book.title.as_str())
                .collect::<Vec<_>>(),
            ["Alpha", "Zulu", "Middle"]
        );
        assert_eq!(
            store
                .books_sorted(None, false, BookSort::Series)
                .unwrap()
                .iter()
                .map(|book| book.title.as_str())
                .collect::<Vec<_>>(),
            ["Alpha", "Zulu", "Middle"]
        );
    }

    #[test]
    fn continue_reading_is_the_recent_unfinished_ones() {
        let (_d, s) = store();
        s.save_scan(
            &["books"],
            &[
                found("books", "a.epub", "A"),
                found("books", "b.epub", "B"),
                found("books", "c.epub", "C"),
            ],
        )
        .unwrap();
        let ids: Vec<i64> = s.books(None, false).unwrap().iter().map(|b| b.id).collect();
        s.set_progress(ids[0], "1", 10.0, None).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(5));
        s.set_progress(ids[1], "9", 99.8, None).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(5));
        s.set_progress(ids[2], "2", 20.0, None).unwrap();
        let reading: Vec<i64> = s.in_progress(10).unwrap().iter().map(|b| b.id).collect();
        assert_eq!(
            reading,
            [ids[2], ids[0]],
            "newest first; the finished one is gone"
        );
        assert!(s.book(ids[1]).unwrap().finished);
        assert!(s.set_progress(999, "1", 1.0, None).is_err());
    }

    #[test]
    fn highlights_notes_and_collections() {
        let (_d, s) = store();
        s.save_scan(&["books"], &[found("books", "a.epub", "A")])
            .unwrap();
        let id = s.books(None, false).unwrap()[0].id;
        let h = s
            .add_highlight(id, "1:0.1", None, "  quoted  ", Some(" thought "), "green")
            .unwrap();
        assert!(
            s.add_highlight(id, "1", None, "x", None, "chartreuse")
                .is_err()
        );
        assert!(
            s.add_highlight(id, "1", None, "   ", None, "yellow")
                .is_err()
        );
        assert_eq!(s.highlights(id).unwrap()[0].quote, "quoted");
        assert_eq!(s.set_note(h, "").unwrap(), id);
        assert_eq!(s.highlights(id).unwrap()[0].note, None);
        s.collect("Sci-fi", id).unwrap();
        s.collect("Sci-fi", id).unwrap();
        assert_eq!(s.collections().unwrap(), [("Sci-fi".to_string(), 1)]);
        assert_eq!(s.collection("Sci-fi").unwrap()[0].id, id);
        assert!(s.collect("X", 999).is_err());
        assert_eq!(s.collections().unwrap(), [("Sci-fi".to_string(), 1)]);
        s.uncollect("Sci-fi", id).unwrap();
        assert_eq!(s.collections().unwrap()[0].1, 0);
        assert_eq!(s.remove_highlight(h).unwrap(), id);
        assert!(s.remove_highlight(h).is_err());
    }

    #[test]
    fn v3_migration_backfills_status_and_deterministic_manual_collection_order() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("legacy.sqlite");
        {
            let conn = Connection::open(&path).unwrap();
            conn.execute_batch("CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY);")
                .unwrap();
            for (index, migration) in MIGRATIONS.iter().take(3).enumerate() {
                conn.execute_batch(migration).unwrap();
                conn.execute(
                    "INSERT INTO schema_migrations(version) VALUES (?1)",
                    [index as i64 + 1],
                )
                .unwrap();
            }
            conn.execute_batch(
                "INSERT INTO books(id,kind,root,path,title,added_at) VALUES
                    (1,'epub','books','finished.epub','Finished','now'),
                    (2,'epub','books','reading.epub','Reading','now'),
                    (3,'epub','books','unstarted.epub','Unstarted','now'),
                    (4,'epub','books','zulu.epub','Zulu','now'),
                    (5,'epub','books','alpha.epub','Alpha','now');
                 INSERT INTO progress(book_id,location,percent,finished,updated_at) VALUES
                    (1,'1',0,1,'now'), (2,'2',25,0,'now');
                 INSERT INTO collections(id,name) VALUES (1,'Legacy');
                 INSERT INTO collection_books(collection_id,book_id) VALUES (1,4),(1,5);",
            )
            .unwrap();
        }

        let store = Store::open(&path).unwrap();
        assert_eq!(store.status(1).unwrap(), BookStatus::Finished);
        assert_eq!(store.status(2).unwrap(), BookStatus::Reading);
        assert_eq!(store.status(3).unwrap(), BookStatus::ToRead);
        assert_eq!(
            store
                .collection("Legacy")
                .unwrap()
                .iter()
                .map(|b| b.title.as_str())
                .collect::<Vec<_>>(),
            ["Alpha", "Zulu"]
        );
        let reopened = Store::open(&path).unwrap();
        assert_eq!(reopened.status(1).unwrap(), BookStatus::Finished);
        assert_eq!(reopened.collection("Legacy").unwrap().len(), 2);
    }

    #[test]
    fn statuses_transition_without_changing_saved_position_and_bulk_updates_are_atomic() {
        let (_dir, store) = store();
        store
            .save_scan(
                &["books"],
                &[found("books", "a.epub", "A"), found("books", "b.epub", "B")],
            )
            .unwrap();
        let books = store.books(None, false).unwrap();
        let (a, b) = (books[0].id, books[1].id);
        assert_eq!(store.status(a).unwrap(), BookStatus::ToRead);
        assert_eq!(
            serde_json::to_value(store.book_record(a).unwrap()).unwrap()["status"],
            "to-read"
        );
        store
            .set_progress(a, "spine:0.4", 42.0, Some(false))
            .unwrap();
        store.mark_opened(a).unwrap();
        assert_eq!(store.status(a).unwrap(), BookStatus::Reading);
        store.set_status(a, BookStatus::Paused).unwrap();
        store.mark_opened(a).unwrap();
        assert_eq!(store.status(a).unwrap(), BookStatus::Reading);
        store.set_status(a, BookStatus::Paused).unwrap();
        store.set_progress(a, "spine:0.8", 99.8, None).unwrap();
        let finished = store.book(a).unwrap();
        assert_eq!(store.status(a).unwrap(), BookStatus::Finished);
        assert_eq!(
            (finished.location.as_deref(), finished.percent),
            (Some("spine:0.8"), Some(99.8))
        );
        store.set_status_many(&[a, b], BookStatus::Paused).unwrap();
        assert_eq!(store.status(a).unwrap(), BookStatus::Paused);
        assert_eq!(store.status(b).unwrap(), BookStatus::Paused);
        assert!(
            store
                .set_status_many(&[a, 999], BookStatus::Reading)
                .is_err()
        );
        assert_eq!(
            store.status(a).unwrap(),
            BookStatus::Paused,
            "failed bulk updates roll back"
        );
        assert!(store.set_status(a, BookStatus::ToRead).is_ok());
        assert_eq!(
            store.book(a).unwrap().location.as_deref(),
            Some("spine:0.8")
        );
    }

    #[test]
    fn collections_support_manual_order_bulk_membership_and_non_destructive_delete() {
        let (_dir, store) = store();
        store
            .save_scan(
                &["books"],
                &[
                    found("books", "a.epub", "A"),
                    found("books", "b.epub", "B"),
                    found("books", "c.epub", "C"),
                ],
            )
            .unwrap();
        let books = store.books_sorted(None, false, BookSort::Title).unwrap();
        let ids = books.iter().map(|book| book.id).collect::<Vec<_>>();
        let list_id = store.create_collection("Reading now").unwrap();
        store.create_collection("Favorites").unwrap();
        store.add_to_collection("Reading now", ids[0]).unwrap();
        store
            .add_many_to_collection("Reading now", &[ids[1], ids[2], ids[1]])
            .unwrap();
        store.add_to_collection("Favorites", ids[0]).unwrap();
        assert_eq!(
            store
                .collection("Reading now")
                .unwrap()
                .iter()
                .map(|b| b.id)
                .collect::<Vec<_>>(),
            ids
        );
        store.reorder_collection("Reading now", ids[2], 0).unwrap();
        assert_eq!(
            store
                .collection("Reading now")
                .unwrap()
                .iter()
                .map(|b| b.id)
                .collect::<Vec<_>>(),
            [ids[2], ids[0], ids[1]]
        );
        assert_eq!(
            store
                .collection_sorted("Reading now", CollectionSort::Title)
                .unwrap()
                .iter()
                .map(|b| b.id)
                .collect::<Vec<_>>(),
            ids
        );
        assert_eq!(store.collection_id("Reading now").unwrap(), list_id);
        store.rename_collection("Reading now", "Current").unwrap();
        store
            .remove_many_from_collection("Current", &[ids[0], ids[1]])
            .unwrap();
        assert_eq!(
            store
                .collection("Current")
                .unwrap()
                .iter()
                .map(|b| b.id)
                .collect::<Vec<_>>(),
            [ids[2]]
        );
        store.delete_collection("Current").unwrap();
        assert!(store.collection("Current").unwrap().is_empty());
        assert_eq!(
            store.books(None, false).unwrap().len(),
            3,
            "deleting a list never deletes books"
        );
        assert_eq!(store.collections().unwrap(), [("Favorites".to_owned(), 1)]);
    }

    #[cfg(unix)]
    #[test]
    fn database_storage_is_private_repairs_modes_and_rejects_symlinks() {
        use std::{
            fs,
            os::unix::fs::{PermissionsExt, symlink},
        };

        fn mode(path: &Path) -> u32 {
            fs::metadata(path).unwrap().permissions().mode() & 0o777
        }

        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("new/bookr.sqlite");
        let store = Store::open(&path).unwrap();
        assert_eq!(mode(path.parent().unwrap()), 0o700);
        assert_eq!(mode(&path), 0o600);

        let connection = store.conn().unwrap();
        connection
            .execute_batch("CREATE TABLE f03_probe (value INTEGER)")
            .unwrap();
        for suffix in ["-wal", "-shm"] {
            let mut sidecar = path.clone().into_os_string();
            sidecar.push(suffix);
            let sidecar = PathBuf::from(sidecar);
            assert!(sidecar.is_file(), "SQLite creates {suffix}");
            assert_eq!(mode(&sidecar), 0o600, "{suffix} is owner-only");
        }

        let repaired_directory = root.path().join("repaired");
        fs::create_dir(&repaired_directory).unwrap();
        fs::set_permissions(&repaired_directory, fs::Permissions::from_mode(0o755)).unwrap();
        let repaired_path = repaired_directory.join("bookr.sqlite");
        fs::File::create(&repaired_path).unwrap();
        fs::set_permissions(&repaired_path, fs::Permissions::from_mode(0o644)).unwrap();
        Store::open(&repaired_path).unwrap();
        assert_eq!(mode(&repaired_directory), 0o700);
        assert_eq!(mode(&repaired_path), 0o600);

        let target = root.path().join("target.sqlite");
        let link = root.path().join("link.sqlite");
        symlink(&target, &link).unwrap();
        assert!(Store::open(&link).is_err());
        assert!(
            !target.exists(),
            "SQLite never follows the protected database leaf"
        );
    }
}
