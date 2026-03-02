// Startup time benchmark
// Measures time to start server and handle first request

import { blue, green, yellow } from "https://deno.land/std@0.210.0/fmt/colors.ts";

interface BenchmarkResult {
  runtime: string;
  coldStart: number;
  firstRequest: number;
  total: number;
}

async function measureStartup(command: string[], runtime: string): Promise<BenchmarkResult> {
  console.log(`\nBenchmarking ${runtime}...`);

  const startTime = performance.now();

  // Start the server process
  const process = new Deno.Command(command[0], {
    args: command.slice(1),
    stdout: "null",
    stderr: "null",
  }).spawn();

  // Wait for server to be ready (try to connect)
  let connected = false;
  let attempts = 0;
  const maxAttempts = 50;

  while (!connected && attempts < maxAttempts) {
    try {
      const response = await fetch("http://localhost:8000/", {
        signal: AbortSignal.timeout(100),
      });
      if (response.ok) {
        connected = true;
      }
    } catch {
      // Server not ready yet
      await new Promise(resolve => setTimeout(resolve, 50));
      attempts++;
    }
  }

  const coldStart = performance.now() - startTime;

  // Make first request
  const requestStart = performance.now();
  await fetch("http://localhost:8000/");
  const firstRequest = performance.now() - requestStart;

  const total = performance.now() - startTime;

  // Cleanup
  process.kill("SIGTERM");
  await process.status;

  return {
    runtime,
    coldStart,
    firstRequest,
    total,
  };
}

async function runBenchmarks() {
  console.log(blue("=".repeat(60)));
  console.log(blue("Startup Time Benchmark"));
  console.log(blue("=".repeat(60)));

  const results: BenchmarkResult[] = [];

  // Benchmark ReScript + Deno
  try {
    const denoResult = await measureStartup(
      ["deno", "run", "--allow-net", "examples/hello-world/main.mjs"],
      "ReScript + Deno"
    );
    results.push(denoResult);
  } catch (error) {
    console.error("Failed to benchmark ReScript + Deno:", error);
  }

  // Compare with Node.js (if available)
  try {
    const nodeResult = await measureStartup(
      ["node", "benchmark/node-server.js"],
      "Node.js + Express"
    );
    results.push(nodeResult);
  } catch {
    console.log(yellow("Node.js not available for comparison"));
  }

  // Display results
  console.log("\n" + green("Results:"));
  console.log(green("=".repeat(60)));

  const headers = ["Runtime", "Cold Start", "First Request", "Total"];
  const rows = results.map(r => [
    r.runtime,
    `${r.coldStart.toFixed(2)}ms`,
    `${r.firstRequest.toFixed(2)}ms`,
    `${r.total.toFixed(2)}ms`,
  ]);

  // Simple table formatting
  console.table([
    ...rows,
  ]);

  // Calculate improvements
  if (results.length > 1) {
    const baseline = results[1]; // Node.js
    const optimized = results[0]; // ReScript

    const improvement = ((baseline.total - optimized.total) / baseline.total * 100);
    console.log(`\n${green("Speed improvement:")} ${improvement.toFixed(1)}% faster startup`);
  }

  // Save results
  await Deno.mkdir("benchmark-results", { recursive: true });
  await Deno.writeTextFile(
    "benchmark-results/startup.json",
    JSON.stringify(results, null, 2)
  );

  console.log("\n✓ Results saved to benchmark-results/startup.json");
}

if (import.meta.main) {
  await runBenchmarks();
}
