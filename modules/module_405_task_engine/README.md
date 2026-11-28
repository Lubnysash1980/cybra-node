# CYBRA Task Engine

- Detects menu/controller/health/structure issues.
- Creates JSON task records and copies supported sources into an isolated sandbox.
- Runs syntax-only checks; interactive menu scripts are never executed by the audit.
- A successful task is marked `awaiting_approval`.
- Automatic writes to live source files are disabled. Review and implement changes through CYBRA NEURO and Parliament approval.
- `cycle N` creates and tests at most N tasks; it does not apply patches.
