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
