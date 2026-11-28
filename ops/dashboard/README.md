# CYBRA work dashboard

Open `index.html` through GitHub Pages or serve the repository locally.

## Termux
From the repository root:
```sh
cd ~/CYBRA
python -m http.server 8765 --directory .
```
Then open `http://127.0.0.1:8765/ops/dashboard/` in the phone browser.

The dashboard reads `state/work_status.json` and links to `WORKLOG.md`. It is read-only. It does not execute repairs or restart services.

For a public GitHub Pages link, enable Pages for this branch/folder or deploy this directory using a Pages workflow. No Pages URL is claimed until GitHub confirms publication.
