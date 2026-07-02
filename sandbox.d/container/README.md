## container backend assets

This directory contains Apple `container` sandbox assets used by muthr.

Place container backend profile definitions and backend-specific overrides here.

## Container Storage Subsystem Optimization

For high-churn agent workflows, keep temporary caches on ephemeral paths instead of persistent overlay layers when possible.

1. Prune volatile build/cache paths from long-lived workspace state.
2. In custom manifests, mount high-write paths to `/tmp` or other ephemeral locations.
3. Avoid writing package manager cache directories directly into repository trees unless persistence is required.
