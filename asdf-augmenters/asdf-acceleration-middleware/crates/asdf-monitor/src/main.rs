//! asdf-monitor - Real-time monitoring and metrics dashboard

use anyhow::Result;
use asdf_core::Plugin;
use asdf_metrics::{MetricsCollector, MetricsReporter};
use clap::{Parser, Subcommand};
use colored::Colorize;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph},
    Frame, Terminal,
};
use std::io;
use std::time::{Duration, Instant};

#[derive(Parser)]
#[command(name = "asdf-monitor")]
#[command(about = "Real-time monitoring and metrics dashboard")]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Launch interactive dashboard
    Dashboard,

    /// Export current metrics
    Metrics {
        /// Output format (text, json, prometheus)
        #[arg(long, default_value = "text")]
        format: String,

        /// Output file
        #[arg(short, long)]
        output: Option<String>,
    },

    /// Health check
    Health,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Dashboard => dashboard(),
        Commands::Metrics { format, output } => metrics(&format, output.as_deref()),
        Commands::Health => health(),
    }
}

/// Application state for the TUI dashboard
struct App {
    /// System information
    system_info: asdf_metrics::SystemInfo,
    /// List of installed plugins
    plugins: Vec<Plugin>,
    /// Currently selected plugin index
    selected_plugin: usize,
    /// Last refresh time
    last_refresh: Instant,
    /// Refresh interval
    refresh_interval: Duration,
    /// Whether to show help
    show_help: bool,
}

impl App {
    fn new() -> Result<Self> {
        Ok(Self {
            system_info: MetricsCollector::system_info(),
            plugins: Plugin::list().unwrap_or_default(),
            selected_plugin: 0,
            last_refresh: Instant::now(),
            refresh_interval: Duration::from_secs(2),
            show_help: false,
        })
    }

    fn refresh(&mut self) {
        if self.last_refresh.elapsed() >= self.refresh_interval {
            self.system_info = MetricsCollector::system_info();
            self.plugins = Plugin::list().unwrap_or_default();
            self.last_refresh = Instant::now();
        }
    }

    fn next_plugin(&mut self) {
        if !self.plugins.is_empty() {
            self.selected_plugin = (self.selected_plugin + 1) % self.plugins.len();
        }
    }

    fn previous_plugin(&mut self) {
        if !self.plugins.is_empty() {
            self.selected_plugin = if self.selected_plugin > 0 {
                self.selected_plugin - 1
            } else {
                self.plugins.len() - 1
            };
        }
    }

    fn toggle_help(&mut self) {
        self.show_help = !self.show_help;
    }
}

fn dashboard() -> Result<()> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app state
    let mut app = App::new()?;

    // Main loop
    let res = run_dashboard(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        println!("{} Error: {:?}", "✗".red(), err);
    }

    Ok(())
}

fn run_dashboard<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
) -> Result<()> {
    loop {
        // Refresh data periodically
        app.refresh();

        // Draw the UI
        terminal.draw(|f| ui(f, app))?;

        // Handle input with timeout for auto-refresh
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                        KeyCode::Char('j') | KeyCode::Down => app.next_plugin(),
                        KeyCode::Char('k') | KeyCode::Up => app.previous_plugin(),
                        KeyCode::Char('r') => {
                            app.last_refresh = Instant::now() - app.refresh_interval;
                        }
                        KeyCode::Char('?') | KeyCode::Char('h') => app.toggle_help(),
                        _ => {}
                    }
                }
            }
        }
    }
}

fn ui(f: &mut Frame, app: &App) {
    // Create main layout
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(3),  // Header
            Constraint::Length(7),  // System info
            Constraint::Min(10),    // Plugins list
            Constraint::Length(3),  // Footer
        ])
        .split(f.area());

    // Header
    let header = Paragraph::new(Line::from(vec![
        Span::styled(
            " asdf-monitor ",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw("- Real-time Dashboard"),
    ]))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::Cyan)),
    );
    f.render_widget(header, chunks[0]);

    // System info section
    render_system_info(f, app, chunks[1]);

    // Plugins section
    render_plugins(f, app, chunks[2]);

    // Footer
    let footer_text = if app.show_help {
        "q: quit | j/k: navigate | r: refresh | ?: toggle help"
    } else {
        "Press ? for help | q to quit"
    };
    let footer = Paragraph::new(footer_text)
        .style(Style::default().fg(Color::DarkGray))
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[3]);

    // Show help overlay if enabled
    if app.show_help {
        render_help_popup(f);
    }
}

fn render_system_info(f: &mut Frame, app: &App, area: Rect) {
    let block = Block::default()
        .title(" System ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Green));

    let inner = block.inner(area);
    f.render_widget(block, area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(2),
            Constraint::Length(1),
        ])
        .split(inner);

    // CPU info
    let cpu_text = format!("CPUs: {}", app.system_info.cpu_count);
    let cpu_para = Paragraph::new(cpu_text);
    f.render_widget(cpu_para, chunks[0]);

    // Memory gauge
    let memory_percent = app.system_info.memory_usage_percent();
    let memory_label = format!(
        "Memory: {:.1}% ({} MB / {} MB)",
        memory_percent,
        app.system_info.used_memory_kb / 1024,
        app.system_info.total_memory_kb / 1024
    );
    let gauge_color = if memory_percent > 80.0 {
        Color::Red
    } else if memory_percent > 60.0 {
        Color::Yellow
    } else {
        Color::Green
    };
    let memory_gauge = Gauge::default()
        .label(memory_label)
        .ratio(memory_percent / 100.0)
        .gauge_style(Style::default().fg(gauge_color));
    f.render_widget(memory_gauge, chunks[1]);

    // Plugin count
    let plugin_text = format!("Plugins: {}", app.plugins.len());
    let plugin_para = Paragraph::new(plugin_text);
    f.render_widget(plugin_para, chunks[2]);
}

fn render_plugins(f: &mut Frame, app: &App, area: Rect) {
    let items: Vec<ListItem> = app
        .plugins
        .iter()
        .enumerate()
        .map(|(i, plugin)| {
            let style = if i == app.selected_plugin {
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default()
            };

            let prefix = if i == app.selected_plugin { ">" } else { " " };
            let url_info = plugin
                .url
                .as_ref()
                .map(|u| format!(" ({})", truncate_url(u, 40)))
                .unwrap_or_default();

            ListItem::new(format!("{} {}{}", prefix, plugin.name, url_info)).style(style)
        })
        .collect();

    let plugins_list = List::new(items)
        .block(
            Block::default()
                .title(" Plugins ")
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Blue)),
        )
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
        );

    f.render_widget(plugins_list, area);
}

fn render_help_popup(f: &mut Frame) {
    let area = centered_rect(60, 50, f.area());

    let help_text = vec![
        Line::from(Span::styled(
            "Keyboard Shortcuts",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from("  q, Esc     Quit the dashboard"),
        Line::from("  j, Down    Select next plugin"),
        Line::from("  k, Up      Select previous plugin"),
        Line::from("  r          Force refresh data"),
        Line::from("  ?, h       Toggle this help"),
        Line::from(""),
        Line::from(Span::styled(
            "Press any key to close",
            Style::default().fg(Color::DarkGray),
        )),
    ];

    let help = Paragraph::new(help_text)
        .block(
            Block::default()
                .title(" Help ")
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Yellow)),
        )
        .style(Style::default().bg(Color::Black));

    // Clear the area first
    f.render_widget(ratatui::widgets::Clear, area);
    f.render_widget(help, area);
}

/// Helper function to create a centered rectangle
fn centered_rect(percent_x: u16, percent_y: u16, r: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}

/// Truncate a URL for display
fn truncate_url(url: &str, max_len: usize) -> String {
    if url.len() <= max_len {
        url.to_string()
    } else {
        format!("{}...", &url[..max_len - 3])
    }
}

fn metrics(format: &str, output: Option<&str>) -> Result<()> {
    let collector = MetricsCollector::new();
    let system_info = MetricsCollector::system_info();

    let content = match format {
        "json" => MetricsReporter::to_json(collector.metrics(), &system_info)?,
        "prometheus" => export_prometheus(collector.metrics())?,
        _ => MetricsReporter::format_colored_report(collector.metrics(), &system_info),
    };

    if let Some(path) = output {
        std::fs::write(path, &content)?;
        println!("{} Metrics written to {}", "✓".green(), path);
    } else {
        println!("{}", content);
    }

    Ok(())
}

fn export_prometheus(metrics: &asdf_metrics::Metrics) -> Result<String> {
    Ok(asdf_metrics::export_prometheus(metrics)?)
}

fn health() -> Result<()> {
    println!("{} Running health check...", "→".cyan());

    if !asdf_core::is_asdf_installed() {
        println!("{} asdf is not installed", "✗".red());
        return Ok(());
    }

    println!("{} asdf is installed", "✓".green());

    let version = asdf_core::asdf_version()?;
    println!("{} Version: {}", "✓".green(), version);

    let plugins = Plugin::list()?;
    println!("{} Plugins: {}", "✓".green(), plugins.len());

    let system_info = MetricsCollector::system_info();
    println!(
        "{} System: {} CPUs, {:.1}% memory usage",
        "✓".green(),
        system_info.cpu_count,
        system_info.memory_usage_percent()
    );

    println!("\n{} System is healthy", "✓".green().bold());

    Ok(())
}
