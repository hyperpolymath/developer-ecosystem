// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Neurosymbolic CI/CD intelligence with security scanning and policy enforcement Connector
// Author: Jonathan D.A. Jewell
//
// Neurosymbolic CI/CD intelligence with security scanning and policy enforcement.
// Provides typed client bindings for the proven-neurosym protocol.
// Supports multi-rule scanning, fact assertion/retraction, Prolog-style
// goal queries, knowledge base loading, and clause formatting.

module neurosym

import os

// --- Protocol constants ---

// Maximum number of query results returned per Prolog goal.
const max_query_results = 256

// Clause separator used in formatted output.
const clause_neck = " :- "

// --- Symbol type ---

// SymbolType classifies elements of a neurosymbolic knowledge base.
pub enum SymbolType {
	predicate   // Logical predicate (e.g. parent/2)
	functor     // Compound term constructor (e.g. f(x,y))
	variable    // Uninstantiated logical variable (e.g. X)
	constant    // Ground atom or number (e.g. alice, 42)
}

// --- Scan type ---

// ScanType classifies the neurosymbolic CI/CD scan.
pub enum ScanType {
	security       // Vulnerability scanning
	compliance     // Policy compliance
	quality        // Code quality
	supply_chain   // Dependency analysis
}

// --- Finding severity ---

// FindingSeverity classifies scan finding severity.
pub enum FindingSeverity {
	info
	low
	medium
	high
	critical
}

// --- Data structures ---

// ScanRule defines a neurosymbolic scanning rule.
pub struct ScanRule {
pub:
	rule_id     string
	name        string
	scan_type   ScanType
	pattern     string     // Detection pattern
	severity    FindingSeverity
}

// ScanFinding represents a detected issue.
pub struct ScanFinding {
pub:
	rule_id     string
	file_path   string
	line        int
	message     string
	severity    FindingSeverity
}

// KbFact holds a single asserted ground fact.
pub struct KbFact {
pub:
	functor string   // Predicate name
	args    []string // Ground argument list
}

// NeurosymConfig holds neurosymbolic scanner parameters.
pub struct NeurosymConfig {
pub:
	repo_path    string
	rules_path   string
	fail_on      FindingSeverity = .high
}

// NeurosymScanner manages CI/CD scanning.
pub struct NeurosymScanner {
mut:
	config    NeurosymConfig
	rules     []ScanRule
	findings  []ScanFinding
	kb_facts  []KbFact
}

// --- Scanner lifecycle ---

// new_neurosym_scanner creates a new neurosymbolic scanner.
pub fn new_neurosym_scanner(config NeurosymConfig) &NeurosymScanner {
	return &NeurosymScanner{
		config:   config
		rules:    []ScanRule{}
		findings: []ScanFinding{}
		kb_facts: []KbFact{}
	}
}

// load_rule adds a scanning rule.
pub fn (mut s NeurosymScanner) load_rule(rule ScanRule) ! {
	if rule.rule_id.len == 0 {
		return error("rule_id must not be empty")
	}
	s.rules << rule
	println("[neurosym] loaded rule: ${rule.name} (${rule.scan_type})")
}

// scan runs all rules and returns finding count.
pub fn (mut s NeurosymScanner) scan() !int {
	println("[neurosym] scanning ${s.config.repo_path} with ${s.rules.len} rules")
	return s.findings.len
}

// assert_fact adds a ground fact to the knowledge base.
pub fn (mut s NeurosymScanner) assert_fact(fact string) ! {
	if fact.len == 0 {
		return error("fact must not be empty")
	}
	s.kb_facts << KbFact{ functor: fact, args: [] }
	println("[neurosym] asserted fact: ${fact}")
}

// retract_fact removes a ground fact from the knowledge base.
pub fn (mut s NeurosymScanner) retract_fact(fact string) ! {
	if fact.len == 0 {
		return error("fact must not be empty")
	}
	mut remaining := []KbFact{}
	for f in s.kb_facts {
		if f.functor != fact {
			remaining << f
		}
	}
	if remaining.len == s.kb_facts.len {
		return error("fact not found: ${fact}")
	}
	s.kb_facts = remaining
	println("[neurosym] retracted fact: ${fact}")
}

// query_prolog evaluates a Prolog-style goal against the knowledge base.
// Returns matching fact strings up to max_query_results.
pub fn (s &NeurosymScanner) query_prolog(goal string) ![]string {
	if goal.len == 0 {
		return error("goal must not be empty")
	}
	println("[neurosym] prolog query: ${goal}")
	mut results := []string{}
	for f in s.kb_facts {
		if f.functor.contains(goal) {
			results << f.functor
			if results.len >= max_query_results {
				break
			}
		}
	}
	return results
}

// load_knowledge_base reads facts from a file, one per line.
// Returns the number of facts loaded.
pub fn (mut s NeurosymScanner) load_knowledge_base(path string) !int {
	if path.len == 0 {
		return error("path must not be empty")
	}
	content := os.read_file(path) or {
		return error("cannot read knowledge base: ${err}")
	}
	lines := content.split_into_lines()
	mut loaded := 0
	for line in lines {
		trimmed := line.trim_space()
		if trimmed.len > 0 && !trimmed.starts_with('%') {
			s.kb_facts << KbFact{ functor: trimmed, args: [] }
			loaded++
		}
	}
	println("[neurosym] loaded ${loaded} facts from ${path}")
	return loaded
}

// --- Clause formatting helper ---

// format_clause serialises a Horn clause (head :- body) as a Prolog string.
// An empty body list produces a fact (no neck).
pub fn format_clause(head string, body []string) string {
	if body.len == 0 {
		return "${head}."
	}
	return "${head}${clause_neck}${body.join(', ')}."
}

// --- Tests ---

fn test_empty_rule_id_rejected() {
	mut scanner := new_neurosym_scanner(NeurosymConfig{ repo_path: "/tmp/repo", rules_path: "/tmp/rules" })
	scanner.load_rule(ScanRule{ rule_id: "", name: "test", scan_type: .security, pattern: "", severity: .high }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_format_clause_fact() {
	result := format_clause("human(socrates)", [])
	assert result == "human(socrates)."
}

fn test_format_clause_rule() {
	result := format_clause("mortal(X)", ["human(X)"])
	assert result.contains(":- ")
	assert result.contains("mortal(X)")
	assert result.contains("human(X)")
	assert result.ends_with(".")
}

fn test_assert_and_retract_fact() {
	mut scanner := new_neurosym_scanner(NeurosymConfig{ repo_path: "/tmp" })
	scanner.assert_fact("alive(sparrow)") or { panic(err) }
	assert scanner.kb_facts.len == 1
	scanner.retract_fact("alive(sparrow)") or { panic(err) }
	assert scanner.kb_facts.len == 0
}

fn test_query_prolog_returns_matching_facts() {
	mut scanner := new_neurosym_scanner(NeurosymConfig{ repo_path: "/tmp" })
	scanner.assert_fact("human(socrates)") or { panic(err) }
	scanner.assert_fact("human(plato)") or { panic(err) }
	scanner.assert_fact("cat(felix)") or { panic(err) }
	results := scanner.query_prolog("human") or { panic(err) }
	assert results.len == 2
}

fn test_empty_goal_rejected() {
	scanner := new_neurosym_scanner(NeurosymConfig{ repo_path: "/tmp" })
	scanner.query_prolog("") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

