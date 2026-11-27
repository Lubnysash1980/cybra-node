# CYBRA DUMP Protection and Storage Policy

Status: design policy; not an installed backup service.
Scope: TEST and LIVE state snapshots, controller state, manifests, and approved recovery metadata.
Never store plaintext secrets, private keys, wallet seed phrases, access tokens, or raw credential files in a dump.

## Goal

A dump must survive accidental deletion, device loss, repository mistakes, corruption, and a failed restore. A successful archive command alone is not proof of recoverability.

## Storage model: 3-2-1

Maintain at least:
1. **Primary local snapshot** on the server, outside the live application/state directory.
2. **Independent secondary copy** on a separate disk or volume, not merely another directory on the same filesystem.
3. **Encrypted off-site copy** in versioned object storage or another independently administered backup destination.

GitHub is for source code, manifests, and backup policy—not runtime dumps, databases, secrets, or private state archives.

The remote destination must be selected and credentials configured by the operator before remote backup can be enabled. Do not invent a bucket, account, or credentials.

## Safe write protocol

For every snapshot:
1. Acquire a single-writer backup lock.
2. Record snapshot ID, UTC creation time, source environment (TEST/LIVE), source commit SHA, schema version, and included paths.
3. Write the archive to a temporary file.
4. Verify archive readability and calculate SHA-256.
5. Write a manifest containing the checksum, size, metadata, and backup status.
6. Atomically rename the verified temporary archive and manifest into the local backup directory.
7. Copy to the independent secondary destination; verify checksum after copy.
8. Upload an encrypted copy to the configured off-site destination; verify remote object metadata/checksum where supported.
9. Mark the snapshot **COMPLETE** only after all required destinations have been verified. Otherwise mark it **DEGRADED** and alert; never silently report success.

A failed or interrupted run must leave the previous known-good snapshot untouched.

## Integrity and immutability

- Use SHA-256 checksums and verify them before restore.
- Encrypt off-site backups in transit and at rest; keep encryption keys separate from the backup destination.
- Enable object versioning and retention protection/immutability on the remote destination where supported.
- Do not overwrite a completed snapshot. New runs create new snapshot IDs.
- Restrict delete permissions; routine backup credentials should be write-only where feasible and must not be able to delete historical versions.
- Keep an append-only audit record of snapshot creation, verification, restore tests, and deletion approvals.

## Retention baseline

Initial configurable policy (confirm against available storage before enabling):
- Daily snapshots: retain 14 days.
- Weekly snapshots: retain 8 weeks.
- Monthly snapshots: retain 12 months.
- Keep at least one separately marked last-known-good snapshot before every LIVE promotion.

Retention cleanup must never delete the only verified copy. Deletion is permitted only when the retention rule is met and at least two newer verified copies exist across independent destinations.

## Restore requirements

- Restore into an isolated TEST location first; never unpack over LIVE.
- Verify checksum, archive readability, manifest/schema compatibility, and expected file inventory.
- Run component health checks and regression tests after restore.
- Record the restore result and time-to-recover.
- A backup is considered **recoverable** only after a successful isolated restore test.
- Before LIVE promotion, require a recent verified DUMP and a tested rollback path to the previous LIVE snapshot.

## TEST / LIVE separation

Use separate directories, encryption keys, access policies, and retention labels for TEST and LIVE. A TEST snapshot must never overwrite a LIVE snapshot. A sealed TEST snapshot remains read-only; promotion references its immutable commit/snapshot IDs.

## Required states

CREATING -> LOCAL_VERIFIED -> SECONDARY_VERIFIED -> OFFSITE_VERIFIED -> COMPLETE

Any failure becomes DEGRADED; checksum mismatch or unreadable archive becomes CORRUPT. Restore flow is RESTORE_TO_ISOLATED_TEST -> VERIFY -> HEALTH_CHECK -> RESTORE_APPROVED.

## Implementation gate

This document does not create backups or connect storage. Before enabling automation, inspect the actual server filesystem and existing DUMP module, choose the independent secondary and off-site providers, define encryption/key custody, and test restore. Do not connect production PM2 or alter LIVE data as part of this policy-only change.
