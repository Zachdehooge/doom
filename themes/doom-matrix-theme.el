;;; doom-matrix-theme.el --- AMOLED black + phosphor green -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Ported from ~/.config/nvim/lua/themes/matrix.lua (NvChad base46 theme).
;;
;;; Code:

(require 'doom-themes)

(defgroup doom-matrix-theme nil
  "Options for the `doom-matrix' theme."
  :group 'doom-themes)

(def-doom-theme doom-matrix
  "AMOLED black with phosphor green accents."

  ;; name        default    256        16
  ((bg         '("#000000" "black"    "black"))
   (fg         '("#d0d8d0" "#d0d8d0"  "white"))
   (bg-alt     '("#011508" "black"    "black"))
   (fg-alt     '("#c0ffd0" "#c0ffd0"  "brightwhite"))

   (base0      '("#000000" "black"    "black"))
   (base1      '("#011508" "#011508"  "brightblack"))
   (base2      '("#03240d" "#03240d"  "brightblack"))
   (base3      '("#063d16" "#063d16"  "brightblack"))
   (base4      '("#0a4f1d" "#0a4f1d"  "brightblack"))
   (base5      '("#4e5a55" "#4e5a55"  "brightblack"))
   (base6      '("#6e7681" "#6e7681"  "brightblack"))
   (base7      '("#8b949e" "#8b949e"  "brightblack"))
   (base8      '("#e0ffe8" "#e0ffe8"  "white"))

   (grey       '("#0b6b26" "#0b6b26"  "brightblack"))
   (red        '("#ff3b3b" "#ff3b3b"  "red"))
   (orange     '("#ffa066" "#ffa066"  "brightred"))
   (green      '("#00ff41" "#00ff41"  "green"))
   (teal       '("#159a38" "#159a38"  "brightgreen"))
   (yellow     '("#e6db74" "#e6db74"  "yellow"))
   (blue       '("#61afef" "#61afef"  "brightblue"))
   (dark-blue  '("#20c84a" "#20c84a"  "blue"))
   (magenta    '("#ff79c6" "#ff79c6"  "magenta"))
   (violet     '("#c792ea" "#c792ea"  "brightmagenta"))
   (cyan       '("#56d4dd" "#56d4dd"  "brightcyan"))
   (dark-cyan  '("#159a38" "#159a38"  "cyan"))

   ;; extra palette entries from the nvim theme
   (vibrant-green '("#4dff88" "#4dff88" "brightgreen"))
   (light-green   '("#7dffa0" "#7dffa0" "brightgreen"))
   (sun           '("#ffb000" "#ffb000" "yellow"))
   (sky           '("#9cdcfe" "#9cdcfe" "brightcyan"))

   ;; face categories
   (highlight      green)
   (vertical-bar   base3)
   (selection      base3)
   (builtin        blue)
   (comments       base6)
   (doc-comments   base7)
   (constants      violet)
   (functions      blue)
   (keywords       green)
   (methods        blue)
   (operators      base7)
   (type           cyan)
   (strings        yellow)
   (variables      fg)
   (numbers        violet)
   (region         base3)
   (error          red)
   (warning        sun)
   (success        green)
   (vc-modified    sun)
   (vc-added       green)
   (vc-deleted     red)

   (modeline-fg     fg)
   (modeline-fg-alt base6)
   (modeline-bg     bg-alt)
   (modeline-bg-alt bg)
   (modeline-bg-inactive bg)
   (modeline-bg-inactive-alt bg))

  ;;;; Base theme face overrides
  ((cursor :background green)
   (hl-line :background base1)
   (line-number :foreground grey)
   (line-number-current-line :foreground green :weight 'bold)
   (font-lock-comment-face :foreground comments :slant 'italic)
   (font-lock-doc-face :foreground doc-comments :slant 'italic)
   (font-lock-keyword-face :foreground keywords :weight 'bold)
   (font-lock-builtin-face :foreground builtin :slant 'italic)
   (font-lock-preprocessor-face :foreground magenta)
   (font-lock-constant-face :foreground constants :weight 'bold)
   (font-lock-escape-face :foreground orange :weight 'bold)
   (font-lock-property-name-face :foreground sky)
   (font-lock-property-use-face :foreground sky)
   (font-lock-bracket-face :foreground base7)
   (font-lock-delimiter-face :foreground base7)
   (font-lock-punctuation-face :foreground base7)
   (font-lock-variable-name-face :foreground fg)
   (font-lock-variable-use-face :foreground fg)
   (show-paren-match :foreground base8 :background base3 :weight 'bold)
   (isearch :foreground bg :background green :weight 'bold)
   (lazy-highlight :foreground bg :background light-green)
   (vertical-border :foreground base3 :background base3)
   (minibuffer-prompt :foreground green :weight 'bold)
   (link :foreground blue :underline t)
   (mode-line :background modeline-bg :foreground modeline-fg)
   (mode-line-inactive :background modeline-bg-inactive :foreground modeline-fg-alt)
   ;;;; doom-modeline
   (doom-modeline-bar :background green)
   (doom-modeline-buffer-file :foreground fg :weight 'bold)
   (doom-modeline-buffer-modified :foreground sun :weight 'bold)
   ;;;; hl-todo
   (hl-todo :foreground bg :background sun :weight 'bold)
   ;;;; dired / treemacs
   (dired-directory :foreground light-green)
   (treemacs-directory-face :foreground light-green)
   ;;;; markdown / org headings
   (markdown-header-face :foreground green :weight 'bold)
   (org-level-1 :foreground green :weight 'bold :height 1.15)
   (org-level-2 :foreground vibrant-green :weight 'bold)
   (org-level-3 :foreground light-green :weight 'bold)
   (org-document-title :foreground green :weight 'bold :height 1.3)
   ;;;; vertico / completion
   (vertico-current :background base3 :foreground base8 :weight 'bold)
   (orderless-match-face-0 :foreground green :weight 'bold)
   ;;;; doom-dashboard
   (doom-dashboard-banner :foreground green)
   (doom-dashboard-menu-title :foreground green)
   (doom-dashboard-menu-desc :foreground fg))

  ;;;; Base theme variable overrides
  ())

;;; doom-matrix-theme.el ends here
