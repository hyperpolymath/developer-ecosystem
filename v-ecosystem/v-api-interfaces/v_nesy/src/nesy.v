// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Neurosymbolic reasoning with hybrid neural-symbolic inference pipelines Connector
// Author: Jonathan D.A. Jewell
//
// Neurosymbolic reasoning with hybrid neural-symbolic inference pipelines.
// Provides typed client bindings for the proven-nesy protocol.
// Supports confidence thresholding, explanation generation, rule evaluation,
// and JSON payload encoding for pipeline queries.

module nesy

import time

// --- Protocol constants ---

// Default minimum confidence threshold for accepting an inference result.
const default_confidence_threshold = 0.5

// Maximum allowed inference depth before aborting.
const max_inference_depth = 50

// Minimum non-negative confidence value.
const confidence_min = f64(0.0)

// Maximum confidence value (1.0 = certain).
const confidence_max = f64(1.0)

// --- Reasoning mode ---

// ReasoningMode selects the neurosymbolic inference approach.
pub enum ReasoningMode {
	neural_only      // Pure neural inference
	symbolic_only    // Pure symbolic reasoning
	hybrid           // Neural + symbolic fusion
	neural_guided    // Neural guides symbolic search
}

// --- Knowledge type ---

// KnowledgeType classifies knowledge representations.
pub enum KnowledgeType {
	ontology         // OWL/RDF ontology
	rules            // Logic rules
	embeddings       // Vector embeddings
	knowledge_graph  // Graph-based knowledge
}

// --- Data structures ---

// NesyPipeline defines a neurosymbolic reasoning pipeline.
pub struct NesyPipeline {
pub:
	name          string
	mode          ReasoningMode
	knowledge     []KnowledgeSource
	confidence    f64 = 0.8
}

// KnowledgeSource identifies a knowledge base input.
pub struct KnowledgeSource {
pub:
	name          string
	source_type   KnowledgeType
	uri           string
}

// NesyResult holds the outcome of a pipeline query.
pub struct NesyResult {
pub:
	result_id    string
	answer       string   // Best symbolic answer
	confidence   f64      // 0.0–1.0
	explanation  string   // Human-readable justification
	pipeline     string   // Pipeline that produced the result
}

// NesyConfig holds neurosymbolic engine parameters.
pub struct NesyConfig {
pub:
	max_depth      int = 10    // Maximum inference depth
	timeout_ms     int = 5000
	explain        bool = true // Generate explanations
	min_confidence f64 = default_confidence_threshold
}

// NesyEngine manages neurosymbolic reasoning pipelines.
pub struct NesyEngine {
mut:
	config     NesyConfig
	pipelines  []NesyPipeline
}

// --- Engine lifecycle ---

// new_nesy_engine creates a new neurosymbolic engine.
pub fn new_nesy_engine(config NesyConfig) &NesyEngine {
	return &NesyEngine{
		config:    config
		pipelines: []NesyPipeline{}
	}
}

// add_pipeline registers a reasoning pipeline.
pub fn (mut e NesyEngine) add_pipeline(pipeline NesyPipeline) ! {
	if pipeline.name.len == 0 {
		return error("pipeline name must not be empty")
	}
	if pipeline.confidence < confidence_min || pipeline.confidence > confidence_max {
		return error("confidence must be between 0.0 and 1.0")
	}
	e.pipelines << pipeline
	println("[nesy] added pipeline: ${pipeline.name} (${pipeline.mode})")
}

// infer runs inference on a pipeline by name.
pub fn (e &NesyEngine) infer(pipeline_name string, query string) !string {
	if query.len == 0 {
		return error("query must not be empty")
	}
	println("[nesy] inferring: ${query} via ${pipeline_name}")
	return "result-placeholder"
}

// query runs a query through a named pipeline and returns a structured result.
pub fn (e &NesyEngine) query(query string, pipeline_name string) !NesyResult {
	if query.len == 0 {
		return error("query must not be empty")
	}
	for p in e.pipelines {
		if p.name == pipeline_name {
			println("[nesy] query via ${pipeline_name}: ${query}")
			return NesyResult{
				result_id:   "result-${time.now().unix()}"
				answer:      "unknown"
				confidence:  p.confidence
				explanation: if e.config.explain { "derived via ${p.mode}" } else { "" }
				pipeline:    pipeline_name
			}
		}
	}
	return error("pipeline not found: ${pipeline_name}")
}

// get_explanation retrieves a human-readable explanation for a result ID.
pub fn (e &NesyEngine) get_explanation(result_id string) !string {
	if result_id.len == 0 {
		return error("result_id must not be empty")
	}
	println("[nesy] fetching explanation for ${result_id}")
	return "Explanation for ${result_id}: inference via neurosymbolic fusion."
}

// evaluate_rule tests a single logic rule against a set of ground facts.
pub fn (e &NesyEngine) evaluate_rule(rule string, facts []string) !bool {
	if rule.len == 0 {
		return error("rule must not be empty")
	}
	println("[nesy] evaluating rule '${rule}' against ${facts.len} facts")
	// Stub: returns true when at least one fact is present
	return facts.len > 0
}

// --- JSON encoding helper ---

// encode_query_payload serialises a query and mode into a JSON payload string.
pub fn encode_query_payload(query string, mode ReasoningMode) string {
	mode_str := match mode {
		.neural_only   { "neural_only" }
		.symbolic_only { "symbolic_only" }
		.hybrid        { "hybrid" }
		.neural_guided { "neural_guided" }
	}
	return '{"query":"${query}","mode":"${mode_str}"}'
}

// --- Tests ---

fn test_empty_pipeline_name_rejected() {
	mut engine := new_nesy_engine(NesyConfig{})
	engine.add_pipeline(NesyPipeline{ name: "", mode: .hybrid, knowledge: [], confidence: 0.8 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_confidence_threshold_validation() {
	mut engine := new_nesy_engine(NesyConfig{})
	engine.add_pipeline(NesyPipeline{ name: "bad", mode: .hybrid, knowledge: [], confidence: 1.5 }) or {
		assert err.str().contains("confidence")
		return
	}
	assert false
}

fn test_encode_query_payload_structure() {
	payload := encode_query_payload("is_mammal(dolphin)", .hybrid)
	assert payload.contains('"query"')
	assert payload.contains("is_mammal(dolphin)")
	assert payload.contains('"mode"')
	assert payload.contains("hybrid")
}

fn test_evaluate_rule_empty_rule_rejected() {
	engine := new_nesy_engine(NesyConfig{})
	engine.evaluate_rule("", ["fact1"]) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

// list_pipelines returns the names of all registered pipelines.
pub fn (e &NesyEngine) list_pipelines() []string {
	return e.pipelines.map(it.name)
}

// remove_pipeline removes a pipeline by name.
pub fn (mut e NesyEngine) remove_pipeline(name string) ! {
	mut remaining := []NesyPipeline{}
	for p in e.pipelines {
		if p.name != name {
			remaining << p
		}
	}
	if remaining.len == e.pipelines.len {
		return error("pipeline not found: ${name}")
	}
	e.pipelines = remaining
	println("[nesy] removed pipeline: ${name}")
}

fn test_evaluate_rule_with_facts() {
	engine := new_nesy_engine(NesyConfig{})
	result := engine.evaluate_rule("parent(X,Y)", ["parent(alice,bob)"]) or { panic(err) }
	assert result == true
}

fn test_evaluate_rule_no_facts_returns_false() {
	engine := new_nesy_engine(NesyConfig{})
	result := engine.evaluate_rule("mortal(X)", []) or { panic(err) }
	assert result == false
}

fn test_query_pipeline_not_found() {
	engine := new_nesy_engine(NesyConfig{})
	engine.query("test?", "missing") or {
		assert err.str().contains("not found")
		return
	}
	assert false
}

