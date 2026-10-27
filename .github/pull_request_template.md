## What and why

<!-- What this changes, and why. Link the issue it closes: "Closes #12".
Part of a change across repositories? Link its rekku-api tracking issue and
the other pull requests (rekku-api docs/ROLLOUT.md). -->

## How it was checked

<!-- The commands you ran (this repository's checks, the same as CI) and
what you tried by hand: screens, endpoints, environments. -->

## Checklist

- [ ] Title and commits follow Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `test:`, `refactor:`, `build:`)
- [ ] This repository's checks pass locally (see CLAUDE.md, "Commands")
- [ ] Docs (README, CLAUDE.md, docs/) updated in this pull request where behavior changed
- [ ] API contract: changed in rekku-api first; clients synced with `npm run api:sync` (or not affected)
- [ ] No secrets, tokens or personal data in code, commits or logs
- [ ] Personal data: new personal data, a new use of it or a new processor (a service that receives it) comes with a privacy policy update (rekku-landing) and the record of processing (or none is added)
- [ ] Deployment: nothing needs doing by hand, or it's described above; Google Cloud changes are in rekku-infra

<!-- repo-specific:start -->
<!-- repo-specific:end -->
