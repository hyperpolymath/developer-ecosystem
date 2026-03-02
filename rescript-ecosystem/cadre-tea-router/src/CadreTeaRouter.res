// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@ocaml.doc("
  TEA-specialised routing integration for ReScript.

  This module provides the wiring to connect cadre-router's URL parsing
  to TEA (The Elm Architecture) applications.

  Features:
  - URL parsing and navigation
  - Query parameter persistence for deep-linking
  - Route guards for blocking navigation during sync
")

module Router = CadreTeaRouter_Router
module Navigation = CadreTeaRouter_Navigation
module Url = CadreTeaRouter_Url
module QueryParams = CadreTeaRouter_QueryParams
module Guards = CadreTeaRouter_Guards
