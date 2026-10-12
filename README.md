# Doom Emacs config

Set up to feel like my Neovim (NvChad) config. `SPC` is the leader key, like `<leader>` in nvim.
Press `SPC` and wait to see every leader key; `SPC h b b` searches all keybinds.

## Dashboard

| Key | Action |
|---|---|
| `SPC b h` | Back to the dashboard |
| `f` | Find file *(on the dashboard)* |
| `n` | New file *(on the dashboard)* |
| `q` | Quit *(on the dashboard)* |

## Files & projects

| Key | Action |
|---|---|
| `SPC SPC` / `SPC p f` | Find file in project |
| `SPC f F` | Find file under the current directory (like Telescope `find_files`) |
| `SPC .` / `SPC f f` | Browse / open a file by path |
| `SPC f r` | Recent files |
| `SPC f s` | Save file |
| `SPC p p` | Switch project |
| `SPC s p` / `SPC /` | Search text in project (like Telescope `live_grep`) |
| `SPC s s` | Search in current file |

Finders and project search skip anything listed in `.findignore` (gitignore syntax).
Dotfiles and `.gitignore`'d files still show up.

## File tree (Treemacs, nvim-tree keys)

| Key | Action |
|---|---|
| `Ctrl+n` | Toggle the tree |
| `SPC e` | Focus the tree (opens it if closed) |

Inside the tree:

| Key | Action |
|---|---|
| `Enter` / `o` | Open file / expand folder |
| `Tab` | Preview (open, keep cursor in tree) |
| `Ctrl+v` / `Ctrl+x` | Open in vertical / horizontal split |
| `a` | New file (end with `/` for a folder) |
| `d` / `r` | Delete / rename |
| `c` / `x` / `p` | Copy / cut / paste |
| `y` / `Y` / `gy` | Copy name / relative path / absolute path |
| `H` / `I` | Toggle dotfiles / gitignored files |
| `-` / `Ctrl+]` | Tree root up / into folder |
| `P` / `Backspace` / `W` | Go to parent / collapse parent / collapse all |
| `R` / `s` / `q` | Refresh / open with system app / close |

The tree resizes to fit the longest visible name (min 15 columns).

## Buffers, windows & workspaces

| Key | Action |
|---|---|
| `SPC ,` / `SPC b b` | Switch buffer |
| `SPC b n` / `SPC b p` | Next / previous buffer |
| `SPC b k` | Close buffer |
| `SPC b N` | New empty buffer |
| `SPC w v` / `SPC w s` | Split vertically / horizontally |
| `SPC w h/j/k/l` | Move to window left/down/up/right |
| `SPC w d` | Close window |
| `SPC TAB TAB` | Show workspaces (projects open in their own workspace) |
| `SPC TAB n` / `SPC TAB d` | New / delete workspace |

## Build & run

| Key | Action |
|---|---|
| `SPC r b` | Build project |
| `SPC r c` | Build & run project |
| `SPC r t` | Close the output panel / reopen the last one |

Detects CMake, Maven, Gradle, Cargo or Python from the current file (or the tree node under the
cursor). Output opens in a panel at the bottom that sizes itself to the output (6 lines minimum,
half the screen at most); `Enter` on an error jumps to it, `q` in the panel closes it. New CMake
builds default to C++23. Defined in `build.el`.

## Code (LSP via Eglot)

| Key | Action |
|---|---|
| `g d` | Peek at definition in a panel at the bottom (`g d` again closes it) |
| `SPC c d` | Go to definition |
| `g D` / `SPC c D` | Find references |
| `K` | Documentation at point |
| `SPC c a` | Code actions |
| `SPC c r` | Rename symbol |
| `SPC c f` | Format buffer / region |
| `SPC c x` | List errors / warnings |
| `Ctrl+o` | Jump back |

LSP is on for C/C++ (clangd), Python (pylsp), Rust (rust-analyzer) and Java (jdtls).
Servers installed by nvim's Mason are found too. The status line shows the active server.

## Editing & misc

| Key | Action |
|---|---|
| `;` | Command line (same as `:`) |
| `SPC g g` | Magit (git status) |
| `SPC t w` | Toggle line wrapping |
| `SPC t l` | Toggle line numbers |
| `SPC x` | Scratch buffer |
| `SPC h r r` | Reload config |
| `SPC q r` | Restart Emacs |
| `SPC q q` | Quit |

Files autosave after 1 second without typing (like nvim's auto-save.nvim). `:q` and its variants
quit without a confirmation; if something is unsaved, Emacs offers to save it first (`:q!` discards).

The mouse works in the terminal (`emacs -nw`); hold **Shift** while dragging to use the
terminal's own selection.

## Files in this config

| File | What it is |
|---|---|
| `init.el` | Enabled Doom modules (run `doom sync` after changing) |
| `config.el` | Personal settings and keybinds |
| `packages.el` | Extra packages |
| `build.el` | `SPC r b` / `SPC r c` build & run |
| `discord.el` | Discord Rich Presence, mirroring nvim's `cord.lua` |
| `cord-icons.el` | File type → Discord icon table |
| `icons/minecraft/` | Discord icons (served from GitHub, so push new ones) |
| `.findignore` | Paths hidden from the file finders and project search |
