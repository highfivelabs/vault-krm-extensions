# Rehearsal cassettes (fake API)

Written by krm-rest-runtime's kindtest.Rehearse (KRM_FAKE_RECORD=1 go test
-run TestEveryKindRehearsal .), replayed by the same test in every go test.

Each file is one kind's live steps (create, read back, update, drift repair,
delete) as the runtime sends them and as the runtime's fake API answers: a
full request and response example of every kind, in the same format and with
the same placeholders as a live run's cassettes (hack/live/cassettes).

The fake answers what the descriptors say, not what the vendor does: these
are not recordings of the real API, and no kind's readiness depends on
them. Where a kind has a live cassette, that one shows the real answers.
