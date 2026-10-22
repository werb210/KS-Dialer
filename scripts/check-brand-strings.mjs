#!/usr/bin/env node
// KEYSTONE_BRAND_CHECK_v1 - KS-Dialer is licensed to many companies, so nothing the user can see may say "Boreal".
// Fails when a Swift string literal, or a user-visible string in an Info.plist / project.yml / AppIntentVocabulary,
// contains "Boreal" (any case: bundle ids, URL schemes and keys too) or a Boreal host, or when Boreal's phone number
// appears anywhere. Comments are not checked: type names and history markers there are internal.
//
// Usage: node scripts/check-brand-strings.mjs        (from the repo root; no dependencies)
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = process.cwd();
const SWIFT_ROOTS = ["Sources", "UI", "Watch", "WatchWidget", "LiveActivity", "CallDirectory", "NotificationService", "Tests"];
const BANNED = /boreal/i;
// Boreal's main number in any common spelling. Built from parts so this file does not contain it.
const PHONE = new RegExp(["587", "888", "1837"].join("[\\s.()-]*"));
const SKIP_DIRS = new Set([".git", "node_modules", "build", "DerivedData", ".build"]);

function walk(dir, out = []) {
  let entries;
  try { entries = readdirSync(dir); } catch { return out; }
  for (const name of entries) {
    if (SKIP_DIRS.has(name)) continue;
    const path = join(dir, name);
    const st = statSync(path);
    if (st.isDirectory()) walk(path, out);
    else out.push(path);
  }
  return out;
}

/** Every string literal in Swift source as { line, text }. Skips line comments and (nested) block comments; understands
 *  "...", multi-line """...""", raw #"..."# strings and \( ) interpolation (whose code may hold more literals). */
export function swiftStringLiterals(src) {
  const found = [];
  let i = 0;
  let line = 1;
  const n = src.length;
  const adv = (k = 1) => { for (let j = 0; j < k && i < n; j++) { if (src[i] === "\n") line++; i++; } };

  function readString() {
    // At a '#'* followed by '"'.
    let hashes = 0;
    while (src[i] === "#") { hashes++; adv(); }
    const multi = src.startsWith('"""', i);
    adv(multi ? 3 : 1);
    const startLine = line;
    let text = "";
    const close = (multi ? '"""' : '"') + "#".repeat(hashes);
    const escape = "\\" + "#".repeat(hashes);
    while (i < n) {
      if (src.startsWith(close, i)) { adv(close.length); break; }
      if (src.startsWith(escape + "(", i)) {
        // Interpolation: code until the matching ')'.
        adv(escape.length + 1);
        let depth = 1;
        while (i < n && depth > 0) {
          const c = src[i];
          if (c === '"' || (c === "#" && /^#+"/.test(src.slice(i, i + 8)))) { readString(); continue; }
          if (c === "(") depth++;
          if (c === ")") depth--;
          if (depth > 0) text += c;
          adv();
        }
        continue;
      }
      if (src.startsWith(escape, i)) { text += src.slice(i, i + escape.length + 1); adv(escape.length + 1); continue; }
      if (!multi && src[i] === "\n") break; // unterminated; stop at end of line
      text += src[i];
      adv();
    }
    found.push({ line: startLine, text });
  }

  while (i < n) {
    if (src.startsWith("//", i)) { while (i < n && src[i] !== "\n") adv(); continue; }
    if (src.startsWith("/*", i)) {
      let depth = 0;
      while (i < n) {
        if (src.startsWith("/*", i)) { depth++; adv(2); continue; }
        if (src.startsWith("*/", i)) { depth--; adv(2); if (depth === 0) break; continue; }
        adv();
      }
      continue;
    }
    if (src[i] === '"' || (src[i] === "#" && /^#+"/.test(src.slice(i, i + 8)))) { readString(); continue; }
    adv();
  }
  return found;
}

// Keys whose values name code (classes, targets, files), not anything a user sees. The Xcode target and Swift type
// names (BorealDialer, BorealWatchWidget, ...) are kept on purpose so the macOS build is not disturbed.
const CODE_KEYS = new Set(["NSExtensionPrincipalClass", "UISceneDelegateClassName", "name", "target", "path",
  "PRODUCT_MODULE_NAME", "excludes", "targets", "product"]);

/** <string> values in a plist (XML), with the key they belong to. */
function plistStrings(src) {
  const out = [];
  const re = /<key>([^<]*)<\/key>|<string>([^<]*)<\/string>/g;
  let key = "";
  let m;
  while ((m = re.exec(src))) {
    if (m[1] !== undefined) { key = m[1]; continue; }
    if (CODE_KEYS.has(key)) continue;
    out.push({ line: src.slice(0, m.index).split("\n").length, text: m[2] });
  }
  return out;
}

/** Scalar values in project.yml (most end up in an Info.plist or entitlements), skipping code-naming keys and the
 *  list items under them. */
function yamlValues(src) {
  const out = [];
  const parents = []; // [{ indent, key }]
  src.split("\n").forEach((raw, idx) => {
    const text = raw.replace(/\s+#.*$/, "");
    if (!text.trim() || text.trim().startsWith("#")) return;
    const indent = text.length - text.trimStart().length;
    while (parents.length && parents[parents.length - 1].indent >= indent) parents.pop();
    const body = text.trim().replace(/^-\s+/, "");
    const kv = /^([A-Za-z0-9_.$()-]+):\s*(.*)$/.exec(body);
    const parentKey = parents.length ? parents[parents.length - 1].key : "";
    if (kv) {
      const [, key, value] = kv;
      if (!value) { parents.push({ indent, key }); return; }
      if (!CODE_KEYS.has(key)) out.push({ line: idx + 1, text: value });
    } else if (text.trim().startsWith("- ") && !CODE_KEYS.has(parentKey)) {
      out.push({ line: idx + 1, text: body });
    }
  });
  return out;
}

const failures = [];
const files = walk(ROOT).map((p) => relative(ROOT, p));

for (const file of files) {
  const top = file.split("/")[0];
  let src;
  try { src = readFileSync(join(ROOT, file), "utf8"); } catch { continue; }
  if (PHONE.test(src)) failures.push(`${file}: contains Boreal's phone number`);

  let strings = [];
  if (file.endsWith(".swift") && SWIFT_ROOTS.includes(top)) strings = swiftStringLiterals(src);
  else if (/(^|\/)Info\.plist$/.test(file) || file.endsWith(".entitlements") || file.endsWith("AppIntentVocabulary.plist")
           || file.endsWith(".xcprivacy")) strings = plistStrings(src);
  else if (file === "project.yml") strings = yamlValues(src);
  else if (file.endsWith(".xcconfig")) strings = src.split("\n").map((t, idx) => ({ line: idx + 1, text: t.replace(/\/\/.*$/, "") }));

  for (const { line, text: literal } of strings) {
    // Tests read project.yml and source files by name, so internal identifiers (BorealDialer, BorealDialerWatch:,
    // Config/BorealDialer.entitlements) may appear in their literals; anything else is still caught.
    const text = top === "Tests" ? literal.replace(/Boreal[A-Z]\w*/g, "") : literal;
    if (BANNED.test(text)) failures.push(`${file}:${line}: "${text.length > 120 ? text.slice(0, 117) + "..." : text}"`);
  }
}

if (failures.length) {
  console.error(`::error::Boreal branding found in ${failures.length} place(s):`);
  for (const f of failures) console.error("  - " + f);
  process.exit(1);
}
console.log("OK: no Boreal branding in Swift string literals, Info.plists, entitlements, project.yml or xcconfig");
