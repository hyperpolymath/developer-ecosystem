# SPDX-License-Identifier: MIT OR Palimpsest-0.8
# SPDX-FileCopyrightText: 2025 Hyperpolymath

# Nickel configuration for aggregate-library (aLib)
# Nickel is a gradually typed configuration language with contracts
# https://nickel-lang.org/

{
  project = {
    name = "aggregate-library",
    version = "0.1.0",
    description = "Common Library specification for cross-language programming",
    homepage = "https://github.com/Hyperpolymath/aggregate-library",

    license = {
      type = "dual",
      licenses = ["MIT", "Palimpsest-0.8"],
      spdx = "MIT OR Palimpsest-0.8",
    },

    maintainers = [
      {
        name = "Hyperpolymath",
        role = "lead",
        github = "Hyperpolymath",
      },
    ],
  },

  rsr = {
    compliance = {
      level = "Gold",
      score = 100,
      version = "1.0.0",
      date = "2025-11-22",
    },

    categories = {
      documentation = { score = 10, max = 10 },
      infrastructure = { score = 10, max = 10 },
      security = { score = 10, max = 10 },
      community = { score = 10, max = 10 },
      licensing = { score = 10, max = 10 },
      type_safety = { score = 10, max = 10 },
      offline_first = { score = 10, max = 10 },
      build_system = { score = 10, max = 10 },
      testing = { score = 10, max = 10 },
      metadata = { score = 10, max = 10 },
      reversibility = { score = 10, max = 10 },
    },
  },

  tpcf = {
    perimeter = 3,
    description = "Community Sandbox - open contribution",
  },

  specifications = {
    count = 20,
    categories = [
      "arithmetic",
      "comparison",
      "logical",
      "string",
      "collection",
      "conditional",
    ],

    operations = {
      arithmetic = ["add", "subtract", "multiply", "divide", "modulo"],
      comparison = ["less_than", "greater_than", "equal", "not_equal", "less_equal", "greater_equal"],
      logical = ["and", "or", "not"],
      string = ["concat", "length", "substring"],
      collection = ["map", "filter", "fold", "contains"],
      conditional = ["if_then_else"],
    },
  },

  target_languages = [
    {
      name = "WokeLang",
      philosophy = "consent-driven, emotional",
    },
    {
      name = "Duet/Ensemble",
      philosophy = "AI-first, session types, effects",
    },
    {
      name = "Eclexia",
      philosophy = "sustainability, energy budgets",
    },
    {
      name = "Oblíbený",
      philosophy = "security, provable termination",
    },
    {
      name = "RT-Lang",
      philosophy = "real-time, dependent types, safety certification",
    },
    {
      name = "Phronesis",
      philosophy = "ethical reasoning, values-based",
    },
    {
      name = "Julia the Viper",
      philosophy = "reversible computing, totality",
    },
  ],

  validation = {
    tools = {
      task_runner = "just",
      version_control = "git",
      yaml_lint = "yamllint",
      markdown_lint = "markdownlint-cli",
      link_checker = "lychee",
    },

    commands = {
      validate = "just validate",
      test = "just test",
      docs = "just docs",
      check = "just check",
      rsr = "just rsr",
    },
  },

  features = {
    offline_first = true,
    air_gap_compatible = true,
    reversible = true,
    type_safe = true,
    zero_network_deps = true,
    specification_only = true,
  },
}
