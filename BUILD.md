# X-Agents Build Notes

This source tree is configured to build public releases with both frontend and backend obfuscated by default.

## Default behavior

`scripts/build-release.sh` now defaults to:

- `XPANEL_OBFUSCATE_FRONTEND=1`
- `XPANEL_OBFUSCATE_BACKEND=1`

That means a plain build already generates:

- frontend minified and obfuscated
- backend obfuscated

## Standard release command

```bash
bash scripts/build-release.sh
```

## Explicit release command

Use this when you want to pin the release base URL manually:

```bash
XPANEL_RELEASE_BASE_URL="http://YOUR-HOST/static/xagents/releases/$(cat VERSION)" \
bash scripts/build-release.sh
```

## Optional override

If you ever need to disable obfuscation temporarily for local debugging only:

```bash
XPANEL_OBFUSCATE_FRONTEND=0 XPANEL_OBFUSCATE_BACKEND=0 bash scripts/build-release.sh
```

Do not use that override for public releases.
