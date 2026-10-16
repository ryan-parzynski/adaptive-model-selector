# decisions/

Conclusions that are **settled**, **set aside** or **rejected**, with the evidence and the condition that should reopen each one. This complements `proposed/` (ideas not yet adopted) and `STATUS.md` (what is proven).

## Policy: don't settle on a conclusion during active change

1. **Reversals need corroboration.** A conclusion that removes a capability or reverses a design ("X can't do Y", "Z is broken", "lane L is offline") needs a second, independent observation before anything is built or removed because of it: a different method, a different box, or a later time.
2. **State claims get re-checked while things change.** A claim about current state (mode, reachability, limits, which model is serving) is re-checked after the next batch of changes, and again about a day later, before it is treated as settled. It's labeled *reported* until then.
3. **Conflicts stay open until tested.** When an operator's direct observation and an agent's report disagree, the question is marked **unresolved** and tested. Neither side is picked by default.
4. **Read the mechanism, not the message.** The command that actually runs, the exit code, the measured value, rather than a log line, a status label or a recalled memory.
5. **Every set-aside idea gets a revisit trigger.** It records why it was set aside, the evidence, the date, and the condition that reopens it. Ideas rejected **on measurement** stay rejected until a measurement says otherwise. Ideas set aside **on assumption** are revisited when the assumption changes.

## Ledger format

| Idea | Status | Why | Evidence | Date | Revisit when |
|---|---|---|---|---|---|

Status is one of `settled`, `set-aside`, `rejected-measured`, `reversed`.
