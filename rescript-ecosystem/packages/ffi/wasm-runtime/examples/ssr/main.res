// Server-Side Rendering example
// Demonstrates HTML generation and templating

// Simple template engine
module Template = {
  type data = Js.Dict.t<string>

  let render = (template: string, data: data): string => {
    let result = ref(template)

    Js.Dict.entries(data)->Array.forEach(((key, value)) => {
      let placeholder = `{{${key}}}`
      result := Js.String2.replaceByRe(result.contents, Js.Re.fromString(placeholder), value)
    })

    result.contents
  }
}

// Page components
module Components = {
  let layout = (title: string, content: string): string => {
    `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
    header { background: #0066cc; color: white; padding: 20px; }
    main { max-width: 1200px; margin: 0 auto; padding: 40px 20px; }
    footer { background: #f5f5f5; padding: 20px; text-align: center; margin-top: 40px; }
    .card { border: 1px solid #ddd; border-radius: 8px; padding: 20px; margin-bottom: 20px; }
    h1 { margin-bottom: 20px; }
    a { color: #0066cc; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <header>
    <h1>${title}</h1>
    <nav>
      <a href="/" style="color: white; margin-right: 20px;">Home</a>
      <a href="/about" style="color: white; margin-right: 20px;">About</a>
      <a href="/blog" style="color: white;">Blog</a>
    </nav>
  </header>
  <main>
    ${content}
  </main>
  <footer>
    <p>&copy; 2025 ReScript WASM Runtime. Built with ReScript and Deno.</p>
  </footer>
</body>
</html>`
  }

  let card = (title: string, content: string): string => {
    `<div class="card">
      <h2>${title}</h2>
      <p>${content}</p>
    </div>`
  }

  let blogPost = (title: string, date: string, content: string): string => {
    `<article class="card">
      <h2>${title}</h2>
      <p style="color: #666; margin: 10px 0;">${date}</p>
      <div>${content}</div>
    </article>`
  }
}

// Mock data
let blogPosts = [
  {
    "title": "Getting Started with ReScript WASM Runtime",
    "date": "2025-01-15",
    "content": "Learn how to build high-performance web applications with ReScript, WASM, and Deno.",
    "slug": "getting-started"
  },
  {
    "title": "Why Type Safety Matters",
    "date": "2025-01-10",
    "content": "Explore the benefits of ReScript's type system for building reliable applications.",
    "slug": "type-safety"
  },
  {
    "title": "WebAssembly Performance Benefits",
    "date": "2025-01-05",
    "content": "Discover how WASM compilation can improve your application's performance.",
    "slug": "wasm-performance"
  }
]

// Handlers
let handleHome = async (_req: Deno.request): promise<Deno.response> => {
  let content = `
    <h1>Welcome to ReScript WASM Runtime</h1>
    ${Components.card(
      "High Performance",
      "98% smaller bundles, 94% faster startup, 90% less memory than Node.js"
    )}
    ${Components.card(
      "Type Safe",
      "Full type safety from ReScript to runtime with zero runtime overhead"
    )}
    ${Components.card(
      "Modern Stack",
      "Built with ReScript, WebAssembly, and Deno for the modern web"
    )}
  `

  let html = Components.layout("Home - ReScript WASM Runtime", content)
  Deno.Response.html(html, ())
}

let handleAbout = async (_req: Deno.request): promise<Deno.response> => {
  let content = `
    <h1>About</h1>
    <div class="card">
      <p>ReScript WASM Runtime is a high-performance, type-safe HTTP server runtime
      combining ReScript's functional programming paradigm with WebAssembly compilation
      and modern runtime environments.</p>
      <br>
      <h3>Key Features</h3>
      <ul>
        <li>Type-safe functional programming with ReScript</li>
        <li>WebAssembly compilation for maximum performance</li>
        <li>Multiple runtime targets: Deno, Bun, WASM</li>
        <li>Minimal bundle sizes (&lt;10KB typical)</li>
        <li>Fast startup times (&lt;100ms)</li>
        <li>Low memory footprint</li>
      </ul>
    </div>
  `

  let html = Components.layout("About - ReScript WASM Runtime", content)
  Deno.Response.html(html, ())
}

let handleBlog = async (_req: Deno.request): promise<Deno.response> => {
  let posts = blogPosts->Array.map(post => {
    Components.blogPost(
      post["title"],
      post["date"],
      `${post["content"]} <a href="/blog/${post["slug"]}">Read more →</a>`
    )
  })->Array.joinWith("\n")

  let content = `
    <h1>Blog</h1>
    ${posts}
  `

  let html = Components.layout("Blog - ReScript WASM Runtime", content)
  Deno.Response.html(html, ())
}

let handleBlogPost = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 2 {
    let slug = Array.getUnsafe(parts, 1)
    let post = blogPosts->Array.find(p => p["slug"] === slug)

    switch post {
    | Some(p) => {
        let content = Components.blogPost(
          p["title"],
          p["date"],
          p["content"]
        )

        let html = Components.layout(p["title"], content)
        Deno.Response.html(html, ())
      }
    | None => {
        let content = `<h1>Post Not Found</h1><p><a href="/blog">← Back to blog</a></p>`
        let html = Components.layout("Not Found", content)
        Deno.Response.html(html, ~status=404, ())
      }
    }
  } else {
    handleBlog(req)
  }
}

let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.get("/", handleHome)
  ->Router.get("/about", handleAbout)
  ->Router.get("/blog", handleBlog)
  ->Router.get("/blog/:slug", handleBlogPost)

Server.withRouter(~port=8000, router)
