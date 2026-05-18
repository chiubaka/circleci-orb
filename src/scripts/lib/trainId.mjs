#!/usr/bin/env node
/**
 * UTC calendar train id allocator (ADR 0037): YYYY.MM.DD.N from remote tag scan.
 * Shared by GitHub release train, release manifests, and promotion tags.
 */
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

export function utcCalendarDateStr(override) {
  if (override) return override;
  const d = new Date();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}.${m}.${day}`;
}

export function regexEscapeBasic(str) {
  return str.replace(/[][\\.^$*+?(){}|]/g, "\\$&");
}

/**
 * @param {string} lsRemoteText git ls-remote --tags output
 * @param {string} prefix tag prefix before date (e.g. release/ or staging-)
 * @param {string} dateStr YYYY.MM.DD
 * @returns {number} max N for that date, or 0 if none
 */
export function maxNFromLsRemoteForDate(lsRemoteText, prefix, dateStr) {
  const escapedPrefix = regexEscapeBasic(prefix);
  const escapedDate = regexEscapeBasic(dateStr);
  const pattern = new RegExp(`^${escapedPrefix}${escapedDate}\\.[0-9]+$`);
  let maxN = -1;
  for (const line of lsRemoteText.split("\n")) {
    if (!line.trim()) continue;
    const parts = line.trim().split(/\s+/);
    const ref = parts[1];
    if (!ref || !ref.startsWith("refs/tags/")) continue;
    let name = ref.slice("refs/tags/".length);
    if (name.includes("^")) name = name.slice(0, name.indexOf("^"));
    if (!pattern.test(name)) continue;
    const tagSuffix = name.slice(prefix.length);
    const nStr = tagSuffix.split(".").pop();
    const n = Number.parseInt(nStr, 10);
    if (Number.isFinite(n) && n > maxN) maxN = n;
  }
  return maxN < 0 ? 0 : maxN;
}

export function computeNextTrainIdForDate(prefix, dateStr, lsRemoteText) {
  const maxN = maxNFromLsRemoteForDate(lsRemoteText, prefix, dateStr);
  return `${dateStr}.${maxN + 1}`;
}

function gitLsRemoteTags() {
  try {
    return execSync("git ls-remote --tags origin 2>/dev/null || true", {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return "";
  }
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

function usage() {
  process.stderr.write(
    "trainId.mjs: max-n --prefix PREFIX --date DATE [--input FILE]\n" +
      "             next-id --prefix PREFIX [--date DATE] [--utc-date-override DATE]\n",
  );
}

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];
  if (!cmd || cmd === "-h" || cmd === "--help") {
    usage();
    process.exit(cmd ? 0 : 1);
  }

  const getOpt = (name) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };

  if (cmd === "max-n") {
    const prefix = getOpt("--prefix") ?? "";
    const dateStr = getOpt("--date");
    if (!dateStr) {
      process.stderr.write("trainId.mjs max-n: --date is required\n");
      process.exit(1);
    }
    const inputFile = getOpt("--input");
    let text;
    if (inputFile) {
      text = readFileSync(inputFile, "utf8");
    } else if (!process.stdin.isTTY) {
      text = await readStdin();
    } else {
      process.stderr.write("trainId.mjs max-n: provide stdin or --input FILE\n");
      process.exit(1);
    }
    process.stdout.write(String(maxNFromLsRemoteForDate(text, prefix, dateStr)));
    return;
  }

  if (cmd === "next-id") {
    const prefix = getOpt("--prefix") ?? "release/";
    const dateStr =
      getOpt("--date") ??
      utcCalendarDateStr(getOpt("--utc-date-override") ?? process.env.UTC_DATE_OVERRIDE);
    const lsRemote = getOpt("--ls-remote-file");
    const text = lsRemote ? readFileSync(lsRemote, "utf8") : gitLsRemoteTags();
    process.stdout.write(computeNextTrainIdForDate(prefix, dateStr, text));
    return;
  }

  usage();
  process.exit(1);
}

const isCli =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isCli) {
  main().catch((err) => {
    process.stderr.write(`${err?.message ?? err}\n`);
    process.exit(1);
  });
}
