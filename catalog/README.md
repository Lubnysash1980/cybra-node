# CYBRA contract registry UI

Static, read-only catalog interface.

## Safety
- No wallet provider, wallet connection, message signing, transaction, deployment, or private-key handling.
- Catalog records are loaded from `contracts.json`.
- Status values: `confirmed`, `proposed`, `blocked`.
- A record may be marked `confirmed` only when its source and implementation are verified.

## Current data state
The UI target is 500 records. The data file is intentionally empty until the existing 163-item source list is located and checked. No contract names, addresses, deployment states, or audit claims are fabricated.

## Preview
Serve this directory as static files, for example with any static HTTP server. Open `index.html`.
