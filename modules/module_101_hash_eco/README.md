# CYBRA Git Hash / Hash Eco — rolling 100-hash autosave

The module keeps the newest 100 integrity records in one JSON ledger:
`state/git_hash_100.json`.

## Behavior
- `python3 eco.py show`, `json`, and `hash` calculate the current module hash and automatically append a record.
- `python3 eco.py history` prints the saved ledger without creating a new record.
- The ledger contains per-layer SHA-256 values, each record's master hash, and one `root_hash` over the ordered list of retained master hashes.
- The ledger is written atomically using a temporary file and `os.replace`.
- The retention cap is exactly 100 records; the oldest record is dropped when record 101 is appended.

## Important distinction
A hash is a fingerprint, not a backup or compression format. It cannot reconstruct the original memory, source files, or conversation. Keep the actual state/snapshot separately; use the root hash to detect changes to the saved list. Do not put secrets, private keys, seed phrases, or credentials into the ledger.

## Configure
Edit `state/git_hash_config.json`. The current implementation deliberately enforces `limit: 100` and a fixed in-module ledger path to prevent accidental unbounded growth or arbitrary path writes.

## Verification
After installing the module, run:
`python3 eco.py hash`
then:
`python3 eco.py history`
The first command should create/update the ledger; the second displays the saved record count and root hash.
