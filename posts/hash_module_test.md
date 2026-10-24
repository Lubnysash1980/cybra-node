# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`4a464e9d3d4875eeb017fb316858bd664cad3c09520da8efbbce3cb1b2670d53`

Payload Double SHA:
`51e7a9c07998861bf6570eb3e99f35af1a502a67a2fe619702e913152506e92d`

Root Double SHA:
`794bec48cdddd78bbfe7088a32dea7aa77b0fb94cdc88549be5d086774c521b2`

Manifest:
`hash_storage/test/hash_module_test_manifest.json`

## Detected hash modules

- `gitcybrahash_double_backend.mjs`: True
- `hash_memory.py`: True
- `hash_daemon.mjs`: True
- `cybra_sha_core_manager.sh`: True
- `hash_storage/root_hash.json`: False


## Result

Hash module base pipeline works if:

- payload file exists;
- manifest file exists;
- proof file verifies;
- double SHA is generated;
- root double SHA is generated.
