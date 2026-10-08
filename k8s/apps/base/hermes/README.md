# Hermes Agent

Hermes runs in its own Kubernetes namespace using the official container image.
The pod keeps Hermes state, Codex authentication, and cloned repositories on
`hermes-data`. An init container installs a pinned Codex CLI into a shared
`emptyDir`, and the official image provides local headless Chromium for browser
automation. Agent commands run inside the Hermes pod (`terminal.backend: local`);
the pod is the execution boundary and has no Kubernetes service account token.

The Deployment starts at **zero replicas**. This lets Flux apply the manifests
without connecting a second client with the OpenClaw Discord bot token or
requiring credentials that have not been provisioned yet.

## Before enabling

1. Create a SOPS-encrypted Kubernetes Secret named `hermes-secrets` in namespace
   `hermes`, containing `DISCORD_BOT_TOKEN` and `GEMINI_API_KEY`. Add the encrypted
   file to `kustomization.yaml`. The repository's `.sops.yaml` encrypts
   `stringData` in files under `k8s/**/secrets/`. A separate Discord bot token is
   preferable while testing; if reusing OpenClaw's token, stop OpenClaw first.

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: hermes-secrets
     namespace: hermes
   type: Opaque
   stringData:
     DISCORD_BOT_TOKEN: <bot token>
     GEMINI_API_KEY: <Gemini API key>
   ```

   From the repository root, save it as
   `k8s/apps/base/hermes/secrets/hermes-secrets.enc.yaml`, run
   `sops --encrypt --in-place k8s/apps/base/hermes/secrets/hermes-secrets.enc.yaml`,
   and confirm the values are encrypted before committing it.
2. Confirm the selected Gemini model and quota. The model is declared in
   `config/config.yaml`; the init container copies this file to the persistent
   Hermes data volume on every pod start.
3. Scale Hermes to one replica in Git. After the pod starts, authenticate Codex
   separately from Hermes:

   ```sh
   kubectl -n hermes exec -it deploy/hermes -- s6-setuidgid hermes codex login --device-auth
   kubectl -n hermes exec deploy/hermes -- s6-setuidgid hermes codex login status
   ```

   `CODEX_HOME` is under `/opt/data/home`, so this login survives pod restarts.
   An OpenAI API key can be used instead if that is the preferred Codex
   authentication method.
4. Test a Discord message, a small Codex coding task in `/opt/data/workspace`,
   and a browser task before removing OpenClaw. Development repositories should
   be cloned into `/opt/data/workspace`; no host source tree or container runtime
   socket is mounted.

The PVC must provide a filesystem suitable for SQLite WAL. The default k3s
local-path volume is suitable; do not move `state.db` to NFS without setting
`database.journal_mode: delete` in Hermes config.
