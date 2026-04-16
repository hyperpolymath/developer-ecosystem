import { defineConfig } from "vite";
import { existsSync } from "node:fs";
import { dirname, basename, join } from "node:path";

// NOTE: assetpackPlugin import removed — it was causing Vite restart loops.
// The import itself made Vite track scripts/ as a config dependency.
// Re-add when needed: import { assetpackPlugin } from "./scripts/assetpack-vite-plugin";

// ReScript emits imports with uncapitalized module names (e.g. "./app/getEngine")
// but the actual files are PascalCase (e.g. "GetEngine.res.mjs"). On case-sensitive
// filesystems (Linux) these don't resolve. This plugin tries the PascalCase variant.
function rescriptResolvePlugin() {
  return {
    name: "vite-plugin-rescript-resolve",
    resolveId(source, importer) {
      if (!importer || !source.startsWith(".")) return null;

      const dir = dirname(importer);
      const base = basename(source);

      // Try adding .res.mjs extension with PascalCase first letter
      const pascalBase = base.charAt(0).toUpperCase() + base.slice(1);
      const candidate = join(dir, dirname(source), pascalBase + ".res.mjs");

      if (existsSync(candidate)) {
        return candidate;
      }
      return null;
    },
  };
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [rescriptResolvePlugin()],
  // NOTE: assetpackPlugin() disabled — was causing Vite to hang on serve.
  // Assets are already built in public/assets/ with manifest at src/manifest.json.
  // Re-enable when raw-assets need reprocessing: assetpackPlugin()
  server: {
    port: 8080,
    open: false,
    watch: {
      // Prevent restart loop: ignore build artifacts and non-source files.
      ignored: [
        "**/scripts/**",
        "**/public/assets/**",
        "**/lib/**",
        "**/main-game/**",
        "**/node_modules/**",
        "**/*.ast",
        "**/*.cmj",
        "**/*.cmi",
        "**/*.cmt",
      ],
    },
  },
  define: {
    APP_VERSION: JSON.stringify(process.env.npm_package_version),
  },
});
