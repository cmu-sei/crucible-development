## Also check, for Crucible

- **Alignment with the task:** parts of the task that are missing, or behavior the task didn't ask for.
- **Security-sensitive areas:** anything that widens access, weakens validation, skips an authorization check, or logs sensitive data. Pay particular attention to authorization, authentication, Keycloak realm changes, secrets and configuration.
- **Crucible design specs:** if `/workspaces/crucible-development/design-specs` has a spec for the area, check the change against it.

Points you'd only mention to the author as optional or a follow-up are findings too: the author decides, and only findings reach them.
