# Auditoria dos dotfiles e scripts

Data: 2026-11-07
Máquina auditada: Fedora Linux 45 (Workstation, GNOME/Wayland), usuário `cmms`
Repo: `~/dotfiles` — remote `git@github.com:carlosmms1/dotfiles.git`
Stow: GNU Stow 2.4.1, alvo `$HOME`

---

## 0. Status da implementação (2026-11-07)

Já implementado neste repo:

- `lib/` ligado ao `setup.sh` e aos scripts; `detect_distro` cobre Arch, Fedora e Debian.
- `setup.sh` multi-distro, com `--profile core|wayland|all`, `--no-fonts`,
  `--no-vscode`, `--no-tmux-plugins`, `--yes` e validação sem o bug do `((errors++))`.
- `packages/arch.txt`, `packages/fedora.txt`, `packages/fedora-optional.txt` e
  `packages/fedora-wayland.txt`; `packages.txt` virou symlink para `packages/arch.txt`.
- Novos pacotes stow: `bash`, `git`, `tmux`, `btop`, `herdr`, `gh`, `vscode`,
  `opencode`, `ssh`, `misc`, `ghostty`, `claude`; `nvim` sincronizado com a máquina.
- `scripts/stow.sh` reescrito (backup automático, `--no-folding`, `--dry-run`,
  `--exclude`, perfis).
- `scripts/nf-install.sh` reescrito (cross-distro, Meslo + JetBrains Mono).
- `scripts/code-install.sh` corrigido (cores, ramo Debian, `dnf check-update`
  removido, instalação idempotente, extensões via `vscode/extensions.txt`).
- `.zshrc` sem caminhos absolutos, sem source sem guarda e sem OMZ duplicado.
- `~/.config/opencode/.env` criado com os segredos extraídos da configuração
  viva (modo 600), e `opencode.jsonc` sanitizado com `{env:NEON_API_KEY}`.
- `cli.json` do opencode foi movido para `templates/opencode/cli.json.example`
  porque o opencode o reescreve em runtime.

Pendências para a outra máquina:

- Preencher `~/.config/opencode/.env` com tokens válidos (ou rotacionar os atuais).
- Habilitar os repositórios opcionais do Fedora se quiser `lazygit`, `ghostty`,
  `brave-browser` e `moby-engine`.
- Rodar `gh auth login` e recriar as chaves SSH (`github_key`, `carlosmms_key`).
- Testar `./scripts/stow.sh --profile core --dry-run` antes de aplicar.

---

## 1. O que está de fato aplicado hoje

| Pacote stow | Alvo em `$HOME` | Estado |
|---|---|---|
| `zsh` | `~/.zshrc`, `~/.config/zsh/*` | linkado (arquivos individuais) |
| `powerlevel10k` | `~/.p10k.zsh` | linkado |
| `kitty` | `~/.config/kitty/*` | linkado |
| `nvim` | `~/.config/nvim/*` | linkado após sincronizar com a cópia viva |
| `bash`, `git`, `tmux`, `btop`, `herdr`, `gh`, `vscode`, `opencode`, `ssh`, `misc`, `ghostty`, `claude` | vários | linkados |
| `hypr` | `~/.config/hypr` | não existe nesta máquina (GNOME) |
| `waybar` | `~/.config/waybar` | não existe nesta máquina |
| `noctalia` | `~/.config/noctalia` | não existe nesta máquina |

O modo `--no-folding` foi adotado para que apps que gravam estado (herdr,
opencode, gh, VS Code) não escrevam dentro do repositório.

Os antigos symlinks `/.config/hypr` e `/.config/waybar` na raiz do repo foram
removidos, assim como o backup `stow/waybar/.../config.jsonc.bak`.

Evidência do `stow -n` antes das correções:

```text
--- hypr ---    LINK: .config/hypr => ../dotfiles/stow/hypr/.config/hypr
--- noctalia - LINK: .config/noctalia => ../dotfiles/stow/noctalia/.config/noctalia
--- waybar ---  LINK: .config/waybar => ../dotfiles/stow/waybar/.config/waybar
--- nvim -----  WARNING! stowing nvim would cause conflicts (12 arquivos)
--- zsh ------  UNLINK/LINK (já linkado)
```

Ou seja: rodar o `setup.sh` atual nesta máquina tentaria instalar Hyprland/Waybar/Noctalia
em um GNOME e abortaria no `nvim` por conflito.

Também estão versionados dois symlinks dentro do próprio repo (`/.config/hypr` e
`/.config/waybar`) que não são usados por nenhum app. São atalhos de edição; podem sair.

---

## 2. Revisão dos arquivos e scripts unstaged

> Os números de linha abaixo se referem à versão analisada antes das correções.
> O estado atual já incorpora as correções descritas.

### 2.1 `.gitignore`

- Adiciona `.env*` e `!.env.example`. **Correto.**
- `.env.example` está vazio. Falta documentar as variáveis necessárias.
- `*.log` já cobre `bootstrap.log` e `scripts/scripts.log`.

### 2.2 `setup.sh`

| # | Linha | Problema | Severidade |
|---|---|---|---|
| A1 | 273 | Só roda em Arch (`/etc/arch-release`, `yay`, `pacman`). A máquina atual é Fedora; o script nem inicia. | alta |
| A2 | 5–8 | `lib/` recém-criado não é importado; logger/utils/pkg/detect continuam duplicados dentro do script. | média |
| A3 | 22, 280–306 | `SETUP_FONTS=true` existe, mas a função está comentada e não há `--no-fonts`. `--no-packages` aparece no help, mas não é parseado. | média |
| A4 | 221–224 | Faz `stow --restow` de **todos** os pacotes: conflita com `nvim` e instalaria `hypr`/`waybar`/`noctalia` no GNOME. | alta |
| A5 | 243, 253, 257, 261 | `((errors++))` retorna status 1 quando `errors=0`; com `set -e` o `validate` aborta no primeiro item ausente. | alta |
| A6 | 73 | `setup_yay` loga "Yay already installed" mesmo depois de instalar. | baixa |
| A7 | 52–54 | `package_installed` usa `pacman`/`yay` e não é chamado em lugar nenhum. | baixa |
| A8 | 8 | Espaço em branco no fim do `readonly LOG_FILE`. | cosmética |
| A9 | 255–261 | `validate` cobra JetBrains Mono e Meslo Nerd Font, mas nenhuma etapa instala fontes (função comentada). | média |
| A10 | 219–224 | Não há backup nem tratamento de conflito; `--restow` não resolve arquivo real existente. | alta |
| A11 | 180 | Uso de `which` (deprecated) em vez de `command -v`. | baixa |
| A12 | 331 | `read -rp` dentro de script com `set -e`; se rodar sem TTY (CI/ssh não interativo) trava ou falha. | baixa |

Pontos positivos: reindentação ficou consistente (2 espaços) e o cabeçalho/log estão
melhores que antes.

### 2.3 `scripts/code-install.sh`

| # | Linha | Problema | Severidade |
|---|---|---|---|
| B1 | 15–21 | `log()` usa `$BLUE`, `$GREEN`, `$NC` etc., mas as cores não são definidas (deveria sourcear `lib/logger.sh`). As saídas ficam sem cor e o `echo -e` fica literal. | alta |
| B2 | 46–50 | No ramo `ID_LIKE=*debian*` define `PACKAGE_MANAGER="dnf"`. Errado: deveria ser `apt`. | alta |
| B3 | 104 | No ramo `dnf` loga "Installing vs-code with APT package manager". | baixa |
| B4 | 110 | `dnf check-update` retorna **100** quando há atualizações; com `set -e` o script morre antes do `dnf install`. Precisa de `|| true`. | alta |
| B5 | 32–35 | `exec sudo "$0"` reexecuta o script inteiro como root; `$HOME` vira `/root` e o script passa a rodar tudo como root. Melhor `sudo` por comando. | média |
| B6 | 82–99 | Já está como root, mas usa `sudo gpg`; inconsistente. | baixa |
| B7 | 80–120 | Não é idempotente: baixa a chave e reescreve o repo toda vez. Não checa se o `code` já existe. | média |
| B8 | — | Não instala extensões. Existe uma lista útil de 23 extensões na máquina (`code --list-extensions`). | lacuna |
| B9 | — | Não instala `wget`, `gpg`, `unzip` no ramo dnf antes de usar. | média |

### 2.4 `stow/zsh/.zshrc` e módulos

| # | Linha | Problema | Severidade |
|---|---|---|---|
| C1 | 45 | `. "$HOME/.local/bin/env"` sem guarda. Esse arquivo é gerado pelo instalador do `uv`; em máquina limpa não existe. | média |
| C2 | 51 | `PNPM_HOME="/home/$USER/.local/share/pnpm"` — funciona só se o home for `/home/<user>`; use `$HOME`. | baixa |
| C3 | 59 | `export PATH=/home/cmms/.opencode/bin:$PATH` — caminho absoluto do usuário atual. | alta |
| C4 | 62 | `source ~/.config/opencode/github-mcp.env` sem guarda e sem template no repo. Em máquina nova: erro a cada shell; e acopla segredo ao dotfile. | alta |
| C5 | 42 | Completions do Bun em `/home/cmms/.bun/_bun`. | média |
| C6 | `plugins.zsh:9` + `.zshrc:38` | O `plugins.zsh` sourceia `$ZSH/oh-my-zsh.sh` e o `.zshrc` sourceia de novo. OMZ e plugins carregam duas vezes. | média |
| C7 | `tools.zsh:19` | `eval "$(zoxide init zsh)"` sem checar se `zoxide` existe. | média |
| C8 | `tools.zsh:10,14` | Caminhos errados: `/home/.local/bin/uv` (deveria ser `$HOME/.local/bin/uv`, e `-f/-x`, não `-d`) e `/home/.cargo/bin`. Hoje esses blocos nunca executam. | média |
| C9 | `aliases.zsh:1` | `cd="z"` cria uma variável, não um alias. O alias real é criado em `tools.zsh`. | baixa |
| C10 | `env.zsh:6` | `BROWSER=brave`, mas o navegador padrão da máquina é Zen. | baixa |
| C11 | `completion.zsh` | `compinit` roda antes do OMZ, que pode rodar de novo. | baixa |

### 2.5 `stow/kitty/kitty.conf`

| # | Linha | Problema | Severidade |
|---|---|---|---|
| D1 | 2313 | `linux_display_server x11` força XWayland em sessão Wayland (GNOME atual e Hyprland). O `auto` é o padrão portátil; se precisar forçar, use variável por host. | média |

### 2.6 `lib/` (novo, não rastreado)

| # | Arquivo | Problema | Severidade |
|---|---|---|---|
| E1 | todos | Nada sourceia `lib/*.sh`; é código morto no estado atual. | alta |
| E2 | `detect_os.sh:6–7` | `popos` não é o ID real (Pop!_OS usa `pop`); falta `linuxmint`. | baixa |
| E3 | `pkg.sh:2–16` | Depende de `$DISTRO` global; o ramo Arch assume `yay`; `pkg_update` não trata distro desconhecida e usa `--sudoloop --timeupdate`. | média |
| E4 | `logger.sh` | Depende de `$LOG_FILE` definido pelo chamador; se não existir, escreve em lugar nenhum (ou falha). | baixa |
| E5 | `utils.sh` | `error_exit` depende de `log`. | baixa |

A separação em `lib/` é boa; falta conectar e testar.

### 2.7 `scripts/nf-install.sh` (novo)

| # | Linha | Problema | Severidade |
|---|---|---|---|
| F1 | 7 | `sudo dnf install fontconfig` trava o script em Fedora; em Arch/Debian falha. | alta |
| F2 | 5–13 | `FONTS_DIR=.local/share/fonts` é relativo; só funciona por causa do `cd ~` anterior. O `cd "$FONTS_DIR"` seguido de `cd ~` é inútil. | média |
| F3 | 9 | Instala só Meslo; o `setup.sh` valida JetBrains Mono também. | média |
| F4 | 9 | Versão fixa `v3.4.0`; sem checksum, sem fallback para `curl`. | baixa |
| F5 | 8–11 | Não checa `wget`/`unzip` antes de usar. | média |
| F6 | 1–3 | Só `set -e`; falta `set -u` e `pipefail`. | baixa |

### 2.8 `.env.example` (novo)

Vazio. Deve listar pelo menos:

```sh
GITHUB_PERSONAL_ACCESS_TOKEN=
NEON_API_KEY=
LANGFUSE_PUBLIC_KEY=
LANGFUSE_SECRET_KEY=
LANGFUSE_BASE_URL=https://us.cloud.langfuse.com
PLANE_API_TOKEN=
```

---

## 3. Inventário: dotfiles na máquina e fora do repo

### 3.1 Alta prioridade — portáteis, sem segredo (adicionar ao stow)

| Caminho | Tamanho | O que é | Destino sugerido |
|---|---|---|---|
| `~/.tmux.conf` | 794 B | prefixo `C-a`, splits, mouse, TPM + tmux-oasis | `stow/tmux/.tmux.conf` |
| `~/.gitconfig` | 87 B | nome, e-mail, `defaultBranch=main` | `stow/git/.gitconfig` |
| `~/.config/btop/btop.conf` | 11 KB | tema, boxes, update 2 s | `stow/btop/.config/btop/btop.conf` |
| `~/.config/herdr/config.toml` | 16 KB | tema catppuccin, prefixo `ctrl+a`, defaults | `stow/herdr/.config/herdr/config.toml` |
| `~/.config/gh/config.yml` | 2 KB | protocolo, alias `co`, prompt | `stow/gh/.config/gh/config.yml` |
| `~/.config/Code/User/settings.json` | 317 B | format-on-save, Prettier, Python | `stow/vscode/.config/Code/User/settings.json` |
| `~/.config/opencode/tui.jsonc` | 43 B | plugin da sessão TUI | `stow/opencode/...` |
| `~/.config/opencode/cli.json` | 352 B | tema, diffs, plugins — o opencode reescreve em runtime | `templates/opencode/cli.json.example` (não stowado) |
| `~/.config/opencode/plugins/herdr-agent-state.js` | 6,5 KB | integração Herdr | `stow/opencode/...` |
| `~/.config/opencode/plugins/ai-memory-opencode2.ts` | 65 KB | integração ai-memory | `stow/opencode/...` |
| `~/.config/opencode/herdr-opencode/tui.js` | 219 B | plugin TUI | `stow/opencode/...` |
| `~/.config/opencode/herdr-tui-session.js` | 21 KB | sessão TUI | `stow/opencode/...` |
| `~/.config/opencode/skills/adr-records/SKILL.md` | — | skill | `stow/opencode/...` |
| `~/.npmrc` | 22 B | `allow-scripts=9router` | `stow/misc/.npmrc` |
| `~/.tool-versions` | 11 B | `nodejs lts` | `stow/misc/.tool-versions` |
| `~/.config/ghostty/config.ghostty` | 25 B | `theme = Catppuccin Mocha` | renomear para `~/.config/ghostty/config` |
| `~/.bash_profile`, `~/.profile`, `~/.zshenv` | ~260 B | PATH de cargo/local | `stow/bash/...` (opcional) |

### 3.2 Exigem sanitização antes de entrar no repo

| Caminho | Risco | Ação |
|---|---|---|
| `~/.config/opencode/opencode.jsonc` | contém `Authorization: Bearer napi_...` (Neon), linha 41 | trocar por `{env:NEON_API_KEY}` |
| `~/.config/opencode/opencode-langfuse.json` | `publicKey` + `secretKey` (`sk-lf-...`) | usar `{env:LANGFUSE_*}` ou template |
| `~/.config/opencode/github-mcp.env` | `GITHUB_PERSONAL_ACCESS_TOKEN=...` | template `.env.example`; não versionar |
| `~/.config/ai-memory/config.toml` | `token_pepper` na linha 295 | remover antes de versionar; gerar de novo na instalação |
| `~/.claude/settings.json` | hook com `/home/cmms/.claude/hooks/...` | trocar por `$HOME` |
| `~/.ssh/config` | nomes de hosts e `IdentityFile` | versionar só o template, sem chaves |
| `~/.config/gh/hosts.yml` | usuário GitHub (token fica no keyring) | opcional/template |

### 3.3 Específicos da máquina — não versionar ou só documentar

| Caminho | Motivo |
|---|---|
| `~/.bashrc` | base do Fedora + env; sobrescrever pode quebrar distro |
| `~/.config/mimeapps.list` | IDs `userapp-Zen-*`, `chatgpt.desktop` que podem não existir |
| `~/.config/user-dirs.dirs` | gerado pelo xdg-user-dirs |
| `~/.config/QtProject.conf` | último diretório visitado |
| `~/.config/jgit/config` | tuning de filesystem da máquina |
| `~/.config/gtk-3.0/bookmarks` | caminhos `/home/cmms/*` |
| `~/.config/fish/conf.d/uv.env.fish` | gerado pelo uv |
| `~/.config/uv/uv-receipt.json` | gerado pelo uv |
| `~/.config/lazygit/config.yml` | vazio |
| `~/.local/bin/env`, `~/.cargo/env` | gerados por instaladores; melhor guardar o `source` |
| `~/.local/share/applications/*.desktop` | launchers específicos (Zen, Obsidian) |
| `~/.fonts/{Roboto,CustomTkinter}` | binários; opcional script de fontes |
| `~/.local/share/fonts/Meslo*` | já coberto por script de Nerd Fonts |
| `~/.config/background` (4,7 MB) | wallpaper; já existe `wallpapers/cool-bg.jpg` |
| `~/.tmux/plugins/*` | instalar TPM + tmux-oasis via script |

### 3.4 Segredos e estado — nunca versionar

| Caminho | Conteúdo |
|---|---|
| `~/.ssh/{github_key,carlosmms_key,authorized_keys,known_hosts*}` | chaves privadas / hosts |
| `~/.config/opencode/service.json` | senha em texto puro |
| `~/.config/opencode/secrets/plane-token-cmmsone` | token Plane |
| `~/.config/neon/credentials.json` | credencial Neon |
| `~/.codex/auth.json` | auth OpenAI |
| `~/.claude.json`, `~/.claude/{history.jsonl,projects,sessions}` | histórico e sessões |
| `~/.zsh_history`, `~/.bash_history`, `~/.python_history`, `~/.psql_history`, `~/.viminfo` | histórico |
| `~/.config/Code/User/{globalStorage,workspaceStorage,History}` | estado do VS Code |
| `~/.config/{Codex,obsidian,BraveSoftware,mozilla,zen}` | perfis/estado de apps |

### 3.5 Divergências encontradas (e o que foi feito)

1. **nvim**: a cópia viva tinha `lua/plugins/colorscheme.lua` (vesper + catppuccin) e
   `lazyvim.json` com extras de TypeScript/Docker/JSON; o `stow/nvim` estava com a
   versão antiga. O repo foi sincronizado e agora está linkado.
2. **waybar**: `stow/waybar/.config/waybar/config.jsonc.bak` estava versionado; foi
   removido.
3. **`.config/hypr` e `.config/waybar` na raiz do repo**: symlinks de conveniência
   sem uso pelos apps; removidos.
4. **zsh**: `plugins.zsh` e `.zshrc` sourceavam OMZ duas vezes; corrigido.
5. **packages.txt**: era 100% Arch. Agora há `packages/{arch,debian,fedora}.txt`,
   `packages/fedora-optional.txt` e `packages/fedora-wayland.txt`; `packages.txt`
   virou symlink para `packages/arch.txt`.
6. **noctalia**: `stow/noctalia/settings.json` ainda contém `/home/cmms/.face` e
   `/home/cmms/wallpapers`. Se o outro notebook usar outro usuário, ajuste esses
   caminhos antes de aplicar o perfil wayland.

---

## 4. Segredos encontrados (ação recomendada)

Todos estavam em texto puro no disco. Se este repo ou o disco for compartilhado, **rotacione**:

- Neon API key (`napi_...`) em `~/.config/opencode/opencode.jsonc`
- Langfuse secret (`sk-lf-...`) em `~/.config/opencode/opencode-langfuse.json`
- Senha do `opencode` em `~/.config/opencode/service.json`
- Token GitHub em `~/.config/opencode/github-mcp.env`
- Token Plane em `~/.config/opencode/secrets/plane-token-cmmsone`
- `token_pepper` do ai-memory em `~/.config/ai-memory/config.toml`
- Chaves SSH privadas em `~/.ssh/`
- `~/.codex/auth.json`

Nunca copiar esses arquivos para `stow/`. No repo, entrar apenas como `.example` com
placeholders ou referências `{env:...}`.

---

## 5. O que foi implementado

1. **Dotfiles faltantes empacotados** em `stow/` (seção 3.1) e `nvim` sincronizado.
2. **Pacotes por OS/perfil**:
   - `packages/arch.txt`, `packages/fedora.txt`, `packages/fedora-optional.txt`,
     `packages/fedora-wayland.txt`; `packages.txt` → symlink para `arch.txt`.
   - Perfil `core`: zsh, git, tmux, btop, nvim, vscode, herdr, opencode, ssh etc.
   - Perfil `wayland` = core + hypr, waybar, noctalia (só em Hyprland).
3. **`lib/` ligado no `setup.sh`**:
   - `detect_distro` → `arch|fedora|debian`
   - `pkg_install` / `pkg_update`
   - `log` / `command_exists` / `error_exit`
4. **`scripts/stow.sh` reescrito**:
   - backup automático de arquivos reais (`~/.dotfiles-backup-*`);
   - stow pacote a pacote, pulando o que não existe;
   - `--adopt` opcional, `--dry-run`, `--exclude`, `--no-folding`;
   - não stowar Wayland em GNOME por padrão.
5. **Fontes**: script único cross-distro, Meslo + JetBrains Mono, `fc-cache`.
6. **VS Code**: instalação corrigida + extensões de `vscode/extensions.txt`.
7. **Segredos**: `.env.example` na raiz + `~/.config/opencode/.env` (modo 600) e
   `source` condicional no `.zshrc`.
8. **README** com o passo a passo do notebook novo.
9. **`scripts/import.sh`** para sincronizar máquina → repo, com dry-run e
   detecção de segredos.

Pendências reais: preencher/rotacionar os tokens no notebook novo, habilitar
COPRs opcionais e recriar as chaves SSH.

---

## 6. Checklist

- [ ] Rotacionar segredos expostos (Neon, Langfuse, GitHub, Plane, opencode)
- [x] Sincronizar `stow/nvim` com `~/.config/nvim`
- [x] Adicionar `stow/{tmux,git,btop,herdr,gh,vscode,opencode,bash,misc,...}`
- [x] Sanitizar `opencode.jsonc`, `claude/settings.json`; Langfuse/ai-memory ficam fora
- [x] Corrigir `zshrc` (paths absolutos, sources sem guarda, OMZ duplicado)
- [x] Corrigir `setup.sh` (multi-distro, flags, `((errors++))`, stow por perfil)
- [x] Corrigir `code-install.sh` (cores, ramo debian, `dnf check-update`)
- [x] Reescrever `nf-install.sh` (cross-distro + JetBrains)
- [x] Criar `packages/{arch,fedora}.txt`
- [x] Remover `waybar/config.jsonc.bak` e symlinks `.config/{hypr,waybar}`
- [x] Testar stow em `HOME=/tmp/testhome` antes de replicar
- [x] Criar `scripts/import.sh` para sincronização contínua
- [ ] Preencher/rotacionar `~/.config/opencode/.env` no notebook novo
- [ ] Habilitar COPRs opcionais e `gh auth login` no notebook novo
