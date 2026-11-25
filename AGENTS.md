# Rules for every change

**Run CI locally and prove it in the pull request.** Until this repository
is public and CI runs on every pull request, nobody can see CI results for
your change unless you show them. Before you open or update a pull request:

1. Commit everything, then run `hack/ci.sh --report` from the repository root.
2. Paste its whole output into the pull request description, under
   "Local CI". It records the commit it tested, the toolchain, and each
   step's result.
3. Do not open, mark ready, or merge a pull request whose "Local CI" section
   is missing, failed, tested an older commit than the head, or reports
   uncommitted changes. After you push new commits, run it again and
   replace the section.

`hack/ci.sh` is the same script `.github/workflows/ci.yml` runs, so a local
pass means the same checks as CI. Add new checks to `hack/ci.sh`, not to
ci.yml.
