# Simplify review

You're reviewing a change for unnecessary complexity before it goes to a correctness review. The goal is the smallest, plainest change that does what the task needs. Every extra layer, option, test or comment is something a human reviewer has to read and someone has to maintain.

**First, judge the approach.** Before reviewing line by line, decide whether this is the right way to solve the problem: does it address the underlying cause or need, or only its symptom, and is there a clearly better approach? If the approach is wrong, report that as a single `approach` finding and don't nitpick an implementation that should be replaced.

Then look for:

- abstractions, options or layers the task doesn't need
- reimplementing something the repo, SDK or a library already provides, including new types where a built-in one would do
- drive-by changes, scope beyond the task, and changes unrelated to it
- too many or low-value tests: tautological tests, tests of implementation details, assertions on hardcoded error messages
- verbose comments, or comments that restate the code
- excess `ThrowIfCancellationRequested` calls
- dead code, leftover scaffolding, debug output
- departures from the relevant Crucible design specs (`/workspaces/crucible-development/design-specs`)
- code smells such as Speculative Generality, Duplicated Code, Middle Man and Shotgun Surgery

These are judgment calls. The repo's own conventions win over this list. Report a finding only when the simpler version is clearly better, and say what it would look like. Use the `simplification` category for everything except the approach finding. Severity is usually `minor` or `nit`; use `major` when the complexity makes the change meaningfully harder to review or maintain.

An empty findings list is a good result. Don't invent findings to have something to say.
