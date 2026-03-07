# SPDX-License-Identifier: PMPL-1.0-or-later

# stdlib-merger

Automated tool for extracting common patterns from multiple language standard libraries and creating a merged aggregate-library with best-of-breed implementations.

## Quick Start

```bash
# Install dependencies
cd tools/stdlib-merger
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run the merger
julia --project=. cli.jl merge \
  --stdlib phronesis:/path/to/phronesis/lib/phronesis/stdlib \
  --stdlib rust:/path/to/rust/library/std \
  --stdlib haskell:/path/to/haskell/base \
  --output ../../lib/aggregate_library \
  --config config/merger.yaml
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for complete architecture documentation.

### Pipeline Overview

```
Input Stlibs → Parse → Match → Rank → Extract → Strip → Output
```

**Components:**
1. **Parser** - Extract function signatures from source files
2. **Matcher** - Identify semantically similar functions
3. **Ranker** - Score implementations and choose the best
4. **Extractor** - Generate aggregate-library modules
5. **Stripper** - Remove extracted functions from original stlibs
6. **Reporter** - Generate documentation

## Directory Structure

```
tools/stdlib-merger/
├── cli.jl                    # CLI entry point
├── Project.toml              # Julia dependencies
├── README.md                 # This file
├── ARCHITECTURE.md           # Detailed architecture
├── src/
│   ├── StdlibMerger.jl       # Main module
│   ├── models.jl             # Data structures
│   ├── orchestrator.jl       # Pipeline coordinator
│   ├── parser.jl             # Parse stlibs
│   ├── matcher.jl            # Match patterns
│   ├── ranker.jl             # Rank implementations
│   ├── extractor.jl          # Extract to aggregate-library
│   ├── stripper.jl           # Strip from original stlibs
│   ├── reporter.jl           # Generate docs
│   ├── parsers/
│   │   ├── elixir_parser.jl
│   │   ├── rust_parser.jl
│   │   └── haskell_parser.jl
│   └── translators/
│       ├── rust_to_elixir.jl
│       └── haskell_to_elixir.jl
├── config/
│   ├── merger.yaml           # Main configuration
│   ├── quality_criteria.yaml
│   └── type_mappings.yaml
├── test/
│   ├── runtests.jl
│   ├── test_parser.jl
│   ├── test_matcher.jl
│   ├── test_ranker.jl
│   └── fixtures/             # Test data
└── examples/
    ├── simple_merge.jl       # Example usage
    └── custom_quality.jl     # Custom quality criteria
```

## Commands

### merge

Extract common patterns and create aggregate-library:

```bash
julia cli.jl merge \
  --stdlib phronesis:/path/to/stdlib \
  --stdlib rust:/path/to/std \
  --stdlib haskell:/path/to/base \
  --output aggregate-library-auto \
  --config config/merger.yaml
```

### analyze

Analyze stlibs without merging (dry run):

```bash
julia cli.jl analyze \
  --stdlib phronesis:/path/to/stdlib \
  --stdlib rust:/path/to/std \
  --stdlib haskell:/path/to/base
```

**Output:**
```
📊 Analysis Results

Phronesis stdlib:
  - 42 modules
  - 180 functions
  - Common patterns: 38

Rust stdlib:
  - 87 modules
  - 1200+ functions
  - Common patterns: 45

Haskell stdlib:
  - 65 modules
  - 800+ functions
  - Common patterns: 41

Universal patterns (in ALL stlibs): 32
```

### rank

Show quality rankings for matched patterns:

```bash
julia cli.jl rank \
  --stdlib phronesis:/path/to/stdlib \
  --stdlib rust:/path/to/std \
  --stdlib haskell:/path/to/base \
  --pattern string_split
```

**Output:**
```
Pattern: string_split

Implementations:
  1. Phronesis: String.split/2         Score: 8.5
     - API Clarity: 9.0
     - Performance: 7.5
     - Error Handling: 8.0
     - Unicode Support: 10.0

  2. Haskell: Data.Text.splitOn        Score: 8.2
     - API Clarity: 9.5
     - Performance: 7.0
     - Error Handling: 7.0
     - Unicode Support: 9.5

  3. Rust: str::split                  Score: 7.8
     - API Clarity: 8.0
     - Performance: 9.0
     - Error Handling: 7.5
     - Unicode Support: 7.0

Best: Phronesis (highest Unicode support, clear API)
```

### extract

Extract specific patterns (without full merge):

```bash
julia cli.jl extract \
  --stdlib phronesis:/path/to/stdlib \
  --pattern string_split,file_read,time_now \
  --output extracted/
```

### strip

Strip extracted patterns from a stdlib:

```bash
julia cli.jl strip \
  --stdlib phronesis:/path/to/stdlib \
  --patterns patterns.json \
  --output stripped_phronesis/
```

### report

Generate reports from previous merge:

```bash
julia cli.jl report \
  --results results.json \
  --output reports/
```

**Generates:**
- `COMPOSITION-GUIDE.md`
- `MIGRATION-GUIDE.md`
- `SIMILARITY-REPORT.md`
- `RANKING-REPORT.md`

## Configuration

### merger.yaml

```yaml
quality_criteria:
  api_clarity:
    weight: 0.30
  performance:
    weight: 0.20
  error_handling:
    weight: 0.25
  unicode_support:
    weight: 0.15
  memory_safety:
    weight: 0.05
  composability:
    weight: 0.05

matching:
  name_similarity_threshold: 0.7
  semantic_similarity_threshold: 0.8
  require_all_stlibs: true

extraction:
  target_language: elixir
  normalize_api: true
  add_docstrings: true

llm:
  provider: anthropic
  model: claude-sonnet-4-5
  api_key_env: ANTHROPIC_API_KEY
```

### Custom Quality Criteria

Create `custom_quality.yaml`:

```yaml
quality_criteria:
  # Your custom weights
  api_clarity:
    weight: 0.5  # Prioritize API clarity
  performance:
    weight: 0.3
  error_handling:
    weight: 0.2
```

Then run:

```bash
julia cli.jl merge \
  --config custom_quality.yaml \
  ...
```

## API Usage (Programmatic)

```julia
using StdlibMerger

# Load stlibs
phronesis = parse_stdlib("/path/to/phronesis/stdlib", :elixir)
rust = parse_stdlib("/path/to/rust/std", :rust)
haskell = parse_stdlib("/path/to/haskell/base", :haskell)

# Find common patterns
patterns = find_patterns([phronesis, rust, haskell])
println("Found $(length(patterns)) common patterns")

# Rank implementations
rankings = rank_implementations.(patterns)

# Extract to aggregate-library
for ranking in rankings
    extract_module(ranking, "output/aggregate_library")
end

# Generate reports
generate_composition_guide(patterns, rankings)
generate_migration_guide(phronesis, patterns)
```

## Environment Variables

```bash
# LLM API key (required for semantic similarity)
export ANTHROPIC_API_KEY=sk-ant-...

# Cache directory (optional)
export STDLIB_MERGER_CACHE=/tmp/stdlib-merger-cache
```

## Examples

### Example 1: Simple Merge

```julia
# examples/simple_merge.jl
using StdlibMerger

merge_stlibs(
    [
        "phronesis" => "/path/to/phronesis/stdlib",
        "rust" => "/path/to/rust/std",
        "haskell" => "/path/to/haskell/base"
    ],
    output_dir = "aggregate-library-auto"
)
```

### Example 2: Custom Quality Criteria

```julia
# examples/custom_quality.jl
using StdlibMerger

# Define custom quality function
function score_custom(impl::FunctionSignature)::Float64
    # Your custom scoring logic
    return score
end

# Use custom criteria
criteria = QualityCriteria(
    api_clarity = Criterion(0.5, score_api_clarity),
    custom = Criterion(0.3, score_custom)
)

merge_stlibs(..., quality_criteria = criteria)
```

## Testing

```bash
# Run all tests
julia --project=. test/runtests.jl

# Run specific test
julia --project=. test/test_parser.jl

# Run with coverage
julia --project=. --code-coverage=user test/runtests.jl
```

## Performance

**Typical merge of 3 stlibs:**
- Parse: ~5 seconds (parallel)
- Match: ~30 seconds (includes LLM API calls, cached)
- Rank: ~10 seconds
- Extract: ~5 seconds
- Strip: ~5 seconds
- **Total: ~1 minute**

**Cache benefits:**
- First run: ~1 minute
- Second run (cached): ~10 seconds

## Limitations

1. **Translation accuracy** - AST-based translation may have bugs, requires human review
2. **LLM dependency** - Semantic similarity requires LLM API access
3. **Language support** - Currently supports Elixir, Rust, Haskell only
4. **Manual review needed** - 20% of decisions require human approval

## Roadmap

- [ ] Support for more languages (Julia, Gleam, OCaml)
- [ ] GUI for reviewing matches
- [ ] Automated regression testing
- [ ] Integration with CI/CD
- [ ] Incremental updates (only re-analyze changed files)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.

## License

PMPL-1.0-or-later
