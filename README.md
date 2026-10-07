<p align="center">
  <a href="https://whitefishcreative.co.uk/">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="assets/wfc-logo-white.svg">
      <img src="assets/wfc-logo.svg" alt="WhiteFish Creative" width="160">
    </picture>
  </a>
</p>

<h1 align="center">devcon</h1>

<p align="center">
  <strong>Claude Code in a dev container, signed in to a second Claude account.</strong><br>
  One command sets a project up for Claude Code in a container; DevPod runs the containers. Your Mac keeps your main account.
</p>

<p align="center">
  <img alt="Version 1.0.0" src="https://img.shields.io/badge/version-1.0.0-0A4E75">
  <img alt="Requires Docker Desktop and DevPod" src="https://img.shields.io/badge/requires-Docker%20%7C%20DevPod-569CBE">
  <img alt="macOS" src="https://img.shields.io/badge/platform-macOS-808285">
  <a href="LICENSE"><img alt="Licence: MIT" src="https://img.shields.io/badge/licence-MIT-0A4E75"></a>
</p>

---

## Why

The Claude desktop app and the Claude Code CLI share one sign-in per Mac. To work on a second Claude account at the same time, you need a second, separate place for Claude Code to live. A dev container is exactly that: a small Linux machine in Docker, with your project folder shared into it and its own Claude sign-in.

devcon makes setting that up one command, and leaves the running of the containers to DevPod.

## What it does

- **`devcon init`** writes `.devcontainer/devcontainer.json` into a project. The container it describes installs Claude Code and keeps the Claude sign-in in a Docker volume, so it survives rebuilds.
- **Accounts by name.** Every project that names the same account shares one sign-in; a different name gives a separate account.
- **`setup.sh`** makes `devcon` a command you can run from any folder, installs DevPod, and removes it all again cleanly.
- **DevPod** builds, starts, stops, rebuilds and deletes the containers, from a desktop app.

## Install

Clone the repo somewhere permanent and run setup:

```bash
git clone git@github.com:whitefish-creative-ltd/devcon.git ~/Code/_devcontainers
cd ~/Code/_devcontainers
./setup.sh install
```

`./setup.sh install`:

1. Links `devcon` into `~/.local/bin`, so it runs from any folder.
2. Adds `~/.local/bin` to your PATH in your shell's startup file (`~/.zshrc` for zsh), **only if it isn't there already**. The line is marked `# added by devcon setup.sh`. If it adds it, open a new terminal.
3. Installs **DevPod** with Homebrew, if it isn't installed.
4. Checks Docker is installed and running, and tells you if not.

To install the command without DevPod, run `./setup.sh install --without-devpod`. Running `install` again is safe, and repairs the command if you move the folder.

## Getting started

1. **Set up DevPod (once per machine).** Open DevPod → **Providers → Add → Docker**, keeping the defaults.
2. **Add the recipe to a project.**
   ```bash
   cd ~/Code/some-project
   devcon init
   ```
3. **Create the workspace.** In DevPod: **Workspaces → Create Workspace** → choose the project folder → **Default IDE: None** → **Create Workspace**. The first build takes a few minutes; later starts are quick. (From a terminal: `devpod up ~/Code/some-project --ide none`.)
4. **Run Claude in the container.**
   ```bash
   ssh some-project.devpod
   claude
   ```
   DevPod names the SSH entry `<workspace-name>.devpod`; the name is shown in the app.
5. **Sign in, the first time only.** `claude` gives you a sign-in link. Open it in your Mac's browser, sign in with the **second** account and paste the code back. Every project on the same account is then already signed in.

From then on, start, stop, rebuild and delete workspaces in DevPod. None of that touches your project files or the Claude sign-in.

## Commands

| Command | What it does |
| --- | --- |
| `devcon init` | Writes `.devcontainer/devcontainer.json` in the current folder, on the default account (`account2`) |
| `devcon init -a work` | The same, on a different Claude account |
| `devcon init ~/Code/some-project` | The same, for another folder |
| `devcon help` | Shows the commands |
| `./setup.sh install` | Installs the `devcon` command and DevPod |
| `./setup.sh install --without-devpod` | Installs the `devcon` command only |
| `./setup.sh uninstall` | Removes the command, and the PATH line if setup added it |

`devcon init` never overwrites an existing `devcontainer.json`: edit it directly, or delete it and run `init` again.

## How it works

### Background: dev containers

- A **dev container** is a small Linux machine running inside Docker on your Mac.
- Your **project folder is shared into it, not copied**: an edit on either side shows up on the other straight away.
- Everything else (installed tools, the home folder, the Claude sign-in) belongs to the container. That separation is what gives you a second account.
- **`devcontainer.json`** is the recipe: which Linux image to use and what to install. It lives in the project at `.devcontainer/devcontainer.json`.
- Containers are **disposable**. Delete or rebuild one and nothing is lost, as long as what matters lives outside it.

### The template

`devcon init` copies `template/devcontainer.json`, replacing `__NAME__` with the project folder's name and `__ACCOUNT__` with the account:

```json
{
  "name": "__NAME__",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:22",
  "containerEnv": {
    "CLAUDE_CONFIG_DIR": "/home/node/.claude"
  },
  "mounts": [
    "source=claude-config-__ACCOUNT__,target=/home/node/.claude,type=volume"
  ],
  "postCreateCommand": "sudo chown -R node:node /home/node/.claude && npm install -g @anthropic-ai/claude-code",
  "remoteUser": "node"
}
```

| Setting | Why |
| --- | --- |
| `image` | Microsoft's Node 22 dev container image. Claude Code is an npm package, so it needs Node. |
| `mounts` | Mounts a Docker **named volume**, `claude-config-<account>`, at the Claude config folder. Volumes live in Docker, outside any container, so the sign-in survives rebuilds and deletes. |
| `containerEnv` → `CLAUDE_CONFIG_DIR` | Makes Claude Code keep **all** its config and sign-in in that folder. Without it, part of the state goes in `~/.claude.json`, outside the volume, and you'd sign in again after every rebuild. |
| `postCreateCommand` | Runs once when the container is first built: gives the `node` user ownership of the volume (Docker creates it owned by root), then installs Claude Code. |
| `remoteUser` | Work as the image's normal `node` user, not root. |

Edit the template to change what every *new* project gets; existing projects keep their own copy.

### Accounts

An account is just the name of a Docker volume, `claude-config-<account>`.

- **The same name in several projects** shares one sign-in: sign in once, use it everywhere.
- **A different name** (`devcon init -a work`) is a separate volume and a separate sign-in.

List the sign-ins:

```bash
docker volume ls --filter name=claude-config-
```

Sign an account out completely (stop its workspaces first):

```bash
docker volume rm claude-config-account2
```

### The global command

`./setup.sh install` creates a symlink, `~/.local/bin/devcon` → `devcon` in this folder. `devcon` follows the link back here to find `template/`, so the folder must stay put: move it and re-run `./setup.sh install` from the new location. Because it's a link, a `git pull` here takes effect straight away.

## Common tasks

| I want to… | Do this |
| --- | --- |
| Use Claude in a new project | `devcon init` in the project, then Create Workspace in DevPod |
| Use a different Claude account | `devcon init -a <name>` |
| Change a project's account | Edit `claude-config-…` in its `devcontainer.json`, then rebuild the workspace in DevPod |
| Update Claude Code in a container | Rebuild the workspace in DevPod (it installs the latest), or run `npm install -g @anthropic-ai/claude-code` inside it |
| Get the latest devcon | `git pull` in this folder |
| Set up another machine | Clone the repo there, then `./setup.sh install` |
| Remove the command | `./setup.sh uninstall` |

## Requirements

- **macOS** with **Homebrew** (for DevPod; without it, get DevPod from [devpod.sh](https://devpod.sh))
- **Docker Desktop**, installed and running
- A **Claude account** for the containers, separate from the one on your Mac

## What setup changes on your computer

**`./setup.sh install`**
- Creates the link `~/.local/bin/devcon`.
- Adds one marked PATH line to your shell's startup file, only if `~/.local/bin` isn't already on your PATH.
- Installs DevPod with Homebrew, unless it's installed or you pass `--without-devpod`.

**`./setup.sh uninstall`**
- Removes the link, and the PATH line only if setup added it.
- Leaves DevPod, Docker, every project's `devcontainer.json`, the Claude sign-in volumes and this folder alone.

**`devcon init`** writes one file, `.devcontainer/devcontainer.json`, in the project you point it at. Nothing else.

## Troubleshooting

- **`devcon: command not found`:** open a new terminal, or run `./setup.sh install` again.
- **`template missing`:** the folder has moved since setup. Run `./setup.sh install` from its new location.
- **DevPod can't create a workspace:** check Docker Desktop is running, and that Docker is added under **Providers**.
- **Asked to sign in again after a rebuild:** the project's `devcontainer.json` is missing `CLAUDE_CONFIG_DIR` or the volume mount. Compare it with `template/devcontainer.json`.
- **A server on your Mac isn't reachable:** inside the container, `localhost` is the container. Use `host.docker.internal` for servers on your Mac. Projects that insist on `localhost` are best run on the Mac; use the container for code, Claude and unit tests.
- **A container isn't in DevPod:** DevPod only manages containers it created. Containers started from VS Code or the `devcontainer` CLI won't appear.
- **Keeping the file out of git:** add `.devcontainer/` to your global gitignore. Committing it shares the setup with anyone who clones the project.

## Development

```bash
git clone git@github.com:whitefish-creative-ltd/devcon.git
cd devcon
bash -n devcon setup.sh
```

- `devcon` — the command; writes a project's `devcontainer.json` from the template
- `template/devcontainer.json` — the recipe new projects get
- `setup.sh` — installs and uninstalls the global command, and installs DevPod
- Record each release in [CHANGELOG.md](CHANGELOG.md) and bump the version badge above.

## Licence

devcon is released under the [MIT License](LICENSE): use it, change it and share it freely, keeping the copyright notice.

**The WhiteFish Creative name and logo** aren't covered by the licence. See [TRADEMARKS.md](TRADEMARKS.md). Contributions are welcome under the terms in [CONTRIBUTING.md](CONTRIBUTING.md).

---

<p align="center">
  <a href="https://whitefishcreative.co.uk/">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="assets/wfc-logo-white.svg">
      <img src="assets/wfc-logo.svg" alt="WhiteFish Creative" width="64">
    </picture>
  </a><br>
  Designed and built by <a href="https://whitefishcreative.co.uk/"><strong>WhiteFish Creative Limited</strong></a>
</p>
