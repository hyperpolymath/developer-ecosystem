// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath
//
// Deno Fresh Well-Known Plugin
// Add this plugin to your Fresh project's main.ts

import { Plugin } from "$fresh/server.ts";

export interface WellKnownConfig {
  security: {
    contact: string[];
    expires: string;
    encryption?: string;
    acknowledgments?: string;
    preferredLanguages?: string[];
    canonical?: string;
    policy?: string;
    hiring?: string;
  };
  ai?: {
    policy?: string;
    trainingOptOut?: boolean;
    contact?: string;
  };
  humans?: {
    team: Array<{ name: string; role: string; location?: string }>;
    thanks?: Array<{ name: string; role?: string }>;
  };
}

function generateSecurityTxt(config: WellKnownConfig["security"]): string {
  const lines: string[] = [];

  for (const contact of config.contact) {
    lines.push(`Contact: ${contact}`);
  }
  lines.push(`Expires: ${config.expires}`);

  if (config.encryption) lines.push(`Encryption: ${config.encryption}`);
  if (config.acknowledgments) lines.push(`Acknowledgments: ${config.acknowledgments}`);
  if (config.preferredLanguages?.length) {
    lines.push(`Preferred-Languages: ${config.preferredLanguages.join(", ")}`);
  }
  if (config.canonical) lines.push(`Canonical: ${config.canonical}`);
  if (config.policy) lines.push(`Policy: ${config.policy}`);
  if (config.hiring) lines.push(`Hiring: ${config.hiring}`);

  return lines.join("\n") + "\n";
}

function generateAiTxt(config: NonNullable<WellKnownConfig["ai"]>): string {
  const lines: string[] = [];
  if (config.policy) lines.push(`AI-Policy: ${config.policy}`);
  if (config.trainingOptOut !== undefined) {
    lines.push(`Training-Opt-Out: ${config.trainingOptOut}`);
  }
  if (config.contact) lines.push(`Contact: ${config.contact}`);
  return lines.join("\n") + "\n";
}

function generateHumansTxt(config: NonNullable<WellKnownConfig["humans"]>): string {
  const lines: string[] = ["/* TEAM */"];

  for (const member of config.team) {
    lines.push(`Name: ${member.name}`);
    lines.push(`Role: ${member.role}`);
    if (member.location) lines.push(`Location: ${member.location}`);
    lines.push("");
  }

  if (config.thanks?.length) {
    lines.push("/* THANKS */");
    for (const t of config.thanks) {
      lines.push(`Name: ${t.name}`);
      if (t.role) lines.push(`Role: ${t.role}`);
      lines.push("");
    }
  }

  lines.push("/* SITE */");
  lines.push(`Last update: ${new Date().toISOString().split("T")[0]}`);
  lines.push("Standards: RFC 8615, RFC 9116");

  return lines.join("\n") + "\n";
}

export function wellKnownPlugin(config: WellKnownConfig): Plugin {
  return {
    name: "well-known",
    routes: [
      {
        path: "/.well-known/security.txt",
        handler: () =>
          new Response(generateSecurityTxt(config.security), {
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          }),
      },
      ...(config.ai
        ? [
            {
              path: "/.well-known/ai.txt",
              handler: () =>
                new Response(generateAiTxt(config.ai!), {
                  headers: { "Content-Type": "text/plain; charset=utf-8" },
                }),
            },
          ]
        : []),
      ...(config.humans
        ? [
            {
              path: "/.well-known/humans.txt",
              handler: () =>
                new Response(generateHumansTxt(config.humans!), {
                  headers: { "Content-Type": "text/plain; charset=utf-8" },
                }),
            },
          ]
        : []),
    ],
  };
}

// Example usage in main.ts:
// import { wellKnownPlugin } from "./well_known_plugin.ts";
//
// await start(manifest, {
//   plugins: [
//     wellKnownPlugin({
//       security: {
//         contact: ["mailto:security@example.com"],
//         expires: "2026-12-31T23:59:59Z",
//       },
//       ai: {
//         trainingOptOut: true,
//       },
//     }),
//   ],
// });
