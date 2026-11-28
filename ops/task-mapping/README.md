# CYBRA BAR task mapping

One task is the unit of work. Any number of executors can be attached to it; each executor reports events against the same task ID. Executors do not create duplicate tasks for the same outcome.

## Levels
- green: done, 100%, acceptance criteria met, evidence attached.
- yellow: in progress or degrading (1–99%).
- red: confirmed failed or blocked.
- not_checked: no trustworthy probe/evidence yet. This is intentionally neutral.

## CLI
From repository root:
\`\`\`sh
python ops/task-mapping/cybra-map.py list
python ops/task-mapping/cybra-map.py add CY-012 "New task" --executor github-actions --executor neuro --acceptance "CI passes"
python ops/task-mapping/cybra-map.py event CY-012 "Started static analysis" --executor github-actions --kind started
python ops/task-mapping/cybra-map.py update CY-012 --status in_progress --progress 40 --note "Parser and tests in progress"
python ops/task-mapping/cybra-map.py validate
\`\`\`

A task may only be green when status=done, progress=100 and evidence is non-empty. Every update is appended to events.ndjson. The CLI never executes task commands, deploys, restarts services, or edits dependencies.

## Shared execution contract
1. Coordinator creates/updates one task ID.
2. Executors claim work by adding their executor ID and recording an event.
3. Executors write outputs/evidence paths to the task record.
4. Only verified acceptance criteria allow green/100%.
5. Conflicts are resolved by task version/commit and event history; no executor silently overwrites another's result.
