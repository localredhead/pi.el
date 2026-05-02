# pi.el

Run [Pi](https://github.com/mariozechner/pi-coding-agent) coding agent inside Emacs using
`vterm` (emacs-libvterm) — the full TUI, including ANSI cursor positioning,
interactive menus, and mouse support, rendered correctly.

Born from frustration with comint-based Pi integrations that break the TUI.
VTERM is a real terminal emulator (backed by libvterm C library), so Pi looks
and behaves exactly like it does in a native terminal.

## Requirements

- Emacs 28.1+
- [vterm](https://github.com/akermu/emacs-libvterm) — install from MELPA
- `pi` installed and on your `exec-path`

## Installation

### Via package.el (local repo)

Add the directory to your `load-path`:

```elisp
(add-to-list 'load-path "~/path/to/pi.el/")
(require 'pi)
```

Or put it in one of your `package-directory-list` dirs and `package-install-file`.

### Via straight.el

```elisp
(use-package pi
  :straight (:type git :host github :repo "localredhead/pi.el"
                   :files ("*.el")))
```

### Via use-package

```elisp
(use-package pi
  :load-path "~/path/to/pi.el"  ; or omit if installed via MELPA
  :config
  ;; Define your own keybindings — pi.el ships with none by default
  (global-set-key (kbd "C-c p p") #'pi)
  (global-set-key (kbd "C-c p t") #'pi-toggle)
  (global-set-key (kbd "C-c p s") #'pi-select))
```

## Usage

| Command | Description |
|---------|-------------|
| `M-x pi` | Launch Pi for current project (reuses existing session) |
| `C-u M-x pi` | Force a fresh Pi session |
| `M-x pi-other-window` | Launch Pi in another window |
| `M-x pi-cwd` | Launch Pi using current directory (no project lookup) |
| `M-x pi-restart` | Kill current session and start fresh |
| `M-x pi-select` | Switch to Pi session, create if none exists |

### Project detection

Pi launches from the project root, automatically detected via:

1. **Emacs `project.el`** (built-in, Emacs 28+)
2. **Projectile** `projectile-project-root` (if available)

Falls back to `default-directory` if neither finds a project.

### Window placement

Default opens in the same window. Control it with:

```elisp
;; Always in a bottom side-window
(setq pi-display-function #'display-buffer)
(pi-setup-display-rules)

;; Or any display function
(setq pi-display-function #'switch-to-buffer)
```

### Auto-launch behavior

After vterm starts, the package waits and then sends the `pi` command.

```elisp
;; Don't auto-launch — just open a shell in the project dir
(setq pi-auto-launch-command nil)

;; Increase wait time for slow shells
(setq pi-startup-wait 2.0)

;; Use a different shell
(setq pi-shell "/usr/bin/env zsh")
```

### Minor mode

Pi buffers get `pi-mode` automatically,
which gives them a mode line indicator (` Pi`)
and runs `pi-mode-hook` after enabling.

No keybindings are defined by default — define your own in your config:

### Customization

`M-x customize-group RET pi RET`

| Variable | Default | Description |
|----------|---------|-------------|
| `pi-binary` | `"pi"` | Command to launch Pi |
| `pi-shell` | `shell-file-name` | Shell for vterm |
| `pi-buffer-name` | `"*pi:%s*"` | Buffer name format |
| `pi-auto-launch-command` | `t` | Auto-send `pi` after shell starts |
| `pi-startup-wait` | `1.0` | Seconds delay before sending command |
| `pi-use-project-root` | `t` | CD to project root first |
| `pi-display-function` | `pop-to-buffer-same-window` | How to display the buffer |
| `pi-pre-launch-hook` | `(pi--maybe-cd-project)` | Hook before launching Pi |
| `pi-mode-line` | `" Pi"` | Mode line indicator |

## Why vterm over comint?

Pi uses ncurses-style TUI rendering: ANSI cursor movement, full-screen
repaints, color attributes, and mouse-aware menus. `comint-mode` can't handle
this — it's line-oriented and strips escape codes. `vterm` uses libvterm (the
same library used by GNOME Terminal, xfce4-terminal, etc.), so Pi renders
correctly.

## Where pi.el fits

One Emacs package already provides Pi integration on MELPA:

- **[dnouri/pi-coding-agent][]** — A native Emacs chat interface with Markdown
  rendering, tree-sitter syntax highlighting, transient menus, chat history
  with fork/search. 

pi.el fills a different niche: a **lightweight vterm wrapper** that shows Pi's
native TUI exactly as it appears in a real terminal — ANSI cursor positioning,
interactive menus, mouse support, the works. It runs on **Emacs 28.1+**.

|                   | **pi.el**                                 | **dnouri/pi-coding-agent**                 |
|-------------------|-------------------------------------------|--------------------------------------------|
| Interface         | vterm — Pi's native TUI unchanged         | Native Emacs buffers (chat + input)        |
| Rendering         | Raw ANSI/ncurses — what Pi ships          | Markdown + tree-sitter syntax highlighting |
| Requirements      | Emacs 28.1+, vterm                        | Emacs 29+, tree-sitter, C compiler         |
| Pi TUI support    | Full — menus, mouse, ncurses all intact   | Pi is consumed and re-rendered             |
| Project awareness | Auto-cds to project root via `project.el` | Works from current directory               |
| Session model     | Hides/restores vterm — state survives     | Opens/closes Emacs buffers per session     |
| Extra deps        | vterm only                                | transient, md-ts-mode, markdown-table-wrap |

Choose **pi.el** if you want Pi's Tui experience unmodified, or you're on
Emacs 28.x. Choose **dnouri** if you want a richer Emacs-native UI and have
Emacs 29+.

[dnouri/pi-coding-agent]: https://github.com/dnouri/pi-coding-agent

## License

Apache 2.0
