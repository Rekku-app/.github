# Rekku organization rules

This is the canonical text of the section every Rekku repository's
`CLAUDE.md` carries between the `org-rules:start` and `org-rules:end`
markers. Change it here first, then copy it into each repository with
`scripts/org-files.sh sync <repository>` (README). Each repository's CI
(`org-files`, the reusable workflow `.github/workflows/org-files.yml`) fails
while its copy differs from this one.

<!-- org-rules:start -->
## The system

Rekku is a study app for school students aged 13 and older in the EU. It is
eight repositories in the `Rekku-app` GitHub organization, deployed to Google
Cloud (Cloud Run, `europe-west1`): dev is project `rekku-509915`, production
is `rekku-prod`.

| Repository | What it is | Runs as |
|---|---|---|
| rekku-api | Go API: all data and rules, the AI (Vertex AI), the job worker and the staff API. Owns the API contracts | Cloud Run `rekku-api`, `rekku-api-worker`, `rekku-api-admin` (internal only) |
| rekku-web | Next.js web app with sign-up and log-in, and the public `/api` gateway every client calls | Cloud Run `rekku-web` (app.rekku.net) |
| rekku-mobile | Expo / React Native app for iOS and Android | EAS builds |
| rekku-shared | TypeScript package `@rekku-app/shared`: the API client and hooks, study logic and strings the web app and the mobile app share | GitHub Packages (private) |
| rekku-admin | Next.js staff panel | Cloud Run `rekku-admin` behind IAP (admin.rekku.net) |
| rekku-landing | Next.js public site and its CMS | Cloud Run `rekku-landing` (rekku.net) |
| rekku-infra | Terraform: the Google Cloud resources of every service | — |
| rekku-loadtest | k6 load tests of dev: mobile, web and real-browser users, started with `/load-test` on a pull request | Cloud Run jobs `rekku-loadtest`, `rekku-loadtest-seed` (dev only) |

The organization's `.github` repository (public) holds these rules
(`ORG_RULES.md`), the pull request template, the files that are the same
in every repository and the reusable workflow that checks them.

Clients call rekku-web's `/api`, which forwards to rekku-api over a private
network; rekku-admin calls rekku-api-admin. People sign up and log in on
the web app (app.rekku.net/login), for the web app and for the mobile app. The map, who may call whom,
and the limits: [rekku-api `docs/INFRASTRUCTURE.md`](https://github.com/Rekku-app/rekku-api/blob/main/docs/INFRASTRUCTURE.md).

Local ports, the same everywhere: rekku-landing 3000, rekku-web 3001,
rekku-admin 3002, rekku-api 8080, its admin API 8090.

## Rules (the same in every Rekku repository)

This section is a copy of `ORG_RULES.md` in
[Rekku-app/.github](https://github.com/Rekku-app/.github). Change it there,
then copy it here with `scripts/org-files.sh sync <this repository>` from a
checkout of Rekku-app/.github; CI (`org-files`) fails while they differ.

### Changes
- Branch from `main`, one topic per branch. Commits and pull request titles
  follow Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `ci:`,
  `test:`, `refactor:`, `build:`, with an optional scope (`fix(auth): …`).
  CI checks the pull request title and its commits.
- `main` and `prod` change only through pull requests: 1 approving review,
  and the CI checks must pass. No direct pushes, force pushes or branch
  deletion, for admins too. Fill in the pull request template.
- Changes to `.github/`, Dockerfiles, the API contracts (`api/*.yaml`) and
  everything in rekku-infra need a code owner's review (`CODEOWNERS`).
- Keep a branch current by rebasing it on `main`, not by merging `main`
  into it. Merged branches are deleted.
- Run this repository's checks (Commands) before you push; CI runs the same
  ones. Lint fails on warnings, locally too.
- Update the docs (README, this file, `docs/`) in the same pull request as
  the change they describe.
- Bugs and follow-ups go in GitHub issues of the repository they concern.

### CI and dependencies
- Workflows pin every action and reusable workflow to a full commit SHA,
  with its version in a comment (`uses: actions/checkout@<sha> # v7.0.1`).
  Docker base images and Cloud Build builder images are pinned by
  `sha256` digest. Dependabot updates both, with the same rules in every
  repository. One exception: the `/load-test` callers use rekku-loadtest's
  `run.yml@main`, because Google Cloud trusts only its workflows on main
  (rekku-infra, bootstrap); main there is protected and code-owned.
- Only GitHub-owned and verified actions run. Other tools are installed from
  their release, pinned by checksum (gitleaks, k6, tflint, trivy).
- Install with `npm ci --ignore-scripts` (CI, Docker): dependencies' install
  scripts don't run, least of all where a token is present.
- CI builds the Docker image (without pushing it) and scans dependencies
  (npm audit, govulncheck), the code (CodeQL) and Terraform (tflint, trivy).

### Deployment
- Merging into `main` deploys to dev (`rekku-509915`) through Cloud Build.
  rekku-mobile deploys nothing on merge; its builds are made with EAS.
  rekku-shared deploys nothing either: a version tag publishes the package,
  and the apps take it in by bumping it.
  rekku-loadtest deploys nothing: merging publishes its scripts to the
  load-test jobs' bucket.
- A release is a pull request from `main` into `prod`, merged with a merge
  commit, once Cloud Build has passed on `main` for that commit. Merging it
  deploys to production (`rekku-prod`).
- Every Google Cloud resource and setting (service accounts, roles,
  databases, Cloud Run variables, ingress, IAP, triggers) belongs to
  rekku-infra's Terraform. Don't change them in the console; the next apply
  puts them back. Change rekku-infra instead.
- Changes across repositories ship in order: rekku-infra and rekku-api first,
  backwards compatible, then rekku-web's gateway, rekku-shared and the apps,
  with new screens behind a feature flag; removals go the other way round.
- How every kind of change gets to users (a feature across repositories,
  contract changes, releasing the services, the package and the mobile
  app, hotfixes): [rekku-api `docs/WORKFLOWS.md`](https://github.com/Rekku-app/rekku-api/blob/main/docs/WORKFLOWS.md).

### API contract
- rekku-api's `api/openapi.yaml` (and `api/admin-openapi.yaml` for the staff
  API) is the contract. Change it in rekku-api first; then run
  `npm run api:sync` where it is vendored (rekku-shared for the apps'
  client, released and bumped in both apps; rekku-web for its gateway;
  rekku-admin for the staff API) and commit the vendored spec with the
  regenerated types. Prefer additive changes: removing or renaming a field
  needs every client updated first.

### Secrets and configuration
- Secrets live in Secret Manager only: never in code, commits, committed
  `.env` files or plain Cloud Run variables. CI scans every change with
  gitleaks (the same `.gitleaks.toml` everywhere).
- Identity Platform web API keys and project IDs are public client
  configuration and may be committed.
- Local-only shortcuts (dev uid, dev staff email, emulators, the fake model)
  are refused on Cloud Run. Keep those checks.

### Users and data
- Treat everything students upload or type as personal data. Never log
  tokens, emails or uploaded content.
- rekku-api stores no names. Students' email addresses live in Identity
  Platform, not in rekku-api's database, which keeps email addresses only
  here: a GDPR request record keeps the requester's email (when given) and
  the emails of the staff who created and closed it, for 3 years after it
  closes; a guardian's email is kept only until the consent is granted,
  declined or expires, then replaced by a keyed hash; and staff members'
  emails are kept on what they did: audit log entries (2 years), case
  replies (2 years after the case closes), approvals, and the switches,
  flags and announcements they changed. A staff search by email is
  recorded in the audit log as a keyed hash (HMAC-SHA256), never as the
  email.
- Deleting an account or an exam purges it (the daily purge job).
- New personal data, a new use of it or a new processor (a service that
  receives it) needs the privacy policy (rekku-landing) and the record of
  processing updated in the same change. The pull request template asks.
<!-- org-rules:end -->
