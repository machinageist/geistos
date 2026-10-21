// Author: Jeff
// Date: 2026-09-19
// Description: Paint the books TUI — tabs, the tab's body, one line of keys or news at the bottom
// Notes: Named ANSI colours only, so the terminal theme decides the shades

use crate::terminal_text::sanitize_terminal_text;
use ratatui::Frame;
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Color, Modifier, Style, Stylize};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Gauge, List, ListItem, ListState, Paragraph, Tabs};

use super::state::{KIND_FILTERS, State, TABS, Tab};
use crate::store::{Book, BookRecord, CollectionSummary};

const ACCENT: Color = Color::Magenta;
const DIM: Color = Color::DarkGray;

// 3725 s → "1:02:05"
pub fn clock(seconds: f64) -> String {
    let s = seconds.max(0.0) as u64;
    format!("{}:{:02}:{:02}", s / 3600, s % 3600 / 60, s % 60)
}

pub fn draw(frame: &mut Frame, state: &State, now_ms: i64) {
    let [top, body, bottom] = Layout::vertical([
        Constraint::Length(1),
        Constraint::Min(3),
        Constraint::Length(1),
    ])
    .areas(frame.area());
    let titles = TABS
        .iter()
        .enumerate()
        .map(|(i, t)| format!("{} {}", i + 1, t.title()));
    let selected = TABS.iter().position(|t| *t == state.tab).unwrap_or(0);
    frame.render_widget(
        Tabs::new(titles)
            .select(selected)
            .highlight_style(Style::new().fg(ACCENT).bold())
            .divider("\u{2502}"),
        top,
    );
    match state.tab {
        Tab::Continue => draw_list(
            frame,
            body,
            " reading and listening ",
            state.continuing.iter().map(book_line).collect(),
            state.cursor(),
        ),
        Tab::Library => {
            let kind = KIND_FILTERS[state.kind];
            let mut title = format!(" library · {}", state.sort.label());
            if !kind.is_empty() {
                title.push_str(&format!(" · {kind}"));
            }
            if !state.query.is_empty() {
                title.push_str(" · /");
                title.push_str(&state.query);
            }
            title.push(' ');
            let rows = state.shown().into_iter().map(book_line).collect();
            draw_list(frame, body, &title, rows, state.cursor())
        }
        Tab::Listening => draw_listening(frame, body, state, now_ms),
        Tab::Lists => match &state.list {
            Some(name) => draw_list(
                frame,
                body,
                &format!(" list · {name} "),
                state
                    .list_books
                    .iter()
                    .enumerate()
                    .map(|(at, record)| list_book_line(at + 1, record))
                    .collect(),
                state.cursor(),
            ),
            None if state.lists.is_empty() => frame.render_widget(
                Paragraph::new(
                    "no reading lists yet \u{b7} mg-bookr collection import <folder> makes one",
                )
                .fg(DIM),
                body,
            ),
            None => {
                let width = state
                    .lists
                    .iter()
                    .map(|list| sanitize_terminal_text(&list.name).chars().count())
                    .max()
                    .unwrap_or(0);
                let rows = state
                    .lists
                    .iter()
                    .map(|list| summary_line(list, width))
                    .collect();
                draw_list(frame, body, " reading lists ", rows, state.cursor())
            }
        },
    }
    let keys = match state.tab {
        _ if state.message.is_some() => state.message.clone().unwrap_or_default(),
        Tab::Library if state.searching => {
            "type to filter · enter done · backspace edit · esc clear · Ctrl-C quits".into()
        }
        Tab::Listening => "space play/pause · ←/→ 15s · n/p chapter · [/] speed · z sleep · x stop · q quit".into(),
        Tab::Library => "enter play/read · f kind · o order · / search · s rescan · space play/pause · z sleep · q quit".into(),
        Tab::Continue => "enter play/read · space play/pause · z sleep · tab/1-4 · q quit".into(),
        Tab::Lists if state.list.is_some() => {
            "enter play/read · esc back to lists · space play/pause · z sleep · q quit".into()
        }
        Tab::Lists => "enter open list · s rescan · tab/1-4 · q quit".into(),
    };
    frame.render_widget(
        Paragraph::new(sanitize_terminal_text(&keys)).fg(DIM),
        bottom,
    );
}

// "Title — Author   62%" with the kind ahead of it
fn book_line(book: &Book) -> Line<'static> {
    let kind = match book.kind.as_str() {
        "audio" | "audio-folder" => "audio",
        other => other,
    };
    let percent = match (book.percent, book.finished) {
        (_, true) => "  finished".to_string(),
        (Some(p), _) if p > 0.0 => format!("  {p:.0}%"),
        _ => String::new(),
    };
    let mut spans = vec![
        Span::styled(format!("{kind:<6}"), Style::new().fg(DIM)),
        Span::raw(sanitize_terminal_text(&book.title)),
    ];
    if let Some(author) = &book.author {
        spans.push(Span::styled(
            format!(" — {}", sanitize_terminal_text(author)),
            Style::new().fg(ACCENT),
        ));
    }
    if let Some(series) = &book.series {
        spans.push(Span::styled(
            format!(" · {}", sanitize_terminal_text(series)),
            Style::new().fg(DIM),
        ));
    }
    spans.push(Span::styled(percent, Style::new().fg(DIM)));
    Line::from(spans)
}

// "ccna-weekly   6 books · 1 reading · 0 finished"
fn summary_line(list: &CollectionSummary, width: usize) -> Line<'static> {
    Line::from(vec![
        Span::raw(format!("{:<width$}", sanitize_terminal_text(&list.name))),
        Span::styled(
            format!(
                "  {} books \u{b7} {} reading \u{b7} {} finished",
                list.books, list.reading, list.finished
            ),
            Style::new().fg(DIM),
        ),
    ])
}

// "  3  reading   epub  Title — Author  12%": the book's place in the list and its status first
fn list_book_line(place: usize, record: &BookRecord) -> Line<'static> {
    let mut line = book_line(&record.book);
    line.spans.insert(
        0,
        Span::styled(
            format!("{place:>3}  {:<9}", record.status.as_str()),
            Style::new().fg(DIM),
        ),
    );
    if record.book.missing {
        line.spans
            .push(Span::styled("  missing", Style::new().fg(Color::Red)));
    }
    line
}

fn draw_list(frame: &mut Frame, area: Rect, title: &str, rows: Vec<Line<'static>>, cursor: usize) {
    let empty = rows.is_empty();
    let list = List::new(rows.into_iter().map(ListItem::new))
        .block(
            Block::new()
                .borders(Borders::TOP)
                .title(sanitize_terminal_text(title))
                .border_style(Style::new().fg(DIM)),
        )
        .highlight_style(Style::new().add_modifier(Modifier::REVERSED));
    let mut list_state = ListState::default().with_selected((!empty).then_some(cursor));
    frame.render_stateful_widget(list, area, &mut list_state);
}

fn draw_listening(frame: &mut Frame, area: Rect, state: &State, now_ms: i64) {
    let Some(now) = &state.now else {
        frame.render_widget(
            Paragraph::new("nothing is playing \u{b7} enter on an audiobook starts one").fg(DIM),
            area,
        );
        return;
    };
    let [title, author, gauge, info] = Layout::vertical([
        Constraint::Length(2),
        Constraint::Length(2),
        Constraint::Length(1),
        Constraint::Min(1),
    ])
    .areas(area);
    frame.render_widget(
        Paragraph::new(sanitize_terminal_text(&now.book.title)).bold(),
        title,
    );
    let by = [
        now.book.author.as_deref().map(sanitize_terminal_text),
        now.chapter.as_deref().map(sanitize_terminal_text),
        (now.tracks > 1).then(|| format!("track {} of {}", now.track + 1, now.tracks)),
    ]
    .into_iter()
    .flatten()
    .collect::<Vec<_>>()
    .join(" \u{b7} ");
    frame.render_widget(Paragraph::new(by).fg(ACCENT), author);
    let position = state.position(now_ms);
    let ratio = if now.duration > 0.0 {
        (position / now.duration).clamp(0.0, 1.0)
    } else {
        0.0
    };
    frame.render_widget(
        Gauge::default()
            .ratio(ratio)
            .label(format!("{} / {}", clock(position), clock(now.duration)))
            .gauge_style(Style::new().fg(ACCENT)),
        gauge,
    );
    let sleep = match (now.sleep_left, now.sleep_chapter) {
        (Some(left), _) => format!(" \u{b7} sleep in {} min", (left / 60.0).ceil()),
        (_, true) => " \u{b7} sleep at chapter end".to_string(),
        _ => String::new(),
    };
    frame.render_widget(
        Paragraph::new(format!(
            "{} \u{b7} {}\u{d7} \u{b7} {:.0}% of the book{sleep}",
            if now.paused { "paused" } else { "playing" },
            now.speed,
            now.percent
        ))
        .fg(DIM),
        info,
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tui::state::tests::{book, now, record, summary};

    fn screen(state: &State, w: u16, h: u16) -> String {
        let mut t = ratatui::Terminal::new(ratatui::backend::TestBackend::new(w, h)).unwrap();
        t.draw(|f| draw(f, state, 5_000)).unwrap();
        t.backend()
            .buffer()
            .content()
            .iter()
            .map(|c| c.symbol())
            .collect()
    }

    #[test]
    fn every_tab_draws_and_the_listening_clock_advances() {
        let mut listening = now(false, 2.0, Some(15.0 * 60.0), false);
        listening.book.author = Some("Ursula K. Le Guin".into());
        let mut s = State {
            continuing: vec![book(1, "epub")],
            library: vec![book(1, "epub"), book(2, "audio")],
            now: Some(listening),
            now_at: 1_000,
            ..Default::default()
        };
        assert!(screen(&s, 100, 12).contains("Book 1"));
        s.tab = Tab::Listening;
        let text = screen(&s, 100, 12);
        assert!(text.contains("Book 7") && text.contains("Ursula K. Le Guin"));
        assert!(text.contains("0:00:18 / 0:01:40"), "4 s at 2x from 10 s");
        assert!(text.contains("sleep in 15 min") && text.contains("2\u{d7}"));
        for tab in TABS {
            s.tab = tab;
            screen(&s, 100, 12);
            // cramped must not panic
            screen(&s, 12, 3);
        }
        s.message = Some("scanning…".into());
        assert!(screen(&s, 100, 12).contains("scanning"));
    }

    #[test]
    fn the_lists_tab_shows_lists_then_a_lists_books_in_order() {
        let mut empty = State {
            tab: Tab::Lists,
            ..Default::default()
        };
        assert!(screen(&empty, 100, 8).contains("no reading lists yet"));

        let mut ccna = summary("ccna-weekly", 6);
        ccna.reading = 1;
        empty.lists = vec![summary("ai-tools", 5), ccna];
        let lists = screen(&empty, 100, 8);
        assert!(lists.contains("4 Lists") && lists.contains("reading lists"));
        assert!(lists.contains("ccna-weekly  6 books · 1 reading · 0 finished"));
        assert!(lists.contains("ai-tools     5 books"), "names line up");
        assert!(lists.contains("enter open list"));

        let mut reading = record(2, "pdf");
        reading.status = crate::store::BookStatus::Reading;
        let mut gone = record(3, "epub");
        gone.book.missing = true;
        empty.list = Some("ccna-weekly".into());
        empty.list_books = vec![record(1, "epub"), reading, gone];
        let books = screen(&empty, 100, 8);
        assert!(books.contains("list · ccna-weekly"));
        assert!(books.contains("  1  to-read  epub  Book 1"));
        assert!(books.contains("  2  reading  pdf   Book 2"));
        assert!(books.contains("Book 3  missing"));
        assert!(books.contains("esc back to lists"));
        screen(&empty, 12, 3);
    }

    fn terminal_active_control(c: char) -> bool {
        matches!(c, '\u{0000}'..='\u{001f}' | '\u{007f}'..='\u{009f}')
    }

    fn hostile_terminal_text() -> String {
        let esc = char::from_u32(27).expect("ESC");
        let bel = char::from_u32(7).expect("BEL");
        format!("unsafe{esc}]8;;https://evil.test{bel}{esc}[2J")
    }

    #[test]
    fn library_view_shows_sort_search_and_input_state() {
        let mut first = book(1, "epub");
        first.series = Some("Earthsea".into());
        let state = State {
            tab: Tab::Library,
            library: vec![first, book(2, "pdf")],
            query: "Book 1".into(),
            searching: true,
            sort: crate::store::BookSort::Author,
            ..Default::default()
        };
        let text = screen(&state, 80, 12);
        assert!(text.contains("library"));
        assert!(text.contains("author"));
        assert!(text.contains("/Book 1"));
        assert!(text.contains("type to filter"));
        assert!(text.contains("Ctrl-C quits") && !text.contains("q quit"));
        assert!(text.contains("Book 1") && !text.contains("Book 2"));
        assert!(text.contains("Earthsea"));
        screen(&state, 12, 3);
    }

    #[test]
    fn book_metadata_chapters_and_status_never_reach_the_backend_as_controls() {
        let hostile = hostile_terminal_text();
        let mut book = book(1, "epub");
        book.title = hostile.clone();
        book.author = Some(hostile.clone());
        let mut listening = now(false, 1.0, None, false);
        listening.book = book.clone();
        listening.chapter = Some(hostile.clone());
        let mut state = State {
            continuing: vec![book.clone()],
            library: vec![book],
            now: Some(listening),
            now_at: 1_000,
            message: Some(hostile),
            ..Default::default()
        };
        state.lists = vec![summary(&hostile_terminal_text(), 1)];
        let mut rendered = String::new();
        for tab in TABS {
            state.tab = tab;
            rendered.push_str(&screen(&state, 180, 12));
        }
        let mut listed = record(1, "epub");
        listed.book.title = hostile_terminal_text();
        state.list = Some(hostile_terminal_text());
        state.list_books = vec![listed];
        rendered.push_str(&screen(&state, 180, 12));
        assert!(
            !rendered.chars().any(terminal_active_control),
            "TestBackend must not receive ESC, BEL, or another C0/C1 control"
        );
        assert!(rendered.contains("]8;;https://evil.test") && rendered.contains("[2J"));
    }
}
