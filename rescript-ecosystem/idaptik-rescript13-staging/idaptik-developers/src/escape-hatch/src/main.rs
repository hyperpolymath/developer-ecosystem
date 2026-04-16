// SPDX-License-Identifier: PMPL-1.0-or-later
//
// IDApTIK Escape Hatch - Developer Command Centre TUI
//
// A ratatui-based terminal interface for managing IDApTIK development tasks,
// viewing component status, and running common developer commands.

#![forbid(unsafe_code)]
mod app;
mod ui;

use std::io;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{Terminal, backend::CrosstermBackend};

use app::App;

/// Entry point. Sets up the terminal, runs the event loop, then restores
/// the terminal on exit.
#[tokio::main]
async fn main() -> io::Result<()> {
    // Initialise terminal.
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Run the app.
    let result = run_app(&mut terminal).await;

    // Restore terminal.
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    result
}

/// Main event loop: draw, then handle input.
async fn run_app(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> io::Result<()> {
    let mut app = App::new();

    while app.running {
        terminal.draw(|frame| ui::draw(frame, &app))?;

        // Block until an event arrives.
        if let Event::Key(key) = event::read()? {
            // Only respond to key-press events (ignore release/repeat on
            // terminals that send them).
            if key.kind != KeyEventKind::Press {
                continue;
            }

            match key.code {
                KeyCode::Char('q') | KeyCode::Char('Q') => app.quit(),
                KeyCode::Tab | KeyCode::BackTab => app.next_tab(),
                KeyCode::Up => app.select_previous(),
                KeyCode::Down => app.select_next(),
                KeyCode::Enter => app.execute_selected(),
                _ => {}
            }
        }
    }

    Ok(())
}
