// SPDX-License-Identifier: PMPL-1.0-or-later

/// TEA-specialised routing integration for ReScript.
///
/// This module provides the wiring to connect cadre-router's URL parsing
/// to TEA (The Elm Architecture) applications.
///
/// Features:
/// - URL parsing and navigation
/// - Query parameter persistence for deep-linking
/// - Route guards for blocking navigation during sync

module Router = Tea_Router
module Navigation = Tea_Navigation
module Url = Tea_Url
module QueryParams = Tea_QueryParams
module Guards = Tea_Guards
