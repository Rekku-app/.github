// Gets this machine ready for this repository: `npm run bootstrap`.
//
// Checks Node (.nvmrc), the GitHub token npm needs for @rekku-app/shared
// (where the repository uses it), installs the dependencies and checks the
// Google Cloud CLI and sign-in (where the repository needs them). Nothing
// needs configuring. It reads gcloud's setup but never changes it; `npm run
// auth` does that. Plain Node with no dependencies, so it runs before
// `npm ci`.
//
// The same file is in every Rekku Node repository, copied from
// Rekku-app/.github (devtools/bootstrap.mjs), and CI fails when a copy
// differs. What differs per repository is in scripts/bootstrap.json:
//   nextSteps       [command, what it does] pairs printed at the end
//   githubPackages  true when npm reads @rekku-app/shared from GitHub Packages
//   googleCloud     true when local development uses the dev project
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const config = JSON.parse(readFileSync(join(import.meta.dirname, "bootstrap.json"), "utf8"));
const NEXT_STEPS = config.nextSteps ?? [];

let todo = 0;
let blocking = 0;
const ok = (what) => console.log(`  ok      ${what}`);
const later = (what, fix, required = false) => {
  todo++;
  if (required) blocking++;
  console.log(`  todo    ${what}\n          ${fix}`);
};
const section = (name) => console.log(`\n${name}`);

/** Runs a command; on Windows through the shell, where npm and gcloud are .cmd files. */
function run(command, args, { quiet = false, env = process.env } = {}) {
  const opts = { cwd: root, stdio: quiet ? "pipe" : "inherit", encoding: "utf8", env };
  if (process.platform !== "win32") return spawnSync(command, args, opts);
  const line = [command, ...args.map((a) => (/[\s"]/.test(a) ? `"${a}"` : a))].join(" ");
  return spawnSync(line, { ...opts, shell: true });
}

console.log(`Getting this machine ready for ${JSON.parse(readFileSync(join(root, "package.json"), "utf8")).name}`);

section("Node");
const wanted = existsSync(join(root, ".nvmrc")) ? readFileSync(join(root, ".nvmrc"), "utf8").trim() : "";
const major = Number(process.versions.node.split(".")[0]);
if (wanted && major < Number(wanted)) {
  later(
    `Node ${process.versions.node} (this repository uses ${wanted}, as CI does)`,
    `install Node ${wanted}: https://nodejs.org/ (or nvm install / fnm use, which read .nvmrc)`,
  );
} else {
  ok(`Node ${process.versions.node}`);
}

const installEnv = { ...process.env };
if (config.githubPackages) {
  section("GitHub Packages");
  // @rekku-app/shared (the code shared between the Rekku apps) is private to
  // the Rekku-app organization, on GitHub Packages. npm reads it with the
  // GitHub token in NODE_AUTH_TOKEN (.npmrc). Without one, this install
  // borrows the GitHub CLI's token, once. The token is never printed or
  // written. For every day, a token that can do nothing but read packages:
  // the GitHub CLI's can push code and run workflows, so it doesn't belong
  // in a shell profile. GitHub Packages' npm registry takes only classic
  // tokens, not fine-grained ones.
  const SET_TOKEN =
    "make a classic token with only read:packages and an expiry\n" +
    "          (https://github.com/settings/tokens/new?scopes=read:packages&description=rekku-packages),\n" +
    "          save it in ~/.config/rekku/packages-token (chmod 600), and in your shell profile:\n" +
    '          export NODE_AUTH_TOKEN="$(cat ~/.config/rekku/packages-token)"\n' +
    "          (PowerShell, in $PROFILE: $env:NODE_AUTH_TOKEN = Get-Content ~/.config/rekku/packages-token)";
  const SCOPE = "gh auth refresh -h github.com -s read:packages";
  const NEED = "NODE_AUTH_TOKEN (npm needs a GitHub token that may read packages for @rekku-app/shared)";
  if (process.env.NODE_AUTH_TOKEN) {
    ok("NODE_AUTH_TOKEN set (npm reads @rekku-app/shared with it)");
  } else if (run("gh", ["--version"], { quiet: true }).status !== 0) {
    later(
      NEED,
      `install the GitHub CLI (https://cli.github.com), gh auth login, ${SCOPE}\n          then, ${SET_TOKEN}`,
      true,
    );
  } else {
    const status = run("gh", ["auth", "status", "-h", "github.com"], { quiet: true });
    const scopes = `${status.stdout ?? ""}${status.stderr ?? ""}`;
    const token = status.status === 0 ? (run("gh", ["auth", "token"], { quiet: true }).stdout ?? "").trim() : "";
    if (!token) {
      later(NEED, `gh auth login, ${SCOPE}\n          then, ${SET_TOKEN}`, true);
    } else if (!/read:packages|write:packages/.test(scopes)) {
      later(
        "the GitHub CLI's token can't read packages (npm needs that for @rekku-app/shared)",
        `once: ${SCOPE}\n          then, ${SET_TOKEN}`,
        true,
      );
    } else {
      installEnv.NODE_AUTH_TOKEN = token;
      later(
        "NODE_AUTH_TOKEN isn't set: this install used the GitHub CLI's token",
        `for later installs, set it ${SET_TOKEN}`,
      );
    }
  }
}

section("Dependencies");
const lock = existsSync(join(root, "package-lock.json"));
const install = run("npm", [lock ? "ci" : "install", "--no-audit", "--no-fund"], { env: installEnv });
if (install.status === 0) ok(`npm ${lock ? "ci" : "install"}`);
else
  later(
    "dependencies",
    (config.githubPackages
      ? "npm ci failed (above). A 401 or 403 for @rekku-app/shared: the token can't read packages (GitHub Packages, above).\n" +
        "          Otherwise close"
      : "npm ci failed (above). Close") + " what holds node_modules open (editor, dev server) and rerun",
    true,
  );

if (config.googleCloud) {
  section("Local settings");
  // Nothing to set: the defaults are the dev project's, and secrets come from
  // Secret Manager. .env.local only overrides a default (see .env.example).
  ok(existsSync(join(root, ".env.local")) ? ".env.local overrides some defaults" : "defaults (no .env.local needed)");

  section("Google Cloud");
  if (run("gcloud", ["--version"], { quiet: true }).status === 0) ok("gcloud installed");
  else later("gcloud", "install the Google Cloud CLI: https://cloud.google.com/sdk/docs/install");
  const adcDir =
    process.env.CLOUDSDK_CONFIG ||
    (process.platform === "win32" ? join(process.env.APPDATA ?? "", "gcloud") : join(homedir(), ".config", "gcloud"));
  const adc = process.env.GOOGLE_APPLICATION_CREDENTIALS || join(adcDir, "application_default_credentials.json");
  if (existsSync(adc)) ok("Application Default Credentials present");
  else later("Google Cloud sign-in", "run: npm run auth");
}

console.log(todo === 0 ? "\nReady. Next:" : `\n${todo} thing(s) to do above. Then:`);
for (const [command, what] of NEXT_STEPS) console.log(`  ${command.padEnd(22)} ${what}`);
process.exit(blocking > 0 ? 1 : 0);
