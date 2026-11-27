# CYBRA DUMP Protection and Recovery Policy

Status: design policy; this document does not mean automated backups are already running.
Scope: TEST/LIVE snapshots, controller state, manifests, and approved recovery metadata.
Never store plaintext secrets, private keys, wallet seed phrases, access tokens, or raw credential files in a dump.

## Minimum recovery guarantee: five dumps

Keep **at least five independently identifiable, verified recovery points** for each environment (TEST and LIVE), not merely five copies of the same archive.

- DUMP-1: newest verified snapshot.
- DUMP-2: previous verified snapshot.
- DUMP-3: third previous verified snapshot.
- DUMP-4: fourth previous verified snapshot.
- DUMP-5: fifth previous verified snapshot.

Each must have its own snapshot ID, timestamp, source commit SHA, environment label, schema version, file inventory, size, and SHA-256 checksum. Keep a separately marked last-known-good LIVE snapshot before every LIVE promotion.

A new snapshot must **not** overwrite any of the five retained recovery points until the new snapshot is completely written and verified. If a new backup fails, all five previous verified snapshots remain untouched. If fewer than five valid recovery points remain, raise a critical backup-health alarm and block LIVE promotion until the minimum is restored.

## Storage: 3-2-1

Maintain:
1. Primary snapshot on the server, outside the live application/state directory.
2. Independent secondary copy on a separate disk or volume—not just another directory on the same filesystem.
3. Encrypted off-site copy in versioned object storage or another independently administered destination.

The five recovery points should be protected across independent failure domains. Five folders on one phone/server/disk do not protect against loss of that device. GitHub is for source code and backup policy, not runtime dumps, databases, secrets, or private state archives.

The operator must select the remote destination and configure credentials before remote backup is enabled. Do not invent a bucket, account, or credentials.

## Safe snapshot creation

For every snapshot:
1. Acquire a single-writer backup lock.
2. Record snapshot ID, UTC time, TEST/LIVE label, source commit SHA, schema version, and included paths.
3. Write to a temporary archive.
4. Verify archive readability and calculate SHA-256.
5. Write a manifest with checksum, size, metadata, and status.
6. Atomically publish the verified archive and manifest locally.
7. Copy to the independent secondary destination and verify the copied checksum.
8. Upload an encrypted off-site copy and verify remote metadata/checksum where supported.
9. Mark COMPLETE only when all required destinations are verified. Otherwise mark DEGRADED and alert.

An interrupted or failed run must leave previous known-good dumps unchanged. Never label an unverified archive COMPLETE.

## Automatic recovery selection

If the controller crashes, becomes confused, or cannot decide which state is valid, recovery must not depend on that controller making the decision.

A separate, minimal recovery supervisor should:
1. Stop or isolate the failing application/controller instance.
2. Read the dump catalog and reject entries with missing manifests, checksum mismatch, incomplete status, incompatible schema, or wrong environment.
3. Examine the five retained recovery points from newest to oldest.
4. Select the newest snapshot that passes integrity and compatibility checks and is marked verified.
5. Restore it into an isolated recovery/TEST location first.
6. Run startup, data-integrity, and health checks.
7. Only after verification, permit a controlled return to the last-known-good LIVE version; otherwise try the next older verified dump.
8. If no candidate passes, enter SAFE_HALT, preserve all dumps, and require operator intervention. Never repeatedly overwrite state or attempt blind restoration.

The recovery supervisor must be simpler and more isolated than the main adaptive controller. It needs a single-writer lock, bounded retries, an audit trail, and a tested fallback procedure. A recovery attempt must never delete or modify its source dump.

## Integrity and immutability

- Verify SHA-256 before every restore.
- Encrypt off-site backups in transit and at rest; keep encryption keys separate from the backup destination.
- Enable object versioning and retention protection/immutability where supported.
- Never overwrite a completed snapshot; every run gets a new ID.
- Restrict delete permissions. Routine backup credentials should not be able to delete historical versions where feasible.
- Maintain an append-only audit record for creation, verification, restore tests, and deletion approvals.

## Retention baseline

The five newest verified recovery points are a hard minimum, not a substitute for longer retention. Initial additional policy, subject to storage capacity:
- Daily snapshots: retain 14 days.
- Weekly snapshots: retain 8 weeks.
- Monthly snapshots: retain 12 months.

Cleanup must never remove the only verified copy or reduce either environment below five valid recovery points. A dump may be pruned only after retention rules are met and at least five newer verified recovery points remain for that environment, with independent copies still available.

## Restore and LIVE promotion

- Test restores in an isolated location; never unpack directly over LIVE.
- Verify checksum, archive readability, manifest/schema compatibility, and expected file inventory.
- Run component health checks and regression tests after restore.
- Record restore result and recovery time.
- A dump is recoverable only after a successful isolated restore test.
- Before LIVE promotion, require five verified LIVE recovery points, a recent verified DUMP, and a tested rollback path to the previous LIVE snapshot.

## TEST / LIVE separation

Use separate directories, encryption keys, access policies, and retention labels. TEST dumps must never overwrite LIVE dumps. A sealed TEST snapshot stays read-only; promotion references immutable commit and snapshot IDs.

## Required states

CREATING -> LOCAL_VERIFIED -> SECONDARY_VERIFIED -> OFFSITE_VERIFIED -> COMPLETE

Failures become DEGRADED; checksum mismatch or unreadable archive becomes CORRUPT. Restore flow:
ISOLATE -> CANDIDATE_CHECK -> RESTORE_TO_TEST -> HEALTH_CHECK -> APPROVED_RECOVERY

## Implementation gate

This policy has not yet installed a backup service or connected remote storage. Before enabling automation, inspect the actual server filesystem and existing DUMP module, choose independent destinations, define encryption/key custody, and successfully test restore. Do not connect production PM2 or alter LIVE data as part of this policy-only change.
