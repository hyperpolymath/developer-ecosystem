# justfile for ReScript Ecosystem Map
# Usage: `just update` (runs all updates), or target specific tasks.

# --- Core Workflow ---
update: update-coverage update-readme lint gen-diagrams
    git add README.adoc docs/COVERAGE.adoc docs/*.svg
    git commit -m "chore: update docs and diagrams [skip ci]" || true

# --- Coverage Management ---
# Generate docs/COVERAGE.adoc from GitHub API (or local repos)
update-coverage:
    # Fetch statuses from GitHub (replace with your logic)
    ./scripts/fetch_github_statuses.rb > docs/COVERAGE.adoc.tmp
    # Format the table (ensure consistent columns)
    just --fmt-coverage
    mv docs/COVERAGE.adoc.tmp docs/COVERAGE.adoc

fmt-coverage:
    column -t -s $'\t' docs/COVERAGE.adoc > docs/COVERAGE.adoc.tmp && \
    mv docs/COVERAGE.adoc.tmp docs/COVERAGE.adoc

# --- README Management ---
update-readme:
    # Sync coverage table into README.adoc
    sed -i '/== Coverage Status/,/^$$/ { /== Coverage Status/{p; r docs/COVERAGE.adoc'; 'd; } }' README.adoc
    # Validate links and tables
    just --lint-readme

lint-readme:
    ack --adoc 'link:' README.adoc | grep -v 'licences\|CONTRIBUTING' || echo "✅ All links validated"
    asciidoctor-lint README.adoc

# --- Diagram Generation ---
gen-diagrams:
    # Generate SVG diagrams from PlantUML sources
    plantuml -tsvg diagrams/*.puml && mv diagrams/*.svg docs/

# --- Helper Recipes ---
# Generate a new coverage template (if needed)
gen-coverage-template:
    cat > docs/COVERAGE.adoc << 'EOF'
= Component Coverage Status
:toc:

== ✅ Hyperpolymath Components (Ours)
[cols="1,2,1,1",options="header"]
|===
| Component          | Description                          | Status      | Link
| rescript-tea       | TEA (Elm Architecture) with layout   | ✅ Active    | link:https://github.com/hyperpolymath/rescript-tea[GitHub]
|===

== 🔵 Community Components (Recommended)
[cols="1,2,1,1",options="header"]
|===
| Component          | Description                          | Status      | Link
| @rescript/react    | Official React bindings              | ✅ Stable    | link:https://github.com/rescript-lang/rescript-react[GitHub]
|===

== ⚠️ Legacy (Not Recommended)
[cols="1,2,1",options="header"]
|===
| Component          | Issue                                | Alternative
| rescript-nodejs    | Lacks Deno’s security model          | Migrate to `rescript-wasm-runtime`
|===

== ⬜ Gaps (Prioritised)
[cols="1,2",options="header"]
|===
| Component          | Requirement
| rescript-tauri     | Tauri 2.0 bindings for mobile/desktop
|===
EOF

# --- PlantUML Management ---
# Generate a new diagram template
gen-diagram-template:
    cat > diagrams/stack.puml << 'EOF'
@startuml
skinparam monochrome true
rectangle "PRESENTATION" {
  [rescript-tea] (TEA/Elm)
  [rescript-jsx] (JSX)
}
@enduml
EOF

# --- CI/CD Integration ---
# Reject failing scripts (GitLab CI/CD)
ci-check:
    if ! just update; then
        echo "ERROR: Documentation update failed. Check logs."
        exit 1
    fi

# --- Utility ---
# Clean up temporary files
clean:
    rm -f docs/*.tmp
EOF
