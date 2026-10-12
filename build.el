;;; $DOOMDIR/build.el --- SPC r b / SPC r c: build & run -*- lexical-binding: t; -*-
;;
;; Mirrors <leader>rb / <leader>rc in ~/.config/nvim/lua/mappings.lua.
;; Picks CMake, Maven, Gradle, Cargo or Python based on the current major mode,
;; falling back to the nearest project marker file. Output goes to a
;; compilation buffer (clickable errors, `]e'/`[e' or M-g n/p to jump).

;;; Context

(defun +build--tree-node ()
  "(PATH . DIR-P) of the treemacs node under the cursor, so you can browse into
another project and build it without opening a file there."
  (when (derived-mode-p 'treemacs-mode)
    (when-let* ((path (treemacs--prop-at-point :path)))
      (and (stringp path) (cons path (file-directory-p path))))))

(defun +build--context-file ()
  (if-let* ((node (+build--tree-node)))
      (unless (cdr node) (car node))
    buffer-file-name))

(defun +build--buf-dir ()
  (if-let* ((node (+build--tree-node)))
      (if (cdr node) (car node) (file-name-directory (car node)))
    (if buffer-file-name
        (file-name-directory buffer-file-name)
      default-directory)))

(defun +build--find-root (markers &optional topmost)
  "Directory of the nearest (or TOPMOST) ancestor containing one of MARKERS."
  (let ((dir (expand-file-name (+build--buf-dir))) found)
    (while dir
      (when (cl-some (lambda (m) (file-exists-p (expand-file-name m dir))) markers)
        (setq found dir)
        (unless topmost (setq dir nil)))
      (when dir
        (let ((parent (file-name-directory (directory-file-name dir))))
          (setq dir (unless (equal parent dir) parent)))))
    (and found (file-name-as-directory found))))

(defun +build--read (path)
  (with-temp-buffer (insert-file-contents path) (buffer-string)))

;;; Commands per project type

(defun +build--cmake (root run)
  (let ((cmd (if (file-directory-p (expand-file-name "build" root))
                 "cmake --build build"
               "cmake -B build && cmake --build build && ln -sf build/compile_commands.json compile_commands.json")))
    (if (not run)
        cmd
      (let ((text (+build--read (expand-file-name "CMakeLists.txt" root))))
        (unless (string-match "add_executable(\\s-*\\([^ \t\n)]+\\)" text)
          (user-error "No add_executable() found in CMakeLists.txt"))
        (let ((target (match-string 1 text)))
          ;; add_executable(${PROJECT_NAME} ...) names the exe after project()
          (when (string-match "project(\\s-*\\([^ \t\n)]+\\)" text)
            (setq target (string-replace "${PROJECT_NAME}" (match-string 1 text) target)))
          (concat cmd " && ./build/" target))))))

(defun +build--java-main-class (path)
  "\"com.example.App\" if PATH declares a main method, else nil."
  (when-let* ((text (ignore-errors (+build--read path))))
    (when (or (string-match-p "static\\s-+void\\s-+main\\s-*(" text)
              (string-match-p "void\\s-+main\\s-*(\\s-*)" text))
      (let ((class (file-name-base path)))
        (if (string-match "^\\s-*package\\s-+\\([[:alnum:]_.]+\\)\\s-*;" text)
            (concat (match-string 1 text) "." class)
          class)))))

(defun +build--maven (root run)
  (if (not run)
      "mvn compile"
    ;; Respect an exec-maven-plugin <mainClass> in the pom; otherwise infer it
    (if (string-match-p "<mainClass>" (+build--read (expand-file-name "pom.xml" root)))
        "mvn -q compile exec:java"
      (let ((main (or (when-let* ((f (+build--context-file))) (+build--java-main-class f))
                      (let ((src (expand-file-name "src/main/java" root)))
                        (and (file-directory-p src)
                             (cl-some #'+build--java-main-class
                                      (directory-files-recursively src "\\.java\\'")))))))
        (unless main
          (user-error "No main class found (set <mainClass> in pom.xml or open the main file)"))
        (concat "mvn -q compile exec:java -Dexec.mainClass=" main)))))

(defun +build--gradle (root run)
  ;; Uses the wrapper when present
  (concat (if (file-executable-p (expand-file-name "gradlew" root)) "./gradlew" "gradle")
          " --console=plain " (if run "run" "classes")))

(defun +build--python (root run)
  (let ((python (or (cl-loop for venv in '(".venv" "venv")
                             for exe = (expand-file-name (concat venv "/bin/python") root)
                             when (file-executable-p exe) return exe)
                    "python3"))
        (file (+build--context-file)))
    (unless (and file (string-suffix-p ".py" file))
      (setq file (expand-file-name "main.py" root))
      (unless (file-readable-p file)
        (user-error "Not in a Python file and no main.py in %s" root)))
    (concat (shell-quote-argument python) (if run " " " -m py_compile ")
            (shell-quote-argument file))))

(defun +build--cargo-workspace-root (root)
  "Top-most Cargo.toml with a [workspace] table (where rustc's relative paths
start), else ROOT."
  (let ((dir root) found)
    (while dir
      (let ((toml (expand-file-name "Cargo.toml" dir)))
        (when (and (file-readable-p toml)
                   (string-match-p "^\\s-*\\[workspace\\]" (+build--read toml)))
          (setq found dir)))
      (let ((parent (file-name-directory (directory-file-name dir))))
        (setq dir (unless (equal parent dir) parent))))
    (or found root)))

(defun +build--cargo (_root run)
  (if (not run)
      "cargo build"
    ;; src/bin/foo.rs or src/bin/foo/main.rs: run that binary
    (let ((file (or (+build--context-file) "")))
      (concat "cargo run"
              (when (or (string-match "/src/bin/\\([^/]+\\)\\.rs\\'" file)
                        (string-match "/src/bin/\\([^/]+\\)/main\\.rs\\'" file))
                (concat " --bin " (shell-quote-argument (match-string 1 file))))))))

(defvar +build-project-types
  `((cmake  :markers ("CMakeLists.txt") :topmost t
            :modes (c-mode c-ts-mode c++-mode c++-ts-mode cmake-mode cmake-ts-mode)
            :cmd +build--cmake)
    (maven  :markers ("pom.xml")
            :modes (java-mode java-ts-mode)
            :cmd +build--maven)
    ;; Top-most so a subproject's build.gradle resolves to the root build
    (gradle :markers ("settings.gradle" "settings.gradle.kts" "build.gradle" "build.gradle.kts")
            :topmost t
            :modes (java-mode java-ts-mode kotlin-mode kotlin-ts-mode groovy-mode)
            :cmd +build--gradle)
    (cargo  :markers ("Cargo.toml")
            :modes (rust-mode rust-ts-mode rustic-mode conf-toml-mode toml-ts-mode)
            :cmd +build--cargo
            :file-root +build--cargo-workspace-root)
    (python :markers ("pyproject.toml" "setup.py" "requirements.txt" ".git")
            :modes (python-mode python-ts-mode)
            :cmd +build--python)))

(defun +build--closest (pred)
  "Project whose marker is closest to the buffer (deepest root wins)."
  (let (best)
    (pcase-dolist (`(,name . ,p) +build-project-types)
      (when-let* (((funcall pred name p))
                  (root (+build--find-root (plist-get p :markers) (plist-get p :topmost))))
        (when (or (null best) (> (length root) (length (nth 2 best))))
          (setq best (list name p root)))))
    best))

(defun +build--detect ()
  (let ((in-modes (lambda (_ p) (apply #'derived-mode-p (plist-get p :modes)))))
    (cond
     ((derived-mode-p 'python-mode 'python-ts-mode)
      (let ((p (alist-get 'python +build-project-types)))
        (list 'python p (or (+build--find-root (plist-get p :markers)) (+build--buf-dir)))))
     ;; Several build tools can share a mode (Java: Maven or Gradle)
     ((+build--closest in-modes))
     ;; Unknown mode (or no matching build file): use any marker
     (t (+build--closest (lambda (name _) (not (eq name 'python))))))))

(defun +build--task (run)
  (pcase-let ((`(,name ,p ,root) (or (+build--detect)
                                     (user-error "No CMake, Maven, Gradle, Cargo or Python project found for this buffer"))))
    (let ((cmd (funcall (plist-get p :cmd) root run)))
      (save-some-buffers t)
      (let* ((default-directory root)
             (compilation-buffer-name-function
              (lambda (_) (format "*%s %s*" name (if run "build & run" "build"))))
             ;; comint so a running program can read input; cursor stays where it was
             (buf (save-selected-window (compile cmd run))))
        (when-let* ((file-root (plist-get p :file-root)))
          (with-current-buffer buf
            (setq-local compilation-search-path (list nil (funcall file-root root)))))))))

(defun +build/build ()
  "Build project (CMake/Maven/Gradle/Cargo/Python)."
  (interactive)
  (+build--task nil))

(defun +build/build-and-run ()
  "Build & run project (CMake/Maven/Gradle/Cargo/Python)."
  (interactive)
  (+build--task t))

(map! :leader
      (:prefix-map ("r" . "run")
       :desc "Build project"       "b" #'+build/build
       :desc "Build & run project" "c" #'+build/build-and-run))

;;; Cargo errors (same patterns as the nvim errorformat)

(after! compile
  (add-to-list 'compilation-error-regexp-alist-alist
               '(cargo "^\\(?:\\(warning\\)\\|error\\)[^\n]*\n\\s-*--> \\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\)"
                       2 3 4 (1)))
  (add-to-list 'compilation-error-regexp-alist-alist
               '(cargo-panic "^thread '[^']*' panicked at \\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\)"
                             1 2 3))
  (add-to-list 'compilation-error-regexp-alist 'cargo)
  (add-to-list 'compilation-error-regexp-alist 'cargo-panic))
