// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath
//
// Deno Fresh Well-Known Middleware
// Add this to your Fresh project's routes/_middleware.ts

import { FreshContext } from "$fresh/server.ts";

// Well-known resource configuration
const WELL_KNOWN_CONFIG = {
  // Security contact (RFC 9116) - REQUIRED: Update these values
  security: {
    contact: ["mailto:security@example.com"],
    expires: "2026-12-31T23:59:59Z",
    encryption: "https://example.com/.well-known/pgp-key.txt",
    acknowledgments: "https://example.com/security/thanks",
    preferredLanguages: ["en"],
    canonical: "https://example.com/.well-known/security.txt",
    policy: "https://example.com/security/policy",
    hiring: "https://example.com/careers/security",
  },

  // AI policy disclosure (RSR)
  ai: {
    policy: "https://example.com/ai-policy",
    trainingOptOut: true,
    contact: "mailto:ai@example.com",
  },

  // Site metadata
  site: {
    domain: "example.com",
    team: [
      { name: "Your Name", role: "Developer", location: "Earth" },
    ],
  },
};

// Generate security.txt content
function generateSecurityTxt(): string {
  const { security } = WELL_KNOWN_CONFIG;
  const lines: string[] = [];

  for (const contact of security.contact) {
    lines.push(`Contact: ${contact}`);
  }
  lines.push(`Expires: ${security.expires}`);

  if (security.encryption) {
    lines.push(`Encryption: ${security.encryption}`);
  }
  if (security.acknowledgments) {
    lines.push(`Acknowledgments: ${security.acknowledgments}`);
  }
  if (security.preferredLanguages?.length) {
    lines.push(`Preferred-Languages: ${security.preferredLanguages.join(", ")}`);
  }
  if (security.canonical) {
    lines.push(`Canonical: ${security.canonical}`);
  }
  if (security.policy) {
    lines.push(`Policy: ${security.policy}`);
  }
  if (security.hiring) {
    lines.push(`Hiring: ${security.hiring}`);
  }

  return lines.join("\n") + "\n";
}

// Generate ai.txt content
function generateAiTxt(): string {
  const { ai } = WELL_KNOWN_CONFIG;
  const lines: string[] = [];

  if (ai.policy) {
    lines.push(`AI-Policy: ${ai.policy}`);
  }
  if (ai.trainingOptOut !== undefined) {
    lines.push(`Training-Opt-Out: ${ai.trainingOptOut}`);
  }
  if (ai.contact) {
    lines.push(`Contact: ${ai.contact}`);
  }

  return lines.join("\n") + "\n";
}

// Generate humans.txt content
function generateHumansTxt(): string {
  const { site } = WELL_KNOWN_CONFIG;
  const lines: string[] = ["/* TEAM */"];

  for (const member of site.team) {
    lines.push(`Name: ${member.name}`);
    lines.push(`Role: ${member.role}`);
    if (member.location) {
      lines.push(`Location: ${member.location}`);
    }
    lines.push("");
  }

  lines.push("/* SITE */");
  lines.push(`Last update: ${new Date().toISOString().split("T")[0]}`);
  lines.push("Standards: RFC 8615, RFC 9116");

  return lines.join("\n") + "\n";
}

// Well-known routes handler
export async function handler(req: Request, ctx: FreshContext) {
  const url = new URL(req.url);
  const path = url.pathname;

  // Handle .well-known routes
  if (path.startsWith("/.well-known/")) {
    const resource = path.replace("/.well-known/", "");

    switch (resource) {
      case "security.txt":
        return new Response(generateSecurityTxt(), {
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });

      case "ai.txt":
        return new Response(generateAiTxt(), {
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });

      case "humans.txt":
        return new Response(generateHumansTxt(), {
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });

      default:
        // Fall through to static files or 404
        break;
    }
  }

  return ctx.next();
}
