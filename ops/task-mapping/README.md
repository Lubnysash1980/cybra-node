# CYBRA BAR task mapping

One task is the unit of work. Any number of executors can be attached to it; each executor reports events against the same task ID. Executors do not create duplicate tasks for the same outcome.

## Levels
- green: exactly 100%, status done, acceptance criteria met and evidence attached.
- yellow: 30–99% progress, or an explicitly recorded degradation at/above 30%.
- red: progress below 30% for an active/measured task, or confirmed failed/blocked at any percentage.
- not_checked: task has not started or has no measurement/evidence yet; this is not a failure score.

The CLI enforces these thresholds when updating a task. A planned task at 0% stays not_checked until work starts; once active, below 30% is red.

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
