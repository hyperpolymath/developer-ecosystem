// SPDX-License-Identifier: PMPL-1.0-or-later
//
// App state for the IDApTIK Escape Hatch developer TUI.

use serde::{Deserialize, Serialize};

/// Which top-level tab is active.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ActiveTab {
    Dashboard,
    Commands,
}

/// A single component shown on the dashboard.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentStatus {
    pub name: String,
    pub completion: u8,
    pub status: String,
}

/// A command entry in the Commands tab.
#[derive(Debug, Clone)]
pub struct CommandEntry {
    pub label: &'static str,
    pub description: &'static str,
}

/// Top-level application state.
#[derive(Debug)]
pub struct App {
    pub running: bool,
    pub active_tab: ActiveTab,
    pub dashboard_items: Vec<ComponentStatus>,
    pub commands: Vec<CommandEntry>,
    pub dashboard_selected: usize,
    pub command_selected: usize,
    pub status_message: Option<String>,
}

impl App {
    /// Create a new App with default IDApTIK component data.
    pub fn new() -> Self {
        let dashboard_items = vec![
            ComponentStatus {
                name: "main-game (IDApixiTIK)".into(),
                completion: 72,
                status: "Active".into(),
            },
            ComponentStatus {
                name: "VM".into(),
                completion: 35,
                status: "In Progress".into(),
            },
            ComponentStatus {
                name: "shared".into(),
                completion: 60,
                status: "Active".into(),
            },
            ComponentStatus {
                name: "multiplayer".into(),
                completion: 15,
                status: "Planned".into(),
            },
            ComponentStatus {
                name: "idaptik-level-architect".into(),
                completion: 40,
                status: "In Progress".into(),
            },
            ComponentStatus {
                name: "idaptik-developers".into(),
                completion: 20,
                status: "In Progress".into(),
            },
            ComponentStatus {
                name: "containers".into(),
                completion: 10,
                status: "Planned".into(),
            },
            ComponentStatus {
                name: "DLC".into(),
                completion: 5,
                status: "Planned".into(),
            },
            ComponentStatus {
                name: "escape-hatch".into(),
                completion: 5,
                status: "Scaffolding".into(),
            },
        ];

        let commands = vec![
            CommandEntry {
                label: "Build Game",
                description: "Compile the main IDApTIK game",
            },
            CommandEntry {
                label: "Run Tests",
                description: "Execute the full test suite",
            },
            CommandEntry {
                label: "Start Sync Server",
                description: "Launch the multiplayer sync server",
            },
            CommandEntry {
                label: "Launch Dev Server",
                description: "Start the local development server",
            },
        ];

        Self {
            running: true,
            active_tab: ActiveTab::Dashboard,
            dashboard_items,
            commands,
            dashboard_selected: 0,
            command_selected: 0,
            status_message: None,
        }
    }

    /// Cycle to the next tab.
    pub fn next_tab(&mut self) {
        self.active_tab = match self.active_tab {
            ActiveTab::Dashboard => ActiveTab::Commands,
            ActiveTab::Commands => ActiveTab::Dashboard,
        };
    }

    /// Move selection up in the current list.
    pub fn select_previous(&mut self) {
        match self.active_tab {
            ActiveTab::Dashboard => {
                if self.dashboard_selected > 0 {
                    self.dashboard_selected -= 1;
                }
            }
            ActiveTab::Commands => {
                if self.command_selected > 0 {
                    self.command_selected -= 1;
                }
            }
        }
    }

    /// Move selection down in the current list.
    pub fn select_next(&mut self) {
        match self.active_tab {
            ActiveTab::Dashboard => {
                if self.dashboard_selected + 1 < self.dashboard_items.len() {
                    self.dashboard_selected += 1;
                }
            }
            ActiveTab::Commands => {
                if self.command_selected + 1 < self.commands.len() {
                    self.command_selected += 1;
                }
            }
        }
    }

    /// Handle Enter on the current selection.
    pub fn execute_selected(&mut self) {
        match self.active_tab {
            ActiveTab::Dashboard => {
                let item = &self.dashboard_items[self.dashboard_selected];
                self.status_message =
                    Some(format!("{}: {}% complete", item.name, item.completion));
            }
            ActiveTab::Commands => {
                let cmd = &self.commands[self.command_selected];
                self.status_message =
                    Some(format!("[not wired] Would run: {}", cmd.label));
            }
        }
    }

    /// Signal the application to quit.
    pub fn quit(&mut self) {
        self.running = false;
    }
}
