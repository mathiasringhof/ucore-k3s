# Repository Guidelines

## Project Structure & Module Organization

- Root `Containerfile` defines the base bootc image and doesn't need to be modified
- `build_files/build.sh` is executed from `Containerfile`, image modifications should be put in here or in scripts in `build_files/` that get called from the main `build.sh`
- `disk_config/` contains Bootc Image Builder specs for qcow2/raw/iso outputs; tweak storage layouts or ISO metadata in those TOML files.
- `Justfile` is the orchestration hub for every workflow, while `artifacthub-repo.yml` and `README.md` document release metadata.
- Never commit generated secrets such as `cosign.key`; only the accompanying `.pub` key belongs in version control.

## Build, Test, and Development Commands

- `just build [image_name] [tag]` runs `podman build` with automatic SHA metadata; execute from the repo root.
- `just build-qcow2`, `just build-raw`, and `just build-iso` call Bootc Image Builder with the matching `disk_config` profile.
- `just run-vm-qcow2` (or `run-vm-raw` / `run-vm-iso`) boots the artifact through QEMU-in-container for smoke testing; it auto-builds if the disk image is missing.
- `just lint` and `just format` run `shellcheck` and `shfmt` across every `*.sh`.
- `just clean` removes `_build*`, manifests, and `output/` artifacts prior to a fresh pipeline run.

## Coding Style & Naming Conventions

- Scripts are POSIX-friendly Bash with `set -euo pipefail`; prefer 4-space indentation, lowercase function names, and descriptive filenames.
- Keep container layers declarative: reference helper scripts under `build_files/` instead of long inline heredocs.
- When adding recipes, follow the existing `Justfile` group annotations and target naming scheme (`build-*`, `run-*`, `lint`, etc.).

## Testing Guidelines

- There is no standalone unit test suite; verification is image-centric.
- After any change, run `just build` followed by `just run-vm-qcow2` (or the artifact type you modified) and confirm k3s services reach a healthy state.
- For shell updates, ensure `just lint` passes and add inline smoke assertions (e.g., `command -v k3s`) inside the relevant `build_files/*.sh`.

## Commit & Pull Request Guidelines

- Use short, present-tense summaries under ~72 characters, matching history like `removed debug output from build.yaml`.
- Squash incidental sync commits before pushing and keep each PR focused on one concern (base image bump, k3s tweak, CI fix, etc.).
- PR descriptions should list what changed, which commands were run (`just build`, `run-vm-*`, `lint`), and any required secrets or config updates.
- Link related issues and attach screenshots or console logs when the change affects boot/install UX.

## Security & Configuration Notes

- Generate `cosign.key` locally and load it into the `SIGNING_SECRET`; never commit the private key to GitHub.
- Document any new credentials, ports, or services in `README.md`

## Dealing With Sandbox Restrictions

- Network calls often fail without elevated permissions.  
- When you see `error connecting to api.github.com`, immediately re-run the same command **without** altering it, but include:
  - `with_escalated_permissions: true`
  - `justification: "Need to contact GitHub API to retrieve workflow logs"` (tailor the sentence to the action).
- Do **not** ask the user in chat; request escalation directly via the tool call as required by the harness.
