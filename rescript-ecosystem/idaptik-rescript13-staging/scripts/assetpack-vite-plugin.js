// SPDX-License-Identifier: PMPL-1.0-or-later
// Custom AssetPack Vite plugin — uses individual pipes instead of pixiPipes
// to avoid importing @napi-rs/woff-build (native addon incompatible with Deno).
// No font files exist in raw-assets/, so the webfont pipe is unnecessary.
import { AssetPack } from "@assetpack/core";

export function assetpackPlugin() {
  // Lazy-load pipes to avoid top-level import of webfont/woff-build
  let pipesPromise;
  async function loadPipes() {
    if (pipesPromise) return pipesPromise;
    pipesPromise = (async () => {
      const [
        { audio },
        { texturePacker },
        { mipmap },
        { compress },
        { json },
        { pixiManifest },
        { spineAtlasMipmap },
        { spineAtlasCompress },
        { spineAtlasManifestMod },
        { texturePackerCompress },
        { texturePackerManifestMod },
      ] = await Promise.all([
        import("@assetpack/core/ffmpeg"),
        import("@assetpack/core/texture-packer"),
        import("@assetpack/core/image"),
        import("@assetpack/core/image"),
        import("@assetpack/core/json"),
        import("@assetpack/core/manifest"),
        import("@assetpack/core/spine"),
        import("@assetpack/core/spine"),
        import("@assetpack/core/spine"),
        import("@assetpack/core/texture-packer"),
        import("@assetpack/core/texture-packer"),
      ]);

      const resolutions = { default: 1, low: 0.5 };
      return [
        audio({}),
        texturePacker({
          texturePacker: { nameStyle: "short" },
          resolutionOptions: { resolutions },
        }),
        mipmap({ resolutions }),
        spineAtlasMipmap({ resolutions }),
        compress({ png: true, jpg: true, webp: true }),
        spineAtlasCompress({ png: true, jpg: true, webp: true }),
        texturePackerCompress({ png: true, jpg: true, webp: true }),
        json(),
        pixiManifest({
          createShortcuts: true,
          output: "./src/manifest.json",
        }),
        spineAtlasManifestMod({
          createShortcuts: true,
          output: "./src/manifest.json",
        }),
        texturePackerManifestMod({
          createShortcuts: true,
          output: "./src/manifest.json",
        }),
      ];
    })();
    return pipesPromise;
  }

  let mode;
  let ap;

  return {
    name: "vite-plugin-assetpack",
    configResolved(resolvedConfig) {
      mode = resolvedConfig.command;
    },
    buildStart: async () => {
      const pipes = await loadPipes();
      const apConfig = {
        entry: "./raw-assets",
        output: "./public/assets/",
        pipes,
      };

      if (mode === "serve") {
        if (ap) return;
        ap = new AssetPack(apConfig);
        await ap.watch();
      } else {
        await new AssetPack(apConfig).run();
      }
    },
    buildEnd: async () => {
      if (ap) {
        await ap.stop();
        ap = undefined;
      }
    },
  };
}
