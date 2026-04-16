// SPDX-License-Identifier: PMPL-1.0-or-later
//
// UI rendering for the IDApTIK Escape Hatch developer TUI.

use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph, Tabs},
};

use crate::app::{ActiveTab, App};

/// Render the entire UI into the given frame.
pub fn draw(frame: &mut Frame, app: &App) {
    // Split into header, body, footer.
    let outer = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // header
            Constraint::Min(0),   // body
            Constraint::Length(3), // footer
        ])
        .split(frame.area());

    draw_header(frame, outer[0], app);
    draw_body(frame, outer[1], app);
    draw_footer(frame, outer[2], app);
}

/// Header: title and tab bar.
fn draw_header(frame: &mut Frame, area: Rect, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Length(2)])
        .split(area);

    // Title line.
    let title = Paragraph::new(Line::from(vec![
        Span::styled(
            " IDApTIK Escape Hatch v0.1.0 ",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            "  Developer Command Centre",
            Style::default().fg(Color::DarkGray),
        ),
    ]));
    frame.render_widget(title, chunks[0]);

    // Tab bar.
    let tab_titles: Vec<Line> = vec!["Dashboard".into(), "Commands".into()];
    let selected = match app.active_tab {
        ActiveTab::Dashboard => 0,
        ActiveTab::Commands => 1,
    };
    let tabs = Tabs::new(tab_titles)
        .select(selected)
        .style(Style::default().fg(Color::White))
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
        )
        .divider(Span::raw(" | "));
    frame.render_widget(tabs, chunks[1]);
}

/// Body: content for the active tab.
fn draw_body(frame: &mut Frame, area: Rect, app: &App) {
    match app.active_tab {
        ActiveTab::Dashboard => draw_dashboard(frame, area, app),
        ActiveTab::Commands => draw_commands(frame, area, app),
    }
}

/// Dashboard tab: list of components with completion gauges.
fn draw_dashboard(frame: &mut Frame, area: Rect, app: &App) {
    // Split into list on left, detail on right.
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(area);

    // Component list.
    let items: Vec<ListItem> = app
        .dashboard_items
        .iter()
        .enumerate()
        .map(|(i, c)| {
            let style = if i == app.dashboard_selected {
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };
            let bar = progress_bar(c.completion, 20);
            ListItem::new(Line::from(vec![
                Span::styled(format!(" {:<28} ", c.name), style),
                Span::styled(bar, Style::default().fg(completion_colour(c.completion))),
                Span::styled(
                    format!(" {:>3}%", c.completion),
                    Style::default().fg(Color::DarkGray),
                ),
            ]))
        })
        .collect();

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Components "),
    );
    frame.render_widget(list, chunks[0]);

    // Detail panel for the selected component.
    let selected = &app.dashboard_items[app.dashboard_selected];
    let gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(format!(" {} ", selected.name)),
        )
        .gauge_style(
            Style::default()
                .fg(completion_colour(selected.completion))
                .bg(Color::DarkGray),
        )
        .percent(selected.completion as u16)
        .label(format!("{}% - {}", selected.completion, selected.status));
    frame.render_widget(gauge, chunks[1]);
}

/// Commands tab: list of available developer commands.
fn draw_commands(frame: &mut Frame, area: Rect, app: &App) {
    let items: Vec<ListItem> = app
        .commands
        .iter()
        .enumerate()
        .map(|(i, cmd)| {
            let marker = if i == app.command_selected {
                ">"
            } else {
                " "
            };
            let style = if i == app.command_selected {
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };
            ListItem::new(Line::from(vec![
                Span::styled(format!(" {} ", marker), style),
                Span::styled(format!("{:<22}", cmd.label), style),
                Span::styled(
                    cmd.description,
                    Style::default().fg(Color::DarkGray),
                ),
            ]))
        })
        .collect();

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Developer Commands "),
    );
    frame.render_widget(list, area);
}

/// Footer: keybindings and status message.
fn draw_footer(frame: &mut Frame, area: Rect, app: &App) {
    let status = app
        .status_message
        .as_deref()
        .unwrap_or("");

    let footer = Paragraph::new(Line::from(vec![
        Span::styled(
            " Tab",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" Switch tabs  "),
        Span::styled(
            "Up/Down",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" Navigate  "),
        Span::styled(
            "Enter",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" Select  "),
        Span::styled(
            "q",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" Quit  "),
        Span::styled(
            status,
            Style::default().fg(Color::Green),
        ),
    ]))
    .block(Block::default().borders(Borders::ALL));
    frame.render_widget(footer, area);
}

/// Build a simple text progress bar of the given width.
fn progress_bar(percent: u8, width: usize) -> String {
    let filled = (percent as usize * width) / 100;
    let empty = width - filled;
    format!("[{}{}]", "#".repeat(filled), "-".repeat(empty))
}

/// Pick a colour based on completion percentage.
fn completion_colour(percent: u8) -> Color {
    match percent {
        0..=25 => Color::Red,
        26..=50 => Color::Yellow,
        51..=75 => Color::Blue,
        _ => Color::Green,
    }
}
