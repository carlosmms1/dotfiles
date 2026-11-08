# dotfiles

Configuração pessoal para reduzir o atrito entre máquinas e sistemas operacionais.
Os dotfiles são versionados em `stow/` e aplicados com GNU Stow em `$HOME`.

## Estrutura

```
.
├── setup.sh                 # bootstrap completo (pacotes, zsh, fontes, stow...)
├── lib/                     # helpers compartilhados (log, distro, pacotes)
├── packages/                # listas de pacotes por distro
│   ├── arch.txt
│   ├── fedora.txt
│   └── fedora-optional.txt  # COPR / terceiros
├── scripts/
│   ├── stow.sh              # aplica os pacotes stow com backup
│   ├── import.sh            # puxa configs da máquina para o repo
│   ├── nf-install.sh        # Meslo + JetBrains Mono Nerd Font
│   └── code-install.sh      # VS Code + extensões
├── stow/                    # pacotes aplicados em $HOME
│   ├── zsh/
│   ├── powerlevel10k/
│   ├── kitty/
│   ├── nvim/
│   ├── bash/
│   ├── git/
│   ├── tmux/
│   ├── btop/
│   ├── herdr/
│   ├── gh/
│   ├── vscode/
│   ├── opencode/
│   ├── ssh/
│   ├── misc/
│   ├── ghostty/
│   ├── claude/
│   ├── hypr/                # perfil wayland
│   ├── waybar/              # perfil wayland
│   └── noctalia/            # perfil wayland
├── templates/               # exemplos de configs com segredos
└── vscode/extensions.txt
```

## Instalação em uma máquina nova

### Fedora

```sh
git clone git@github.com:carlosmms1/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Opcional: repositórios de pacotes que não estão no Fedora oficial
# (lazygit, ghostty, brave, docker). Veja packages/fedora-optional.txt.
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable -y dejan/lazygit
sudo dnf copr enable -y scottames/ghostty

./setup.sh --profile core
```

### Arch Linux

```sh
git clone git@github.com:carlosmms1/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh --profile core
```

O `setup.sh` instala yay se necessário, atualiza o sistema, instala os pacotes de
`packages/<distro>.txt`, configura ZSH/Oh My Zsh/powerlevel10k, Nerd Fonts,
VS Code + extensões, aplica os dotfiles com stow e instala os plugins do tmux.

### Perfis

| Perfil | O que aplica |
|---|---|
| `core` (default) | zsh, kitty, nvim, bash, git, tmux, btop, herdr, gh, vscode, opencode, ssh, misc, ghostty, claude |
| `wayland` | core + hypr, waybar, noctalia |
| `all` | igual a `wayland` (mantido por compatibilidade) |

### Flags úteis

```sh
./setup.sh --help
./setup.sh --no-packages --no-update-system   # só reaplica dotfiles
./setup.sh --yes                              # sem confirmação
```

## Segredos

Os arquivos com token/senha **não** são versionados. O template fica em
`.env.example`:

```sh
cp .env.example ~/.config/opencode/.env
chmod 600 ~/.config/opencode/.env
$EDITOR ~/.config/opencode/.env
```

Variáveis usadas:

- `GITHUB_PERSONAL_ACCESS_TOKEN` — MCP do GitHub no opencode
- `NEON_API_KEY` — MCP da Neon em `opencode.jsonc`
- `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` / `LANGFUSE_BASE_URL`
- `PLANE_API_TOKEN`

O `~/.zshrc` sourceia `~/.config/opencode/.env` automaticamente (e, por
compatibilidade, o antigo `~/.config/opencode/github-mcp.env`).

Nunca versionar: `~/.ssh/*_key`, `~/.config/opencode/{service.json,secrets/}`,
`~/.config/neon/credentials.json`, `~/.codex/auth.json`, `~/.claude.json`,
históricos e perfis de navegador. Veja `docs/auditoria-e-inventario.md`.

## Stow manual

O `scripts/stow.sh` move arquivos reais conflitantes para
`~/.dotfiles-backup-XXXXXXXXXXXXXX/` antes de criar os symlinks. Ele usa
`--no-folding`, então aplicativos que gravam estado (herdr, opencode, gh,
VS Code) não sujam o repositório.

```sh
./scripts/stow.sh --profile core --dry-run   # simula
./scripts/stow.sh --profile core             # aplica

# pacotes específicos
./scripts/stow.sh --packages "nvim zsh git"

# ignorar alguns
./scripts/stow.sh --profile core --exclude "opencode,ssh"
```

## Manutenção

```sh
# Puxar alterações feitas na máquina de volta para o repo
./scripts/import.sh --dry-run
./scripts/import.sh --packages "nvim tmux git"

# Atualizar a cópia do nvim no repo a partir da máquina
rsync -aL --delete ~/.config/nvim/ stow/nvim/.config/nvim/

# Atualizar extensões do VS Code
code --list-extensions | sort > vscode/extensions.txt

# Reaplicar depois de editar um dotfile no repo
./scripts/stow.sh --packages nvim
```

O `cli.json` do opencode é reescrito em runtime, por isso não é stowado; o
modelo fica em `templates/opencode/cli.json.example`.

## Documentação

- `docs/auditoria-e-inventario.md` — auditoria da máquina, dotfiles que estavam
  fora do repo, segredos encontrados e checklist de migração.
