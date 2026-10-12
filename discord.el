;;; $DOOMDIR/discord.el --- Discord Rich Presence (elcord) -*- lexical-binding: t; -*-
;;
;; Mirrors ~/.config/nvim/lua/configs/cord.lua:
;;   Line 1 (details): file, cursor, evil state, scope, diagnostics
;;   Line 2 (state):   project, branch, LSP, buffers, tmux session
;; plus a per-project persistent timer, a "View Repository" button, and
;; hiding presence entirely for secret files.

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

(defun +elcord--special-line ()
  (let ((name (+elcord--project-name)))
    (cond
     ((derived-mode-p '+doom-dashboard-mode) "Home")
     ((or (derived-mode-p 'magit-mode) (bound-and-true-p git-commit-mode))
      (concat "Committing changes in " name))
     ((derived-mode-p 'dired-mode) (concat "Browsing files in " name))
     ((derived-mode-p 'help-mode 'helpful-mode 'Info-mode 'Man-mode 'woman-mode 'apropos-mode)
      "Reading Emacs docs")
     ((derived-mode-p 'flycheck-error-list-mode 'flymake-diagnostics-buffer-mode)
      (concat "Fixing problems in " name))
     ((derived-mode-p 'debugger-mode 'gud-mode) (concat "Debugging in " name))
     ((derived-mode-p 'vterm-mode 'eshell-mode 'term-mode 'shell-mode 'compilation-mode)
      (concat "Running commands in " name))
     ((derived-mode-p 'org-agenda-mode) "Taking notes in Org"))))

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
    (let ((url (+elcord--repo-url)))
      `(("details" . ,(or (+elcord--special-line) (+elcord--file-line)))
        ("state" . ,(+elcord--workspace-line))
        ("timestamps" ("start" . ,(+elcord--start-timestamp)))
        ,@(when (stringp url)
            `(("buttons" . [(("label" . "View Repository") ("url" . ,url))])))))))

(defun +elcord--update-presence-a ()
  "Re-send presence whenever anything shown changes, not just buffer/line."
  (let ((buf (window-buffer (or (minibuffer-selected-window) (selected-window)))))
    (unless (elcord--buffer-boring-p (buffer-name buf))
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
           ("args" . (("activity" . (("assets" . ,(elcord--mode-icon-and-text))
                                     ,@+elcord--activity))
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
  ;; Timer only counts active time; force a resend when coming back
  (advice-add 'elcord--start-idle :before (lambda (&rest _) (+elcord--commit-time)))
  (advice-add 'elcord--cancel-idle :before (lambda (&rest _) (setq +elcord--activity nil)))
  (add-hook 'kill-emacs-hook #'+elcord--commit-time)
  (elcord-mode +1))
