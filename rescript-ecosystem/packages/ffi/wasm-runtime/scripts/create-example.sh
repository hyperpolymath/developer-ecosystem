#!/usr/bin/env bash
# Create a new example application

set -euo pipefail

# Check if name provided
if [ $# -eq 0 ]; then
  echo "Usage: ./scripts/create-example.sh <example-name>"
  echo "Example: ./scripts/create-example.sh my-api"
  exit 1
fi

NAME=$1
DIR="examples/${NAME}"

# Create directory
if [ -d "$DIR" ]; then
  echo "Error: Example '${NAME}' already exists"
  exit 1
fi

mkdir -p "$DIR"

# Create main.res
cat > "${DIR}/main.res" << 'EOF'
// {{NAME}} example
// Run with: just dev-{{NAME}}

let handler = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)

  switch path {
  | "/" => {
      Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("message", Js.Json.string("{{NAME}} example")),
          ("timestamp", Js.Json.number(Deno.now()))
        ])),
        ()
      )
    }
  | _ => Deno.Response.text("Not Found", ~status=404, ())
  }
}

Server.simple(~port=8000, handler)
EOF

# Replace placeholders
sed -i "s/{{NAME}}/${NAME}/g" "${DIR}/main.res"

# Create README
cat > "${DIR}/README.md" << EOF
# ${NAME} Example

Description of this example.

## Running

\`\`\`bash
# Build
just build

# Run
deno run --allow-net examples/${NAME}/main.mjs
\`\`\`

## Features

- Feature 1
- Feature 2
- Feature 3

## API Endpoints

- \`GET /\` - Description

## Testing

\`\`\`bash
curl http://localhost:8000/
\`\`\`
EOF

echo "✅ Created new example: ${NAME}"
echo ""
echo "Next steps:"
echo "  1. Edit examples/${NAME}/main.res"
echo "  2. Build: just build"
echo "  3. Run: deno run --allow-net examples/${NAME}/main.mjs"
echo ""
echo "Add to justfile:"
echo "  dev-${NAME}:"
echo "    just build"
echo "    deno run --allow-net examples/${NAME}/main.mjs"
