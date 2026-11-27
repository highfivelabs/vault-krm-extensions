# Rules for every change

**CI runs on every pull request; run it locally first.** The `ci` check
(`.github/workflows/hfl-ci.yml`, which calls highfivelabs/krm-ci) must pass
before a merge. Its hermetic check is `hack/ci.sh`, so run that before you
push: a local pass means the same checks. Add new checks to `hack/ci.sh`;
the `hfl-*.yml` workflows and `.github/dependabot.yml` are rendered by
krm-ci (`task krm:sync` there), so don't edit them here.

Claude reviews each pull request (`hfl/security-review`, and an advisory
first pass in one comment): members' on push, anyone else's once a
maintainer comments `/review`. Live tests against the real account run only
after a maintainer's `/ok-to-test-live sha=<head>`, a passing review of that
commit, and the `live` environment's approval.

<!-- HFL-WORKSPACE: BEGIN (generated from highfivelabs/workspace sync/blocks/public-krm.md by bin/sync-agents; edit it there) -->
## High Five Labs team members

**Outside contributors:** this section isn't for you. Nothing in it is
required of you, and the repository it links to is private. The rules above
are all you need.

If you work at High Five Labs, the team rules also apply here: coord, Linear,
draft pull requests and diagrams. They live in `highfivelabs/workspace`. Read
its `AGENTS.md` before you start, unless it is already in your context: it is
`../AGENTS.md` in a local checkout under the `highfivelabs/` folder, and
otherwise
`gh api repos/highfivelabs/workspace/contents/AGENTS.md -H "Accept: application/vnd.github.raw"`.

The essentials, in case you can't read it:

* Claim the Linear issue in coord before you edit (`coord claim HFL-n`), and
  put its key in the branch name and PR title.
* Open pull requests as drafts. Mark one ready only when it's finished and
  green, and put it back in draft before pushing to it again.
* This repository is public. Issue keys are fine. Internal URLs, customer
  names, credentials and personal details never go in commits, pull
  requests or files.
* The Spectacle method doesn't apply here. The kinds are generated and held
  in place by this repository's own checks.
<!-- HFL-WORKSPACE: END -->
