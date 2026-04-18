//! asdf-bench - Benchmarking tool for asdf operations

use anyhow::Result;
use asdf_core::Plugin;
use asdf_metrics::{Metrics, MetricsCollector, MetricsReporter, SystemInfo};
use clap::Parser;
use colored::Colorize;
use std::time::Instant;

#[derive(Parser)]
#[command(name = "asdf-bench")]
#[command(about = "Benchmarking tool for asdf operations")]
#[command(version)]
struct Cli {
    /// Run all benchmarks
    #[arg(long)]
    all: bool,

    /// Baseline comparison (bash script)
    #[arg(long)]
    baseline: Option<String>,

    /// Output format (text, json, html)
    #[arg(long, default_value = "text")]
    format: String,

    /// Output file
    #[arg(short, long)]
    output: Option<String>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    println!(
        "{}",
        "asdf-bench - Performance Benchmarking"
            .bright_cyan()
            .bold()
    );
    println!("{}", "===================================".bright_black());
    println!();

    let mut collector = MetricsCollector::new();

    // Benchmark: List plugins
    println!("{} Benchmarking: List plugins", "->".cyan());
    collector.start();

    let start = Instant::now();
    let plugins = Plugin::list()?;
    let duration = start.elapsed();

    collector.record_success();

    println!(
        "  {} Found {} plugins in {:.2}s",
        "OK".green(),
        plugins.len(),
        duration.as_secs_f64()
    );

    // System info
    let system_info = MetricsCollector::system_info();

    // Generate report
    match cli.format.as_str() {
        "json" => {
            let json = MetricsReporter::to_json(collector.metrics(), &system_info)?;
            if let Some(output) = cli.output {
                std::fs::write(&output, &json)?;
                println!("{} JSON report written to {}", "OK".green(), output);
            } else {
                println!("{}", json);
            }
        }
        "html" => {
            let html = generate_html_report(collector.metrics(), &system_info, &plugins)?;
            if let Some(output) = cli.output {
                std::fs::write(&output, &html)?;
                println!("{} HTML report written to {}", "OK".green(), output);
            } else {
                println!("{}", html);
            }
        }
        _ => {
            let report = MetricsReporter::format_colored_report(collector.metrics(), &system_info);
            println!("{}", report);
        }
    }

    Ok(())
}

/// Generate an HTML benchmark report
fn generate_html_report(
    metrics: &Metrics,
    system_info: &SystemInfo,
    plugins: &[Plugin],
) -> Result<String> {
    let timestamp = chrono_lite_timestamp();

    let plugin_rows: String = plugins
        .iter()
        .map(|p| {
            let url = p.url.as_deref().unwrap_or("-");
            format!(
                r#"        <tr>
          <td>{}</td>
          <td><code>{}</code></td>
        </tr>"#,
                html_escape(&p.name),
                html_escape(url)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");

    let html = format!(
        r#"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>asdf-bench Report</title>
  <style>
    :root {{
      --bg-primary: #1a1b26;
      --bg-secondary: #24283b;
      --text-primary: #c0caf5;
      --text-secondary: #565f89;
      --accent-cyan: #7dcfff;
      --accent-green: #9ece6a;
      --accent-yellow: #e0af68;
      --accent-red: #f7768e;
      --border-color: #414868;
    }}
    * {{
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: var(--bg-primary);
      color: var(--text-primary);
      line-height: 1.6;
      padding: 2rem;
    }}
    .container {{
      max-width: 1200px;
      margin: 0 auto;
    }}
    header {{
      text-align: center;
      margin-bottom: 2rem;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--border-color);
    }}
    h1 {{
      color: var(--accent-cyan);
      font-size: 2rem;
      margin-bottom: 0.5rem;
    }}
    .timestamp {{
      color: var(--text-secondary);
      font-size: 0.875rem;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 1.5rem;
      margin-bottom: 2rem;
    }}
    .card {{
      background: var(--bg-secondary);
      border-radius: 8px;
      padding: 1.5rem;
      border: 1px solid var(--border-color);
    }}
    .card h2 {{
      color: var(--accent-cyan);
      font-size: 1.125rem;
      margin-bottom: 1rem;
      padding-bottom: 0.5rem;
      border-bottom: 1px solid var(--border-color);
    }}
    .stat {{
      display: flex;
      justify-content: space-between;
      padding: 0.5rem 0;
    }}
    .stat-label {{
      color: var(--text-secondary);
    }}
    .stat-value {{
      font-weight: 600;
    }}
    .stat-value.success {{
      color: var(--accent-green);
    }}
    .stat-value.warning {{
      color: var(--accent-yellow);
    }}
    .stat-value.error {{
      color: var(--accent-red);
    }}
    .progress-bar {{
      width: 100%;
      height: 8px;
      background: var(--bg-primary);
      border-radius: 4px;
      overflow: hidden;
      margin-top: 0.5rem;
    }}
    .progress-fill {{
      height: 100%;
      border-radius: 4px;
      transition: width 0.3s ease;
    }}
    .progress-fill.low {{
      background: var(--accent-green);
    }}
    .progress-fill.medium {{
      background: var(--accent-yellow);
    }}
    .progress-fill.high {{
      background: var(--accent-red);
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
    }}
    th, td {{
      padding: 0.75rem;
      text-align: left;
      border-bottom: 1px solid var(--border-color);
    }}
    th {{
      color: var(--text-secondary);
      font-weight: 500;
      font-size: 0.875rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }}
    td code {{
      background: var(--bg-primary);
      padding: 0.125rem 0.375rem;
      border-radius: 4px;
      font-size: 0.75rem;
      color: var(--text-secondary);
    }}
    footer {{
      text-align: center;
      color: var(--text-secondary);
      font-size: 0.875rem;
      margin-top: 2rem;
      padding-top: 1rem;
      border-top: 1px solid var(--border-color);
    }}
    footer a {{
      color: var(--accent-cyan);
      text-decoration: none;
    }}
    footer a:hover {{
      text-decoration: underline;
    }}
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>asdf-bench Performance Report</h1>
      <p class="timestamp">Generated: {}</p>
    </header>

    <div class="grid">
      <div class="card">
        <h2>Operations</h2>
        <div class="stat">
          <span class="stat-label">Total</span>
          <span class="stat-value">{}</span>
        </div>
        <div class="stat">
          <span class="stat-label">Succeeded</span>
          <span class="stat-value success">{}</span>
        </div>
        <div class="stat">
          <span class="stat-label">Failed</span>
          <span class="stat-value {}">{}</span>
        </div>
        <div class="stat">
          <span class="stat-label">Success Rate</span>
          <span class="stat-value success">{:.1}%</span>
        </div>
      </div>

      <div class="card">
        <h2>Timing</h2>
        <div class="stat">
          <span class="stat-label">Total Duration</span>
          <span class="stat-value">{:.3}s</span>
        </div>
        <div class="stat">
          <span class="stat-label">Average Duration</span>
          <span class="stat-value">{:.3}s</span>
        </div>
      </div>

      <div class="card">
        <h2>System</h2>
        <div class="stat">
          <span class="stat-label">CPU Cores</span>
          <span class="stat-value">{}</span>
        </div>
        <div class="stat">
          <span class="stat-label">Memory Usage</span>
          <span class="stat-value {}">{:.1}%</span>
        </div>
        <div class="progress-bar">
          <div class="progress-fill {}" style="width: {:.1}%"></div>
        </div>
        <div class="stat">
          <span class="stat-label">Memory</span>
          <span class="stat-value">{} MB / {} MB</span>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Installed Plugins ({})</h2>
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Repository URL</th>
          </tr>
        </thead>
        <tbody>
{}
        </tbody>
      </table>
    </div>

    <footer>
      <p>Generated by <a href="https://github.com/Hyperpolymath/asdf-acceleration-middleware">asdf-acceleration-middleware</a></p>
    </footer>
  </div>
</body>
</html>
"#,
        timestamp,
        metrics.operations_total,
        metrics.operations_succeeded,
        if metrics.operations_failed > 0 {
            "error"
        } else {
            ""
        },
        metrics.operations_failed,
        metrics.success_rate(),
        metrics.total_duration.as_secs_f64(),
        metrics.average_duration.as_secs_f64(),
        system_info.cpu_count,
        memory_usage_class(system_info.memory_usage_percent()),
        system_info.memory_usage_percent(),
        memory_progress_class(system_info.memory_usage_percent()),
        system_info.memory_usage_percent(),
        system_info.used_memory_kb / 1024,
        system_info.total_memory_kb / 1024,
        plugins.len(),
        plugin_rows
    );

    Ok(html)
}

/// Get CSS class for memory usage percentage
fn memory_usage_class(percent: f64) -> &'static str {
    if percent > 80.0 {
        "error"
    } else if percent > 60.0 {
        "warning"
    } else {
        "success"
    }
}

/// Get CSS class for memory progress bar
fn memory_progress_class(percent: f64) -> &'static str {
    if percent > 80.0 {
        "high"
    } else if percent > 60.0 {
        "medium"
    } else {
        "low"
    }
}

/// Simple HTML escaping
fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

/// Generate a simple timestamp without external chrono dependency
fn chrono_lite_timestamp() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};

    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();

    let secs = duration.as_secs();

    // Calculate date components (simplified, assumes UTC)
    let days_since_epoch = secs / 86400;
    let time_of_day = secs % 86400;

    let hours = time_of_day / 3600;
    let minutes = (time_of_day % 3600) / 60;
    let seconds = time_of_day % 60;

    // Simplified year calculation (good enough for display)
    let mut year = 1970;
    let mut remaining_days = days_since_epoch as i64;

    while remaining_days >= days_in_year(year) {
        remaining_days -= days_in_year(year);
        year += 1;
    }

    let mut month = 1;
    while remaining_days >= days_in_month(year, month) {
        remaining_days -= days_in_month(year, month);
        month += 1;
    }

    let day = remaining_days + 1;

    format!(
        "{:04}-{:02}-{:02} {:02}:{:02}:{:02} UTC",
        year, month, day, hours, minutes, seconds
    )
}

fn is_leap_year(year: i64) -> bool {
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
}

fn days_in_year(year: i64) -> i64 {
    if is_leap_year(year) {
        366
    } else {
        365
    }
}

fn days_in_month(year: i64, month: i64) -> i64 {
    match month {
        1 => 31,
        2 => {
            if is_leap_year(year) {
                29
            } else {
                28
            }
        }
        3 => 31,
        4 => 30,
        5 => 31,
        6 => 30,
        7 => 31,
        8 => 31,
        9 => 30,
        10 => 31,
        11 => 30,
        12 => 31,
        _ => 30,
    }
}
