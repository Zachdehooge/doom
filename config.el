;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-matrix)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Discord Rich Presence, matching nvim cord.lua
(load! "discord")

;;; ---------------------------------------------------------------------------
;;; Dashboard, matching nvim's alpha.lua
;;; ---------------------------------------------------------------------------
(setq fancy-splash-image nil              ; ASCII banner in the GUI too
      +dashboard-ascii-banner-fn
      (lambda ()
        (propertize
         (string-join
          '("         (\\,/)                    "
            "         oo   '''//,        _      "
            "       ,/_;~,       \\,    / '      "
            "       \"'   \\    (    \\    !       "
            "             ',|  \\    |__.'       "
            "             '~  '~----''          "
            "                                   "
            "       Keith, the C++ rat          "
            "   \"segfaults build character\"     ")
          "\n")
         'face '+dashboard-banner))
      +dashboard-functions '(+dashboard-widget-banner +dashboard-widget-shortmenu))

(defun my/dashboard-new-file ()
  "Like nvim's `:ene | startinsert'."
  (interactive)
  (+default/new-buffer)
  (when (bound-and-true-p evil-local-mode) (evil-insert-state)))

(setq +dashboard-menu-sections
      '(("Find file"
         :icon (nerd-icons-octicon "nf-oct-search" :face '+dashboard-menu-title)
         :key "f"
         :action +default/find-file-under-here)
        ("New file"
         :icon (nerd-icons-octicon "nf-oct-file" :face '+dashboard-menu-title)
         :key "n"
         :action my/dashboard-new-file)
        ("Quit"
         :icon (nerd-icons-octicon "nf-oct-sign_out" :face '+dashboard-menu-title)
         :key "q"
         :action save-buffers-kill-terminal)))

(map! :map +dashboard-mode-map
      :n "f" #'+default/find-file-under-here
      :n "n" #'my/dashboard-new-file
      :n "q" #'save-buffers-kill-terminal)

;;; ---------------------------------------------------------------------------
;;; File tree (treemacs), with nvim-tree / NvChad keybinds
;;; ---------------------------------------------------------------------------
;; Same filters as nvim-tree: show dotfiles, hide .git and .idea
(setq treemacs-show-hidden-files t)
(after! treemacs
  (add-to-list 'treemacs-ignored-file-predicates
               (lambda (file _) (member file '(".git" ".idea")))))

(defun my/treemacs-focus ()
  "Like NvChad's <leader>e (NvimTreeFocus): open the tree if needed and jump into it."
  (interactive)
  (require 'treemacs)
  (if (eq (treemacs-current-visibility) 'visible)
      (treemacs-select-window)
    (+treemacs/toggle)))

(map! :n "C-n" #'+treemacs/toggle
      :leader :desc "Focus file tree" "e" #'my/treemacs-focus)

(defun my/treemacs--target-dir ()
  "Directory under the cursor, or the parent of the file under the cursor."
  (let ((path (treemacs--prop-at-point :path)))
    (if (file-directory-p path) path (file-name-directory path))))

(defun my/treemacs-create ()
  "Like nvim-tree's `a': create a file, or a directory if the name ends in /."
  (interactive)
  (let* ((dir (my/treemacs--target-dir))
         (name (read-string (format "Create (end with / for a directory) in %s: "
                                    (abbreviate-file-name dir))))
         (path (expand-file-name name dir)))
    (if (string-suffix-p "/" name)
        (make-directory path t)
      (make-directory (file-name-directory path) t)
      (write-region "" nil path nil 0 nil 'excl))
    (treemacs-refresh)
    (treemacs-goto-file-node (directory-file-name path))))

(defvar my/treemacs-clipboard nil "(PATH . copy-or-cut) for nvim-tree style c/x/p.")

(defun my/treemacs-copy () "nvim-tree's `c'." (interactive)
  (setq my/treemacs-clipboard (cons (treemacs--prop-at-point :path) 'copy))
  (message "Copied %s" (file-name-nondirectory (car my/treemacs-clipboard))))

(defun my/treemacs-cut () "nvim-tree's `x'." (interactive)
  (setq my/treemacs-clipboard (cons (treemacs--prop-at-point :path) 'cut))
  (message "Cut %s" (file-name-nondirectory (car my/treemacs-clipboard))))

(defun my/treemacs-paste ()
  "nvim-tree's `p': paste the copied/cut file into the directory under the cursor."
  (interactive)
  (pcase-let* ((`(,src . ,op) (or my/treemacs-clipboard (user-error "Nothing copied or cut")))
               (dest (expand-file-name (file-name-nondirectory (directory-file-name src))
                                       (my/treemacs--target-dir))))
    (when (and (file-exists-p dest)
               (not (y-or-n-p (format "%s exists, overwrite? " (abbreviate-file-name dest)))))
      (user-error "Cancelled"))
    (if (eq op 'cut)
        (progn (rename-file src dest t) (setq my/treemacs-clipboard nil))
      (if (file-directory-p src)
          (copy-directory src dest nil t t)
        (copy-file src dest t)))
    (treemacs-refresh)))

(defun my/treemacs-preview ()
  "nvim-tree's <Tab>: open the file but keep the cursor in the tree."
  (interactive)
  (treemacs-visit-node-no-split '(4)))

(after! treemacs-evil
  (evil-define-key* 'treemacs treemacs-mode-map
    (kbd "o")     #'treemacs-RET-action
    (kbd "a")     #'my/treemacs-create
    (kbd "d")     #'treemacs-delete-file
    (kbd "r")     #'treemacs-rename-file
    (kbd "c")     #'my/treemacs-copy
    (kbd "x")     #'my/treemacs-cut
    (kbd "p")     #'my/treemacs-paste
    (kbd "y")     #'treemacs-copy-filename-at-point
    (kbd "Y")     #'treemacs-copy-relative-path-at-point
    (kbd "gy")    #'treemacs-copy-absolute-path-at-point
    (kbd "R")     #'treemacs-refresh
    (kbd "H")     #'treemacs-toggle-show-dotfiles
    (kbd "I")     #'treemacs-hide-gitignored-files-mode
    (kbd "-")     #'treemacs-root-up
    (kbd "C-]")   #'treemacs-root-down
    (kbd "P")     #'treemacs-goto-parent-node
    (kbd "DEL")   #'treemacs-collapse-parent-node
    (kbd "W")     #'treemacs-collapse-all-projects
    (kbd "s")     #'treemacs-visit-node-in-external-application
    (kbd "TAB")   #'my/treemacs-preview
    [tab]         #'my/treemacs-preview
    ;; treemacs's "horizontal split" is vim's vsplit and vice versa
    (kbd "C-v")   #'treemacs-visit-node-horizontal-split
    (kbd "C-x")   #'treemacs-visit-node-vertical-split
    (kbd "q")     #'treemacs-quit))

;;; ---------------------------------------------------------------------------
;;; Mouse in the terminal (emacs -nw): click, drag-select, scroll wheel
;;; ---------------------------------------------------------------------------
(xterm-mouse-mode 1)

;;; ---------------------------------------------------------------------------
;;; Line wrapping
;;; ---------------------------------------------------------------------------
;; Soft-wrap long lines everywhere (wrapped lines keep the code's indentation)
(+global-word-wrap-mode +1)
(add-to-list '+word-wrap-disabled-modes 'treemacs-mode)

;;; ---------------------------------------------------------------------------
;;; File tree width: fit the longest visible name, like nvim-tree's
;;; view.width = { min = 15, max = -1, padding = 1 }
;;; ---------------------------------------------------------------------------
(defvar my/treemacs-min-width 15)
(defvar my/treemacs-padding 1)
(defvar my/treemacs--fit-timer nil)

(defun my/treemacs-fit-width ()
  "Resize the treemacs window to its longest line (expanded nodes only)."
  (setq my/treemacs--fit-timer nil)
  (when-let* ((win (treemacs-get-local-window)))
    (with-selected-window win
      (let ((longest 0))
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (setq longest (max longest (string-width (buffer-substring (line-beginning-position)
                                                                       (line-end-position)))))
            (forward-line 1)))
        (let ((width (max my/treemacs-min-width (+ longest my/treemacs-padding))))
          (setq treemacs-width width)
          (treemacs--set-width width))))))

(defun my/treemacs-fit-width-soon (&rest _)
  "Refit once the current command (expand, collapse, refresh...) has finished."
  (unless my/treemacs--fit-timer
    (setq my/treemacs--fit-timer (run-with-idle-timer 0 nil #'my/treemacs-fit-width))))

(after! treemacs
  (dolist (fn '(treemacs--expand-root-node treemacs--collapse-root-node
                treemacs--expand-dir-node treemacs--collapse-dir-node
                treemacs-root-up treemacs-root-down))
    (advice-add fn :after #'my/treemacs-fit-width-soon))
  (add-hook 'treemacs-post-refresh-hook #'my/treemacs-fit-width-soon)
  (add-hook 'treemacs-select-functions #'my/treemacs-fit-width-soon))

;; SPC r b / SPC r c: build & run (CMake/Maven/Gradle/Cargo/Python), like nvim
(load! "build")

;; ; enters command mode, like nvim's map("n", ";", ":")
(map! :n ";" #'evil-ex)
