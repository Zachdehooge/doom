;;; $DOOMDIR/discord.el --- Discord Rich Presence (elcord) -*- lexical-binding: t; -*-
;;
;; Mirrors ~/.config/nvim/lua/configs/cord.lua:
;;   Line 1 (details): file, cursor, evil state, scope, diagnostics
;;   Line 2 (state):   project, branch, LSP, buffers, tmux session
;; plus a per-project persistent timer, a "View Repository" button, and
;; hiding presence entirely for secret files. Icons are cord.nvim's
;; minecraft theme, stored in icons/minecraft/ (see the Icons section).

(defconst +elcord-max-len 128 "Discord's per-line limit.")

(defvar +elcord-blacklist '("\\.env\\'" "/\\.env[^/]*\\'" "/\\.ssh/")
  "Regexps on `buffer-file-name' that hide presence entirely.")

(defvar +elcord--activity nil
  "Activity computed on the last tick; `:hidden' means clear presence.")

(defun +elcord--trim (s)
  (if (<= (length s) +elcord-max-len) s
    (concat (substring s 0 (1- +elcord-max-len)) "…")))

(defun +elcord--join (parts)
  (+elcord--trim (string-join (delq nil parts) " · ")))

;;; Line 1 pieces

(defun +elcord--mode ()
  (when (bound-and-true-p evil-local-mode)
    (pcase evil-state
      ('normal "NORMAL") ('insert "INSERT") ('visual
       (pcase (evil-visual-type) ('line "V-LINE") ('block "V-BLOCK") (_ "VISUAL")))
      ('replace "REPLACE") ('emacs "EMACS") ('motion "MOTION")
      ('operator "OPERATOR") (s (upcase (symbol-name s))))))

(defun +elcord--scope ()
  "Name of the enclosing function/class (imenu or tree-sitter)."
  (require 'which-func)
  (when-let* ((name (ignore-errors (which-function))))
    (concat "in " (replace-regexp-in-string "(.*" "" name) "()")))

(defun +elcord--diagnostics ()
  (let ((errs 0) (warns 0))
    (cond
     ((bound-and-true-p flycheck-mode)
      (dolist (c (flycheck-count-errors flycheck-current-errors))
        (pcase (car c)
          ('error (setq errs (cdr c)))
          ('warning (setq warns (cdr c))))))
     ((bound-and-true-p flymake-mode)
      (dolist (d (flymake-diagnostics))
        (pcase (flymake--severity (flymake-diagnostic-type d))
          (3 (cl-incf errs))
          (2 (cl-incf warns))))))
    (let ((parts (delq nil (list (and (> errs 0) (format "%dE" errs))
                                 (and (> warns 0) (format "%dW" warns))))))
      (and parts (string-join parts " ")))))

(defun +elcord--file-line ()
  (+elcord--join
   (list (concat (if buffer-read-only "Viewing " "Editing ")
                 (if buffer-file-name (file-name-nondirectory buffer-file-name) (buffer-name))
                 (and buffer-file-name (buffer-modified-p) " [+]")
                 (and buffer-read-only " [RO]"))
         (format "Ln %d/%d:%d" (line-number-at-pos)
                 (line-number-at-pos (point-max)) (1+ (current-column)))
         (+elcord--mode)
         (+elcord--scope)
         (+elcord--diagnostics))))

;;; Line 2 pieces

(defun +elcord--project-root ()
  (or (and (fboundp 'doom-project-root) (doom-project-root))
      default-directory))

(defun +elcord--project-name ()
  (if (and (fboundp 'doom-project-p) (doom-project-p))
      (doom-project-name)
    (file-name-nondirectory (directory-file-name (expand-file-name default-directory)))))

(defun +elcord--branch ()
  (when-let* ((b (or (and (fboundp 'magit-get-current-branch)
                          (ignore-errors (magit-get-current-branch)))
                     (and vc-mode (replace-regexp-in-string
                                   "\\`[^:-]*[:-]" "" (substring-no-properties vc-mode))))))
    (unless (string-empty-p b) b)))

(defun +elcord--lsp ()
  (cond ((and (fboundp 'eglot-current-server) (eglot-current-server))
         (let ((s (eglot-current-server)))
           (or (plist-get (eglot--server-info s) :name)
               (eglot-project-nickname s))))
        ((bound-and-true-p lsp-mode)
         (mapconcat (lambda (w) (symbol-name (lsp--client-server-id (lsp--workspace-client w))))
                    (lsp-workspaces) ","))))

(defvar +elcord--tmux-session 'unset)
(defun +elcord--tmux ()
  "Cached tmux session name; no-op outside tmux."
  (when (eq +elcord--tmux-session 'unset)
    (setq +elcord--tmux-session
          (and (getenv "TMUX")
               (string-trim (shell-command-to-string "tmux display-message -p '#S'")))))
  (and +elcord--tmux-session (concat "tmux:" +elcord--tmux-session)))

(defun +elcord--workspace-line ()
  (let ((branch (+elcord--branch)))
    (+elcord--join
     (list (concat "In " (+elcord--project-name) (and branch (format " (%s)" branch)))
           (+elcord--lsp)
           (format "%d bufs" (length (if (fboundp 'doom-real-buffer-list)
                                         (doom-real-buffer-list)
                                       (cl-remove-if-not #'buffer-file-name (buffer-list)))))
           (+elcord--tmux)))))

;;; Non-file buffers (cord.nvim's file_browser / vcs / docs / ...)

(defvar +elcord-special-buffers
  '(((+dashboard-mode +doom-dashboard-mode)    dashboard      "dashboard"  "Doom Dashboard")
    ((magit-mode)                              vcs            "git"        "Magit")
    ((treemacs-mode)                           file_browser   "folder"     "Treemacs")
    ((dired-mode)                              file_browser   "folder"     "Dired")
    ((package-menu-mode)                       plugin_manager "plugin"     "package.el")
    ((lsp-log-io-mode eglot-list-connections-mode) lsp        "server"     "LSP")
    ((help-mode helpful-mode Info-mode apropos-mode) docs     "book"       "Emacs")
    ((Man-mode woman-mode)                     docs           "book"       "Man pages")
    ((org-mode org-agenda-mode)                notes          "org"        "Orgmode")
    ((debugger-mode)                           debug          "bug"        "Debugger")
    ((gud-mode)                                debug          "bug"        "GNU Debugger")
    ((dap-ui-repl-mode)                        debug          "bug"        "DAP")
    ((ert-results-mode)                        test           "test"       "ERT")
    ((flycheck-error-list-mode)                diagnostics    "diagnostic" "Flycheck")
    ((flymake-diagnostics-buffer-mode)         diagnostics    "diagnostic" "Flymake")
    ((tetris-mode)                             games          "controller" "Tetris")
    ((snake-mode)                              games          "controller" "Snake")
    ((gomoku-mode)                             games          "controller" "Gomoku")
    ((pong-mode)                               games          "controller" "Pong")
    ((solitaire-mode)                          games          "controller" "Solitaire")
    ((bubbles-mode)                            games          "controller" "Bubbles")
    ((5x5-mode)                                games          "controller" "5x5")
    ((dun-mode)                                games          "controller" "Dunnet")
    ((vterm-mode)                              terminal       "shell"      "vterm")
    ((eshell-mode)                             terminal       "shell"      "Eshell")
    ((term-mode)                               terminal       "shell"      "Term")
    ((shell-mode)                              terminal       "shell"      "Shell")
    ((compilation-mode)                        terminal       "shell"      "Compilation"))
  "(MODES TYPE ICON NAME), like cord.nvim's mappings.lua.")

(defun +elcord--special ()
  "(TYPE ICON NAME) for a non-file buffer, or nil."
  (if (bound-and-true-p git-commit-mode)
      '(vcs "git" "Git")
    (cl-loop for (modes . rest) in +elcord-special-buffers
             when (apply #'derived-mode-p modes) return rest)))

(defun +elcord--special-line (special)
  "Text for SPECIAL, using the same wording as cord.lua."
  (pcase-let ((`(,type ,_ ,name) special))
    (pcase type
      ('dashboard "Home")
      ('file_browser (concat "Browsing files in " name))
      ('plugin_manager (concat "Managing plugins in " name))
      ('lsp (concat "Configuring LSP in " name))
      ('docs (concat "Reading " name " docs"))
      ('vcs (concat "Committing changes in " name))
      ('notes (concat "Taking notes in " name))
      ('debug (concat "Debugging in " name))
      ('test (concat "Running tests in " name))
      ('diagnostics (concat "Fixing problems in " name))
      ('terminal (concat "Running commands in " name))
      ('games (concat "Playing " name)))))

;;; Icons: cord.nvim's minecraft theme, kept in $DOOMDIR/icons/minecraft/.
;; Discord only loads images by URL, so they're served from this repo on GitHub;
;; a new icon shows up once it's pushed. Map files to it in cord-icons.el.

(load! "cord-icons")

(defconst +elcord-icon-dir (expand-file-name "icons/minecraft/" doom-user-dir))
(defconst +elcord-icon-url
  "https://raw.githubusercontent.com/Zachdehooge/doom/main/icons/minecraft/%s.png")

(defun +elcord--icon-url (icon)
  "URL for ICON, falling back to the plain text icon if there's no local PNG."
  (format +elcord-icon-url
          (if (file-exists-p (expand-file-name (concat icon ".png") +elcord-icon-dir))
              icon
            "text")))

(defvar +elcord-mode-icons
  '((emacs-lisp-mode "lisp" . "Emacs Lisp")
    (lisp-interaction-mode "lisp" . "Emacs Lisp")
    (sh-mode "shell" . "Shell script")
    (bash-ts-mode "shell" . "Shell script")
    (fish-mode "fishshell" . "Fish")
    (python-mode "python" . "Python")
    (python-ts-mode "python" . "Python"))
  "Fallback for files whose name/extension isn't in cord's table (e.g. shebang scripts).")

(defun +elcord--file-icon ()
  "(ICON . TOOLTIP) for the current buffer, using cord's filename/extension table."
  (let ((name (downcase (file-name-nondirectory (or buffer-file-name (buffer-name))))))
    (or (cdr (assoc name +elcord-cord-filename-icons))
        ;; Longest suffix first, so foo.service.ts beats foo.ts
        (cl-loop for i = (string-search "." name) then (string-search "." name (1+ i))
                 while i
                 thereis (cdr (assoc (substring name (1+ i)) +elcord-cord-extension-icons)))
        (cl-loop for (mode . icon) in +elcord-mode-icons
                 when (derived-mode-p mode) return icon)
        (cons "text" (format-mode-line mode-name)))))

(defun +elcord--assets (special)
  "Large minecraft icon for the file or SPECIAL buffer, small Emacs icon."
  (let ((icon (cond (elcord--idle-status '("idle" . "💤"))
                    (special (cons (nth 1 special) (nth 2 special)))
                    (t (+elcord--file-icon)))))
    `(("large_image" . ,(+elcord--icon-url (car icon)))
      ("large_text" . ,(cdr icon))
      ("small_image" . ,(elcord--editor-icon))
      ("small_text" . ,(format "GNU Emacs %s" emacs-version)))))

;;; Persistent per-project timer (cord.nvim persistent_timer, mode = "active")

(defvar +elcord-time-file (concat doom-cache-dir "elcord-project-time.el"))
(defvar +elcord--project-time
  (or (ignore-errors (with-temp-buffer
                       (insert-file-contents +elcord-time-file)
                       (read (current-buffer))))
      (make-hash-table :test #'equal))
  "Project root -> seconds of active time across sessions.")
(defvar +elcord--current-project nil)
(defvar +elcord--since nil "`float-time' when the current project became active.")

(defun +elcord--commit-time ()
  (when (and +elcord--current-project +elcord--since)
    (cl-incf (gethash +elcord--current-project +elcord--project-time 0)
             (- (float-time) +elcord--since))
    (setq +elcord--since nil)
    (ignore-errors
      (with-temp-file +elcord-time-file
        (prin1 +elcord--project-time (current-buffer))))))

(defun +elcord--start-timestamp ()
  (let ((root (+elcord--project-root)))
    (unless (equal root +elcord--current-project)
      (+elcord--commit-time)
      (setq +elcord--current-project root))
    (unless +elcord--since (setq +elcord--since (float-time)))
    (floor (- +elcord--since (gethash root +elcord--project-time 0)))))

;;; Repository button

(defvar +elcord--repo-urls (make-hash-table :test #'equal))
(defun +elcord--repo-url ()
  (let ((root (+elcord--project-root)))
    (with-memoization (gethash root +elcord--repo-urls)
      (let* ((default-directory root)
             (remote (string-trim (shell-command-to-string
                                   "git config --get remote.origin.url 2>/dev/null"))))
        (cond ((string-empty-p remote) 'none)
              ((string-match "\\`\\(?:ssh://\\)?git@\\([^:/]+\\)[:/]\\(.+?\\)\\(?:\\.git\\)?\\'" remote)
               (format "https://%s/%s" (match-string 1 remote) (match-string 2 remote)))
              ((string-match "\\`\\(https?://\\)\\(?:[^@/]+@\\)?\\(.+?\\)\\(?:\\.git\\)?\\'" remote)
               (concat (match-string 1 remote) (match-string 2 remote)))
              (t 'none))))))

;;; Glue into elcord

(defun +elcord--compute ()
  (if (and buffer-file-name
           (cl-some (lambda (re) (string-match-p re buffer-file-name)) +elcord-blacklist))
      :hidden
    (let ((url (+elcord--repo-url))
          (special (+elcord--special)))
      `(("assets" . ,(+elcord--assets special))
        ("details" . ,(if special (+elcord--special-line special) (+elcord--file-line)))
        ("state" . ,(+elcord--workspace-line))
        ("timestamps" ("start" . ,(+elcord--start-timestamp)))
        ,@(when (stringp url)
            `(("buttons" . [(("label" . "View Repository") ("url" . ,url))])))))))

(defun +elcord--update-presence-a ()
  "Re-send presence whenever anything shown changes, not just buffer/line."
  (let ((buf (window-buffer (or (minibuffer-selected-window) (selected-window)))))
    ;; Treemacs' buffer name starts with a space, which elcord deems boring
    (unless (and (elcord--buffer-boring-p (buffer-name buf))
                 (not (eq (buffer-local-value 'major-mode buf) 'treemacs-mode)))
      (with-current-buffer buf
        (let ((activity (+elcord--compute)))
          (unless (equal activity +elcord--activity)
            (setq +elcord--activity activity)
            (elcord--try-update-presence (buffer-name) (point))))))))

(defun +elcord--set-presence-a ()
  (if (eq +elcord--activity :hidden)
      (elcord--empty-presence)
    (let ((nonce (format-time-string "%s%N")))
      (elcord--send-packet
       1 `(("cmd" . "SET_ACTIVITY")
           ("args" . (("activity" . ,+elcord--activity)
                      ("pid" . ,(emacs-pid))))
           ("nonce" . ,nonce))))))

(use-package! elcord
  :defer 2
  :config
  (setq elcord-refresh-rate 5           ; Discord allows ~5 updates / 20s
        elcord-idle-timer 600
        elcord-quiet t
        elcord-editor-icon "emacs_icon")
  (advice-add 'elcord--update-presence :override #'+elcord--update-presence-a)
  (advice-add 'elcord--set-presence :override #'+elcord--set-presence-a)
  ;; elcord's idle presence takes its icons from here
  (advice-add 'elcord--mode-icon-and-text :override (lambda () (+elcord--assets nil)))
  ;; Timer only counts active time; force a resend when coming back
  (advice-add 'elcord--start-idle :before (lambda (&rest _) (+elcord--commit-time)))
  (advice-add 'elcord--cancel-idle :before (lambda (&rest _) (setq +elcord--activity nil)))
  (add-hook 'kill-emacs-hook #'+elcord--commit-time)
  (elcord-mode +1))
