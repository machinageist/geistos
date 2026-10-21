// Author: Jeff
// Date: 2026-10-21
// Description: Turn a folder of books into a reading list, filing new books into the library
// Notes: The list is named after the folder. Each entry (a file, or a symlink to one) is a book
//        already under the books root, a copy of one (same size and SHA-256 — never a guess from
//        the title), or new. A new book is filed at texts/<Subject>/<author>-<year>-<title>.<ext>,
//        the way the library is kept, and the entry becomes a symlink to it: a real file is
//        moved, a linked one outside the folder is copied and left alone. Library files are
//        placed with a hard link, so an existing name is never overwritten, and an entry is
//        swapped for its link with one rename, so a failure leaves the old entry or the new link.
//        A dry run plans the same and touches nothing

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use serde::Serialize;
use sha2::{Digest, Sha256};

use crate::meta::{self, Meta};
use crate::scan::{self, Roots};
use crate::store::Store;

// where the library keeps books by subject: <books>/texts/<Subject>/
pub const SHELF: &str = "texts";
// a file name stem stops here; the library's longest is 144
const MAX_STEM_CHARS: usize = 180;
// words that belong to the surname after them: "Le Guin", "van Rossum"
const SURNAME_PARTICLES: [&str; 10] = [
    "da", "de", "del", "der", "di", "du", "la", "le", "van", "von",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum Action {
    // already under the books root
    Shelved,
    // the same bytes as a library file; the entry now links to it
    Duplicate,
    // new: filed into the library and linked back
    Imported,
}

#[derive(Debug, Serialize)]
pub struct Member {
    // the entry's name in the folder
    pub source: String,
    pub action: Action,
    // where the book is inside the books root
    pub path: String,
    // the book's id once it is recorded (never on a dry run)
    pub id: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct Skipped {
    pub source: String,
    pub reason: String,
}

#[derive(Debug, Serialize)]
pub struct Report {
    pub list: String,
    pub dry_run: bool,
    // where new books were filed, when there were any
    pub subject: Option<String>,
    pub books: Vec<Member>,
    pub skipped: Vec<Skipped>,
    // books that joined the list (an existing list keeps its members)
    pub added: usize,
    pub scan: Option<scan::Report>,
}

// One folder entry, before anything changes
struct Entry {
    source: String,
    // the entry, and the file it is (itself, or a link's target)
    link: PathBuf,
    file: PathBuf,
    // a real file in the folder, so ours to move
    owned: bool,
    extension: String,
    // what it is and its place in the books root; None while it is new and unnamed
    found: Option<(Action, String)>,
}

// Import `dir` as the reading list named after it
pub fn import(
    store: &Store,
    roots: &Roots,
    cover_dir: &Path,
    dir: &Path,
    subject: Option<&str>,
    dry_run: bool,
) -> Result<Report> {
    let folder = dir
        .canonicalize()
        .with_context(|| format!("cannot open {}", dir.display()))?;
    let list = dir
        .file_name()
        .or(folder.file_name())
        .and_then(|name| name.to_str())
        .context("the folder's name is not text")?;
    let list = Store::checked_collection_name(list)?.to_string();
    let books_root = roots
        .books
        .canonicalize()
        .with_context(|| format!("cannot open the books folder {}", roots.books.display()))?;

    // What each entry is
    let mut skipped = Vec::new();
    let mut entries = Vec::new();
    let mut library = None;
    for source in entry_names(&folder, &mut skipped)? {
        let link = folder.join(&source);
        let Ok(file) = link.canonicalize() else {
            skipped.push(skip(&source, "a broken link"));
            continue;
        };
        if !file.is_file() {
            skipped.push(skip(&source, "not a file"));
            continue;
        }
        let extension = meta::extension(&file.to_string_lossy());
        if !scan::EBOOK_EXTENSIONS.contains(&extension.as_str()) {
            skipped.push(skip(&source, "not an ebook (epub, pdf, cbz or cbr)"));
            continue;
        }
        let owned = !link.symlink_metadata()?.file_type().is_symlink();
        let found = if file.starts_with(&books_root) {
            Some((Action::Shelved, file.clone()))
        } else {
            let sizes = library.get_or_insert_with(|| library_sizes(&books_root));
            copy_of(&file, sizes)?.map(|copy| (Action::Duplicate, copy))
        };
        let found = match found {
            None => None,
            Some((action, path)) => match inside(&books_root, &path) {
                Some(path) => Some((action, path)),
                None => {
                    skipped.push(skip(&source, "its library path is not text"));
                    continue;
                }
            },
        };
        entries.push(Entry {
            source,
            link,
            file,
            owned,
            extension,
            found,
        });
    }
    if entries.is_empty() {
        bail!("{} holds no ebooks (epub, pdf, cbz or cbr)", dir.display())
    }

    // Where new books go, and under what names
    let subject = if entries.iter().any(|entry| entry.found.is_none()) {
        let listed = entries
            .iter()
            .filter_map(|entry| entry.found.as_ref().map(|(_, path)| path.as_str()));
        Some(choose_subject(&books_root, subject, listed)?)
    } else {
        None
    };
    let mut taken = HashSet::new();
    entries.retain_mut(|entry| {
        let Some(subject) = &subject else {
            return true;
        };
        if entry.found.is_some() {
            return true;
        }
        let kind = match entry.extension.as_str() {
            "cbz" | "cbr" => "comic",
            other => other,
        };
        let meta = scan::read(kind, &entry.file).unwrap_or_default();
        // a link's target keeps the name it came with, which usually says more
        let file_name = entry
            .file
            .file_name()
            .map_or(String::new(), |name| name.to_string_lossy().into_owned());
        let path = format!(
            "{SHELF}/{subject}/{}",
            library_name(&meta, &file_name, &entry.extension)
        );
        if books_root.join(&path).symlink_metadata().is_ok() || !taken.insert(path.clone()) {
            skipped.push(skip(&entry.source, &format!("{path} is already taken")));
            return false;
        }
        entry.found = Some((Action::Imported, path));
        true
    });
    if entries.is_empty() && !dry_run {
        let reasons = skipped
            .iter()
            .map(|skipped| format!("{}: {}", skipped.source, skipped.reason))
            .collect::<Vec<_>>();
        bail!(
            "nothing in {} can be listed ({})",
            dir.display(),
            reasons.join("; ")
        )
    }

    let mut report = Report {
        list,
        dry_run,
        subject,
        books: Vec::new(),
        skipped,
        added: 0,
        scan: None,
    };
    let planned = entries.into_iter().filter_map(|entry| {
        entry
            .found
            .clone()
            .map(|(action, path)| (entry, action, path))
    });
    if dry_run {
        report.books = planned
            .map(|(entry, action, path)| Member {
                source: entry.source,
                action,
                path,
                id: None,
            })
            .collect();
        return Ok(report);
    }

    // File and link, then record and list
    let mut members = Vec::new();
    for (entry, action, path) in planned {
        let target = books_root.join(&path);
        match action {
            Action::Shelved => {}
            Action::Duplicate => link_back(&entry.link, &target)?,
            Action::Imported => {
                place(&entry.file, &target, entry.owned)?;
                link_back(&entry.link, &target)?;
            }
        }
        members.push((entry.source, action, path));
    }
    report.scan = Some(scan::scan(store, roots, cover_dir)?);
    let mut ids = Vec::new();
    for (source, action, path) in members {
        match store.book_at(scan::BOOKS, &path)? {
            Some(id) => {
                ids.push(id);
                report.books.push(Member {
                    source,
                    action,
                    path,
                    id: Some(id),
                });
            }
            None => report.skipped.push(skip(
                &source,
                &format!("the scan did not record {path} (a hidden or too-deep folder?)"),
            )),
        }
    }
    if ids.is_empty() {
        bail!("none of the books in {} could be recorded", dir.display())
    }
    if store.collection_id(&report.list).is_err() {
        store.create_collection(&report.list)?;
    }
    report.added = store.add_many_to_collection(&report.list, &ids)?;
    Ok(report)
}

fn skip(source: &str, reason: &str) -> Skipped {
    Skipped {
        source: source.to_string(),
        reason: reason.to_string(),
    }
}

// A path inside the books root as the library records it: "texts/Subject/book.epub"
fn inside(books_root: &Path, path: &Path) -> Option<String> {
    path.strip_prefix(books_root)
        .ok()
        .and_then(Path::to_str)
        .map(str::to_string)
}

// The folder's entry names in natural order; hidden ones are left out
fn entry_names(folder: &Path, skipped: &mut Vec<Skipped>) -> Result<Vec<String>> {
    let mut names = Vec::new();
    for entry in
        std::fs::read_dir(folder).with_context(|| format!("cannot read {}", folder.display()))?
    {
        let name = entry?.file_name();
        match name.to_str() {
            Some(name) if name.starts_with('.') => {}
            Some(name) => names.push(name.to_string()),
            None => skipped.push(skip(&name.to_string_lossy(), "its name is not text")),
        }
    }
    names.sort_by(|a, b| meta::natural_cmp(a, b));
    Ok(names)
}

// Every ebook under the books root by size, so a copy is found without hashing the lot.
// Best effort: an unreadable folder is passed over, and a copy missed there is caught later
// by its conventional name being taken
fn library_sizes(books_root: &Path) -> HashMap<u64, Vec<PathBuf>> {
    let mut sizes: HashMap<u64, Vec<PathBuf>> = HashMap::new();
    let mut stack = vec![(books_root.to_path_buf(), 0)];
    while let Some((dir, depth)) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().into_owned();
            let Ok(kind) = entry.file_type() else {
                continue;
            };
            if name.starts_with('.') {
                continue;
            }
            if kind.is_dir() && depth < scan::MAX_DEPTH {
                stack.push((entry.path(), depth + 1));
            } else if kind.is_file()
                && scan::EBOOK_EXTENSIONS.contains(&meta::extension(&name).as_str())
                && let Ok(metadata) = entry.metadata()
            {
                sizes.entry(metadata.len()).or_default().push(entry.path());
            }
        }
    }
    sizes
}

// The library file holding the same bytes as `file`, if there is one
fn copy_of(file: &Path, sizes: &HashMap<u64, Vec<PathBuf>>) -> Result<Option<PathBuf>> {
    let Some(same_size) = sizes.get(&std::fs::metadata(file)?.len()) else {
        return Ok(None);
    };
    let digest = sha256(file)?;
    Ok(same_size
        .iter()
        .find(|candidate| sha256(candidate).is_ok_and(|other| other == digest))
        .cloned())
}

fn sha256(path: &Path) -> Result<Vec<u8>> {
    let mut file =
        std::fs::File::open(path).with_context(|| format!("cannot read {}", path.display()))?;
    let mut digest = Sha256::new();
    std::io::copy(&mut file, &mut digest)?;
    Ok(digest.finalize().to_vec())
}

// The subject new books are filed under: the one asked for, else the one most of the list is in
fn choose_subject<'a>(
    books_root: &Path,
    asked: Option<&str>,
    listed: impl Iterator<Item = &'a str>,
) -> Result<String> {
    let shelf = books_root.join(SHELF);
    let mut subjects = std::fs::read_dir(&shelf)
        .with_context(|| format!("cannot read {}", shelf.display()))?
        .flatten()
        .filter(|entry| entry.file_type().is_ok_and(|kind| kind.is_dir()))
        .filter_map(|entry| entry.file_name().to_str().map(str::to_string))
        .filter(|name| !name.starts_with('.'))
        .collect::<Vec<_>>();
    subjects.sort();
    if let Some(asked) = asked {
        if subjects.iter().any(|subject| subject == asked) {
            return Ok(asked.to_string());
        }
        bail!(
            "there is no subject {asked} in {}; the subjects are: {}",
            shelf.display(),
            subjects.join(", ")
        )
    }
    let mut counts: HashMap<&str, usize> = HashMap::new();
    for path in listed {
        let mut parts = path.split('/');
        if let (Some(SHELF), Some(subject), Some(_)) = (parts.next(), parts.next(), parts.next()) {
            *counts.entry(subject).or_default() += 1;
        }
    }
    let most = counts.values().copied().max().unwrap_or(0);
    let mut top = counts
        .into_iter()
        .filter(|(_, count)| *count == most)
        .map(|(subject, _)| subject)
        .collect::<Vec<_>>();
    top.sort();
    match top.as_slice() {
        [one] => Ok(one.to_string()),
        [] => bail!(
            "none of this list's books are in {SHELF}/ yet, so pass --subject (one of: {})",
            subjects.join(", ")
        ),
        tied => bail!(
            "this list's books are split evenly between {}, so pass --subject",
            tied.join(" and ")
        ),
    }
}

// Put `file` at `target` without overwriting anything: a hard link when it is ours to move
// (the entry's rename to a symlink then lets go of the old name), else a copy
fn place(file: &Path, target: &Path, owned: bool) -> Result<()> {
    let placed = || format!("cannot file {} as {}", file.display(), target.display());
    if owned {
        match std::fs::hard_link(file, target) {
            Ok(()) => return Ok(()),
            Err(error) if error.kind() == std::io::ErrorKind::CrossesDevices => {}
            Err(error) => return Err(error).with_context(placed),
        }
    }
    let name = target
        .file_name()
        .context("a library path has a file name")?;
    let part = target.with_file_name(format!(".{}.part", name.to_string_lossy()));
    std::fs::copy(file, &part).with_context(placed)?;
    let linked = std::fs::hard_link(&part, target).with_context(placed);
    std::fs::remove_file(&part).ok();
    linked
}

// Swap the folder's entry for a symlink to `target`, in one rename
fn link_back(link: &Path, target: &Path) -> Result<()> {
    let name = link.file_name().context("an entry has a file name")?;
    let fresh = link.with_file_name(format!(".{}.link", name.to_string_lossy()));
    std::os::unix::fs::symlink(target, &fresh)
        .with_context(|| format!("cannot make a link at {}", fresh.display()))?;
    std::fs::rename(&fresh, link)
        .with_context(|| format!("cannot replace {} with a link", link.display()))
}

// ── Names ──

// The library's file name for a book: "donahue-gary-a-2011-network-warrior-2nd-edition.epub"
pub fn library_name(meta: &Meta, source: &str, extension: &str) -> String {
    let authors = if meta.authors.is_empty() {
        split_authors(meta.author.as_deref().unwrap_or_default())
    } else {
        meta.authors.clone()
    };
    let mut author = authors
        .first()
        .map(|first| person(first))
        .filter(|first| !first.is_empty())
        .unwrap_or_else(|| "unknown".into());
    if authors.len() > 1 {
        author.push_str("-et-al");
    }
    let year = meta.year.or_else(|| year_in(source));
    let year_word = year.map_or("undated".into(), |year| year.to_string());
    // a title from the file name loses the year it gave
    let title = meta
        .title
        .as_deref()
        .map(slug)
        .filter(|title| !title.is_empty())
        .or_else(|| {
            let words = slug(&meta::title_from_name(source));
            let words = words
                .split('-')
                .filter(|word| *word != year_word)
                .collect::<Vec<_>>()
                .join("-");
            Some(words).filter(|title| !title.is_empty())
        })
        .unwrap_or_else(|| "untitled".into());
    let stem = format!("{author}-{year_word}-{}", edition_last(&title));
    format!("{}.{extension}", shorten(&stem))
}

// One author string into people: "A. Writer; B. Writer", "A & B", "A and B"
fn split_authors(text: &str) -> Vec<String> {
    text.split([';', '&'])
        .flat_map(|part| part.split(" and "))
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .map(str::to_string)
        .collect()
}

// Surname first: "Gary A. Donahue" → "donahue-gary-a"; "Odom, Wendell" → "odom-wendell"
fn person(name: &str) -> String {
    if let Some((surname, given)) = name.split_once(',') {
        return slug(&format!("{surname} {given}"));
    }
    let words = name.split_whitespace().collect::<Vec<_>>();
    let mut start = words.len().saturating_sub(1);
    while start > 1 && SURNAME_PARTICLES.contains(&words[start - 1].to_lowercase().as_str()) {
        start -= 1;
    }
    slug(&format!(
        "{} {}",
        words[start..].join(" "),
        words[..start].join(" ")
    ))
}

// Lower-case ASCII words joined by hyphens: "Effective Modern C++" → "effective-modern-cplusplus"
fn slug(text: &str) -> String {
    let mut words = String::new();
    for c in text.chars().flat_map(char::to_lowercase) {
        match c {
            'a'..='z' | '0'..='9' => words.push(c),
            '+' => words.push_str("plus"),
            '&' => words.push_str(" and "),
            '\'' | '\u{2018}' | '\u{2019}' => {}
            other => words.push_str(fold(other).unwrap_or(" ")),
        }
    }
    words.split_whitespace().collect::<Vec<_>>().join("-")
}

// A Latin letter without its accent: "é" → "e"
fn fold(c: char) -> Option<&'static str> {
    Some(match c {
        'à' | 'á' | 'â' | 'ã' | 'ä' | 'å' | 'ā' | 'ą' => "a",
        'æ' => "ae",
        'ç' | 'ć' | 'č' => "c",
        'è' | 'é' | 'ê' | 'ë' | 'ē' | 'ę' | 'ě' => "e",
        'ì' | 'í' | 'î' | 'ï' | 'ī' => "i",
        'ł' => "l",
        'ñ' | 'ń' | 'ň' => "n",
        'ò' | 'ó' | 'ô' | 'õ' | 'ö' | 'ø' | 'ő' => "o",
        'œ' => "oe",
        'ř' => "r",
        'ß' => "ss",
        'ś' | 'š' => "s",
        'ù' | 'ú' | 'û' | 'ü' | 'ū' | 'ů' | 'ű' => "u",
        'ý' | 'ÿ' => "y",
        'ź' | 'ż' | 'ž' => "z",
        _ => return None,
    })
}

// A year standing alone in a file name: "Network Warrior (2011).pdf" → 2011; ISBNs do not count
fn year_in(name: &str) -> Option<i32> {
    name.split(|c: char| !c.is_ascii_digit())
        .find(|run| run.len() == 4 && (run.starts_with("19") || run.starts_with("20")))
        .and_then(|run| run.parse().ok())
}

// The edition goes last: "linux-2nd-edition-talking-directly" → "linux-talking-directly-2nd-edition"
fn edition_last(title: &str) -> String {
    let mut words = title.split('-').collect::<Vec<_>>();
    if let Some(at) = words
        .windows(2)
        .position(|pair| is_ordinal(pair[0]) && pair[1] == "edition")
    {
        let edition = words.drain(at..at + 2).collect::<Vec<_>>();
        words.extend(edition);
    }
    words.join("-")
}

// "2nd", "3rd", "11th"
fn is_ordinal(word: &str) -> bool {
    let digits = word.trim_end_matches(|c: char| c.is_ascii_alphabetic());
    !digits.is_empty()
        && digits.bytes().all(|b| b.is_ascii_digit())
        && ["st", "nd", "rd", "th"].contains(&&word[digits.len()..])
}

// Cut a long stem back to a whole word (it is ASCII by now)
fn shorten(stem: &str) -> &str {
    if stem.len() <= MAX_STEM_CHARS {
        return stem;
    }
    let cut = &stem[..MAX_STEM_CHARS];
    cut.rsplit_once('-').map_or(cut, |(head, _)| head)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::meta::tests::{write_cbz, write_epub};

    fn named(title: &str, authors: &[&str], year: Option<i32>) -> Meta {
        Meta {
            title: Some(title.into()),
            authors: authors.iter().map(|a| a.to_string()).collect(),
            year,
            ..Meta::default()
        }
    }

    #[test]
    fn names_follow_the_library_convention() {
        let cases = [
            (
                named(
                    "Network Warrior, 2nd Edition",
                    &["Gary A. Donahue"],
                    Some(2011),
                ),
                "donahue-gary-a-2011-network-warrior-2nd-edition.epub",
            ),
            (
                named(
                    "Linux System Programming, 2nd Edition: Talking Directly to the Kernel and C Library",
                    &["Robert Love"],
                    Some(2013),
                ),
                "love-robert-2013-linux-system-programming-talking-directly-to-the-kernel-and-c-library-2nd-edition.epub",
            ),
            (
                named(
                    "CCNA 200-301 Official Cert Guide Library",
                    &["Odom, Wendell", "Kevin Wallace"],
                    None,
                ),
                "odom-wendell-et-al-undated-ccna-200-301-official-cert-guide-library.epub",
            ),
            (
                named("Effective Modern C++", &["Scott Meyers"], Some(2014)),
                "meyers-scott-2014-effective-modern-cplusplus.epub",
            ),
            (
                named("Hacker\u{2019}s Delight", &["Henry S. Warren"], Some(2013)),
                "warren-henry-s-2013-hackers-delight.epub",
            ),
            (
                named("The Left Hand of Darkness", &["Ursula K. Le Guin"], None),
                "le-guin-ursula-k-undated-the-left-hand-of-darkness.epub",
            ),
        ];
        for (meta, name) in cases {
            assert_eq!(library_name(&meta, "x.epub", "epub"), name);
        }
    }

    #[test]
    fn names_fall_back_to_the_file_and_stay_short() {
        // accents fold, and the year comes from the file name when the book has none
        let geron = named("Hands-On Machine Learning", &["Aurélien Géron"], None);
        assert_eq!(
            library_name(&geron, "Hands-On ML (2019) 9781098125974.epub", "epub"),
            "geron-aurelien-2019-hands-on-machine-learning.epub"
        );
        // a PDF's one author string is split into people
        let pdf = Meta {
            title: Some("Dive Into Systems".into()),
            author: Some("Suzanne J. Matthews & Tia Newhall and Kevin C. Webb".into()),
            ..Meta::default()
        };
        assert_eq!(
            library_name(&pdf, "dis.pdf", "pdf"),
            "matthews-suzanne-j-et-al-undated-dive-into-systems.pdf"
        );
        // nothing known: the file name gives the title, without the year it also gave
        assert_eq!(
            library_name(&Meta::default(), "Network Warrior (2011).pdf", "pdf"),
            "unknown-2011-network-warrior.pdf"
        );
        let long = named(&"word ".repeat(60), &["A. Writer"], Some(2020));
        let name = library_name(&long, "x.epub", "epub");
        assert!(name.len() <= MAX_STEM_CHARS + ".epub".len());
        assert!(name.ends_with("-word.epub"));
    }

    // books/texts/{Fiction,Science}, one EPUB and one comic shelved in Fiction
    fn library(dir: &Path) -> (Roots, PathBuf, PathBuf) {
        let fiction = dir.join("books/texts/Fiction");
        std::fs::create_dir_all(&fiction).unwrap();
        std::fs::create_dir_all(dir.join("books/texts/Science")).unwrap();
        std::fs::create_dir_all(dir.join("audiobooks")).unwrap();
        let shelved = fiction.join("le-guin-ursula-k-undated-the-left-hand-of-darkness.epub");
        write_epub(&shelved, false);
        let comic = fiction.join("saga.cbz");
        write_cbz(&comic);
        let roots = Roots {
            books: dir.join("books"),
            audiobooks: dir.join("audiobooks"),
        };
        (roots, shelved, comic)
    }

    fn is_link(path: &Path) -> bool {
        path.symlink_metadata()
            .is_ok_and(|m| m.file_type().is_symlink())
    }

    #[test]
    fn a_folder_becomes_a_list_with_new_books_filed_and_linked_back() {
        let dir = tempfile::tempdir().unwrap();
        let (roots, shelved, comic) = library(dir.path());
        let covers = dir.path().join("covers");
        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let outside = dir.path().join("downloads/outside (2001).pdf");
        std::fs::create_dir_all(outside.parent().unwrap()).unwrap();
        std::fs::write(&outside, b"%PDF-1.4 not really").unwrap();

        let folder = dir.path().join("lists/hainish");
        std::fs::create_dir_all(folder.join("sub")).unwrap();
        std::os::unix::fs::symlink(&shelved, folder.join("a-shelved.epub")).unwrap();
        std::fs::copy(&comic, folder.join("b-copy.cbz")).unwrap();
        write_epub(&folder.join("c-new.epub"), true);
        std::fs::write(folder.join("d-notes.txt"), b"notes").unwrap();
        std::os::unix::fs::symlink(dir.path().join("gone.epub"), folder.join("e-broken.epub"))
            .unwrap();
        std::os::unix::fs::symlink(&outside, folder.join("f-outside.pdf")).unwrap();
        write_epub(&folder.join(".hidden.epub"), true);
        let new_bytes = std::fs::read(folder.join("c-new.epub")).unwrap();
        let shelved_at = shelved_path();
        let filed = "texts/Fiction/le-guin-ursula-k-1969-the-left-hand-of-darkness.epub";
        let linked = "texts/Fiction/unknown-2001-outside.pdf";

        // A dry run plans everything and changes nothing
        let plan = import(&store, &roots, &covers, &folder, None, true).unwrap();
        let planned = plan
            .books
            .iter()
            .map(|m| (m.source.as_str(), m.action, m.path.as_str()))
            .collect::<Vec<_>>();
        let expected = [
            ("a-shelved.epub", Action::Shelved, shelved_at.as_str()),
            ("b-copy.cbz", Action::Duplicate, "texts/Fiction/saga.cbz"),
            ("c-new.epub", Action::Imported, filed),
            ("f-outside.pdf", Action::Imported, linked),
        ];
        assert_eq!(planned, expected);
        let skipped = plan
            .skipped
            .iter()
            .map(|s| s.source.as_str())
            .collect::<Vec<_>>();
        assert_eq!(skipped, ["d-notes.txt", "e-broken.epub", "sub"]);
        assert_eq!(plan.subject.as_deref(), Some("Fiction"));
        assert!(!is_link(&folder.join("c-new.epub")));
        assert!(!is_link(&folder.join("b-copy.cbz")));
        assert!(!roots.books.join(filed).exists());
        assert!(store.collection_id("hainish").is_err());

        // The real run files, links and lists
        let done = import(&store, &roots, &covers, &folder, None, false).unwrap();
        assert_eq!(done.added, 4);
        assert!(done.books.iter().all(|m| m.id.is_some()));
        assert_eq!(std::fs::read(roots.books.join(filed)).unwrap(), new_bytes);
        for (entry, target) in [
            ("a-shelved.epub", shelved_path()),
            ("b-copy.cbz", "texts/Fiction/saga.cbz".into()),
            ("c-new.epub", filed.into()),
            ("f-outside.pdf", linked.into()),
        ] {
            let entry = folder.join(entry);
            assert!(is_link(&entry));
            assert_eq!(
                entry.canonicalize().unwrap(),
                roots.books.join(target).canonicalize().unwrap()
            );
        }
        assert!(
            outside.exists(),
            "a linked file outside the folder is copied, not moved"
        );
        let listed = store
            .collection("hainish")
            .unwrap()
            .into_iter()
            .map(|book| book.path)
            .collect::<Vec<_>>();
        assert_eq!(
            listed,
            [
                shelved_path(),
                "texts/Fiction/saga.cbz".into(),
                filed.into(),
                linked.into()
            ]
        );

        // Again: everything is shelved now and the list is unchanged
        let again = import(&store, &roots, &covers, &folder, None, false).unwrap();
        assert_eq!(again.added, 0);
        assert!(again.books.iter().all(|m| m.action == Action::Shelved));
        assert_eq!(store.collection("hainish").unwrap().len(), 4);
    }

    fn shelved_path() -> String {
        "texts/Fiction/le-guin-ursula-k-undated-the-left-hand-of-darkness.epub".into()
    }

    #[test]
    fn the_subject_is_asked_for_when_it_cannot_be_inferred() {
        let dir = tempfile::tempdir().unwrap();
        let (roots, shelved, _) = library(dir.path());
        let covers = dir.path().join("covers");
        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let folder = dir.path().join("new-only");
        std::fs::create_dir_all(&folder).unwrap();
        write_epub(&folder.join("new.epub"), true);

        let none = import(&store, &roots, &covers, &folder, None, true).unwrap_err();
        assert!(format!("{none:#}").contains("pass --subject (one of: Fiction, Science)"));
        let unknown = import(&store, &roots, &covers, &folder, Some("Nope"), true).unwrap_err();
        assert!(format!("{unknown:#}").contains("there is no subject Nope"));
        let asked = import(&store, &roots, &covers, &folder, Some("Science"), true).unwrap();
        assert_eq!(
            asked.books[0].path,
            "texts/Science/le-guin-ursula-k-1969-the-left-hand-of-darkness.epub"
        );

        // one shelved book in each subject is a tie
        let science = roots.books.join("texts/Science/paper.cbz");
        std::fs::write(&science, b"different bytes").unwrap();
        std::os::unix::fs::symlink(&shelved, folder.join("a.epub")).unwrap();
        std::os::unix::fs::symlink(&science, folder.join("b.cbz")).unwrap();
        let tied = import(&store, &roots, &covers, &folder, None, true).unwrap_err();
        assert!(format!("{tied:#}").contains("split evenly between Fiction and Science"));
    }

    #[test]
    fn a_taken_name_is_skipped_and_an_empty_folder_is_an_error() {
        let dir = tempfile::tempdir().unwrap();
        let (roots, _, _) = library(dir.path());
        let covers = dir.path().join("covers");
        let store = Store::open(dir.path().join("b.sqlite")).unwrap();
        let folder = dir.path().join("clash");
        std::fs::create_dir_all(&folder).unwrap();
        // a different book already holds the name this one would get
        let holder = "texts/Fiction/le-guin-ursula-k-1969-the-left-hand-of-darkness.epub";
        std::fs::write(roots.books.join(holder), b"someone else").unwrap();
        write_epub(&folder.join("new.epub"), true);
        let report = import(&store, &roots, &covers, &folder, Some("Fiction"), false).unwrap_err();
        assert!(format!("{report:#}").contains("new.epub: texts/Fiction/le-guin"));
        assert!(
            store.books(None, true).unwrap().is_empty(),
            "nothing was scanned"
        );
        assert!(
            !is_link(&folder.join("new.epub")),
            "a skipped book is left alone"
        );
        let plan = import(&store, &roots, &covers, &folder, Some("Fiction"), true).unwrap();
        assert!(plan.books.is_empty());
        assert_eq!(plan.skipped[0].reason, format!("{holder} is already taken"));

        let empty = dir.path().join("empty");
        std::fs::create_dir_all(&empty).unwrap();
        let error = import(&store, &roots, &covers, &empty, None, true).unwrap_err();
        assert!(format!("{error:#}").contains("holds no ebooks"));
    }
}
