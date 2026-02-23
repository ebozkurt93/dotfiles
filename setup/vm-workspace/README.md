# vm-workspace

Template-based VM workflow for local development.

## Requirements

- `limactl`
- `yq` (only needed when using `--cpus`, `--memory`, or `--disk`)

## Recommended flow (templates)

```bash
vm-workspace --template-create ai-template --setup-script "$HOME/dotfiles/setup/vm-workspace/setup.sh"
vm-workspace --template-use ai-template --name ai-task-123 \
  --workspace-script "$HOME/dotfiles/setup/vm-workspace/workspace.sh"
```

## Template validation (first time)

```bash
vm-workspace --template-create ai-template --setup-script "$HOME/dotfiles/setup/vm-workspace/setup.sh"
vm-workspace --name ai-template --shell
vm-workspace --name ai-template --stop
```

## Ad-hoc VM (testing only)

```bash
vm-workspace --setup-script "$HOME/dotfiles/setup/vm-workspace/setup.sh"
```

## Workspace copy

The default workspace script is user-specific and hardcoded:

- Host: `~/personal-repositories/CV`
- VM: `~/workspace/CV`

```bash
vm-workspace --template-use ai-template --name ai-task-123 \
  --workspace-script "$HOME/dotfiles/setup/vm-workspace/workspace.sh"
```

## Common management

```bash
vm-workspace --status
vm-workspace --name ai-task-123 --shell
vm-workspace --name ai-task-123 --stop
vm-workspace --name ai-task-123 --delete
```

## Getting data out (doc-only)

Copy a folder back to host:

```bash
limactl copy ai-task-123:~/workspace/CV /path/on/host/
```

Create a PR / push from inside VM:

```bash
cd ~/workspace/CV
git status
git add .
git commit -m "..."
git push
```

Export a patch and copy it to host:

```bash
# Inside VM
cd ~/workspace/CV
git diff > /tmp/changes.patch

# On host
limactl copy ai-task-123:/tmp/changes.patch /path/on/host/
```

## Notes

- Use `--flag value` (no `--flag=value`).
- `--template-use` applies CPU/memory/disk overrides.
- `--template-use` opens a shell by default after the VM is ready.
- Running `vm-workspace` with no args prints usage and exits.
