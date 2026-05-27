;;; init.el --- GNU Emacs initialization  -*- lexical-binding: t; -*-

;;; Code:

(let ((minver "29"))
  (if (version< emacs-version minver)
      (error "GNU Emacs v%s or later required for this init.el" minver)))

;; Disable garbage collection during initialization for faster startup.
(defvar my-default-gc-cons-threshold gc-cons-threshold
  "Default value of `gc-cons-threshold'.")
(setq gc-cons-threshold most-positive-fixnum)
(defun my-restore-gc-cons-threshold ()
  "Restore `gc-cons-threshold' after init."
  (setq gc-cons-threshold my-default-gc-cons-threshold))
(add-hook 'emacs-startup-hook #'my-restore-gc-cons-threshold)

;;;; Utilities:

(defun my-emacs-d-path (file)
  "Return a path to FILE within the GNU Emacs directory."
  (expand-file-name file user-emacs-directory))

;;;; Package Manager:

;; Bootstrap straight.el.
(defvar bootstrap-version)
(let ((bootstrap-file
       (my-emacs-d-path "straight/repos/straight.el/bootstrap.el"))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Use `use-package' to install packages.
(setq straight-use-package-by-default t)
(straight-use-package 'use-package)

;;;; Operating Systems:

(defconst *is-bsd* (eq system-type 'berkeley-unix))
(defconst *is-linux* (eq system-type 'gnu/linux))
(defconst *is-macos* (eq system-type 'darwin))
(defconst *is-windows* (eq system-type 'windows-nt))
(defconst *is-unix* (or *is-bsd* *is-linux* *is-macos*))

(when (or *is-bsd* *is-linux*)
  ;; I always use window managers where focus follows the mouse.
  (setq focus-follows-mouse t))

(when *is-macos*
  ;; Fix problem where `exec-path' doesn't include the Homebrew path.
  (use-package exec-path-from-shell
    :config
    (exec-path-from-shell-initialize)))

;;;; General Settings:

;; Run Emacs as a server so that emacsclient will work.
(require 'server)
(unless (server-running-p) (server-start))

(global-auto-revert-mode 1) ; Revert externally edited files.

;; Live dangerously.
(setq create-lockfiles nil)
(setq make-backup-files nil)

(save-place-mode 1) ; Remember position in files.
(recentf-mode 1) ; Remember recently edited files.
(setq recentf-max-menu-items 32) ; Default is 10.
(global-set-key (kbd "C-c R") 'recentf-open-files)

;; Reduce buffer list clutter from dired.
(setq dired-kill-when-opening-new-dired-buffer t)

;; Always kill the current buffer instead of prompting.
(global-set-key (kbd "C-x k") 'kill-current-buffer)

(delete-selection-mode 1) ; Typing replaces selection.

(setq large-file-warning-threshold nil) ; Open big files without prompting.

;; Disable garbage collection when minibuffer is active.
;; https://bling.github.io/blog/2016/01/18/why-are-you-changing-gc-cons-threshold/
(defun my-gc-minibuffer-setup-hook ()
  (setq gc-cons-threshold most-positive-fixnum))
(defun my-gc-minibuffer-exit-hook ()
  (setq gc-cons-threshold my-default-gc-cons-threshold))
(add-hook 'minibuffer-setup-hook #'my-gc-minibuffer-setup-hook)
(add-hook 'minibuffer-exit-hook #'my-gc-minibuffer-exit-hook)

;; Make it easier to restart Emacs.
(use-package restart-emacs
  :commands restart-emacs)

(defun my-add-to-path (newpath)
  "Add NEWPATH to `exec-path' and the PATH environment variable, if it
exists and is not already present."
  (when (file-directory-p newpath)
    (let* ((path (or (getenv "PATH") ""))
           (entries (split-string path path-separator t)))
      (unless (member newpath entries)
        (setenv "PATH" (if (string-empty-p path)
                           newpath
                         (concat path path-separator newpath)))))
    ;; `add-to-list' dedupes by `equal', matching the member-check above.
    (add-to-list 'exec-path newpath)))

(my-add-to-path (concat (getenv "HOME") "/bin"))
(my-add-to-path (concat (getenv "HOME") "/.local/bin"))
(my-add-to-path (concat (getenv "HOME") "/go/bin"))
(my-add-to-path (concat (getenv "HOME") "/.cargo/bin"))

;; native-compilation causes warnings with some packages: by default, this opens
;; the *Warnings* window, which is annoying, so suppress it.
(setq native-comp-async-report-warnings-errors nil)

;; Enable mouse support in terminal frames.  This is a no-op in a GUI frame, so
;; it's safe to set unconditionally.
(xterm-mouse-mode 1)

;; Open a URL in a web browser
(global-set-key (kbd "C-c u") #'browse-url)

;; Prefer vertical window splitting.
(setq split-height-threshold nil)

;; *scratch* starts out empty.
(setq initial-scratch-message nil)

(setq mouse-autoselect-window t) ; window focus follows mouse

;;;; Appearance (UI Elements):

(setq inhibit-startup-screen t)

(tool-bar-mode 0)
(scroll-bar-mode 0)

;; Disable the menu bar by default but make it easy to enable.
(menu-bar-mode 0)
(global-set-key (kbd "C-c m") #'menu-bar-mode)

(column-number-mode 1)

(show-paren-mode 1)
(setq show-paren-delay 0)

(blink-cursor-mode 0)
;; Switch to an underbar cursor while in overwrite mode.
(defun my-overwrite-mode-hook ()
  "Switch the cursor between a box and an underbar based on overwrite mode."
  (setq cursor-type (if overwrite-mode 'hbar 'box)))
(add-hook 'overwrite-mode-hook #'my-overwrite-mode-hook)

;; Search shows current match # and total match # in the mode-line
(use-package anzu
  :config
  (global-anzu-mode +1))

;;;; Appearance (Theme, Style, etc.):

(setq custom-safe-themes t)

(straight-use-package
 '(almost-mono-themes :type git :host github :repo "ixtenu/almost-mono-themes"))
(load-theme 'almost-mono-black t)

(defvar my-gui-once-done nil
  "Non-nil after one-time GUI-only setup has run.")
(defun my-setup-gui-frame (frame)
  "Apply GUI-only configuration when FRAME is graphical."
  (when (display-graphic-p frame)
    (with-selected-frame frame
      ;; Make the mouse pointer visible atop the nearly black background.
      (set-mouse-color "white")
      ;; Ignore errors in case the configured font is not (yet) installed.
      (ignore-errors
        (set-frame-font "Cascadia Code 12" t t)))
    (unless my-gui-once-done
      (setq my-gui-once-done t)
      ;; Clock in modeline.  Only done for GUI frames (terminal modelines are
      ;; space-constrained).
      (setq display-time-format "%H:%M"
            display-time-default-load-average nil)
      (display-time-mode 1)
      ;; The first GUI frame will install nerd-icons fonts if they are not
      ;; already present.  Deferred until here because `find-font' needs a
      ;; graphical font backend to give meaningful answers.
      (when (and (fboundp 'nerd-icons-install-fonts)
                 (not (find-font (font-spec :name "Symbols Nerd Font Mono"))))
        (nerd-icons-install-fonts t)))))

;; GUI-only frame setup.  Routed through `after-make-frame-functions' so
;; emacsclient frames created under --daemon receive the same treatment as a
;; non-daemon initial frame (where `display-graphic-p' is t at init).
(add-hook 'after-make-frame-functions #'my-setup-gui-frame)
;; Apply to the initial frame for the non-daemon case.  Do this after startup is
;; complete, after nerd-icons has been loaded.
(defun my-setup-gui-frame-hook ()
  (my-setup-gui-frame (selected-frame)))
(add-hook 'emacs-startup-hook #'my-setup-gui-frame-hook())

(use-package ligature
  :config
  (ligature-set-ligatures
   'prog-mode
   '("!=" "->" "<=" ">=" "<<" ">>" "<<=" ">>=" "||" "&&" "!!"))
  (global-ligature-mode t))

;; nerd-icons is required by doom-modeline and nerd-icons-dired.
;; Fonts auto-install on first GUI frame; see `my-setup-gui-frame'.
(use-package nerd-icons
  :defer t)

;; Dired eye candy.
(use-package nerd-icons-dired
  :commands nerd-icons-dired-mode)
(defun my-dired-mode-hook ()
  "Enable nerd-icons in dired buffers shown in graphical frames."
  (when (display-graphic-p)
    (nerd-icons-dired-mode 1)))
(add-hook 'dired-mode-hook #'my-dired-mode-hook)

;; Modeline eye candy.
(use-package doom-modeline
  :init (doom-modeline-mode 1)
  ;; Fix issue with "../../.." (etc.) shown in modeline for paths visited via
  ;; symlink.  See the doom-modeline README for details.
  :config (setq doom-modeline-project-detection 'project))

(setq frame-resize-pixelwise t) ; No gaps around "maximized" window.

;;;; Project Management:

;;; For projectile-ripgrep.
(when (executable-find "rg")
  (use-package rg
    :init (rg-enable-default-bindings)))

(use-package projectile
  :init
  (projectile-mode 1)
  :bind (:map projectile-mode-map ("C-c p" . projectile-command-map)))

;;;; Input:

(global-set-key (kbd "C-x C-m") 'execute-extended-command)
(setq use-short-answers t)

;; Display possible completions for partial keychords.
(use-package which-key
  :config (which-key-mode 1))

;; Change the behavior of C-x 1: after using C-x 1 to hide the other windows,
;; use C-x 1 again to unhide them.
(use-package zygospore
  :bind (("C-x 1" . zygospore-toggle-delete-other-windows)))

;;;; Navigation:

;; Easier window navigation
(use-package ace-window
  :bind (("M-o" . ace-window)))
(global-set-key (kbd "C-c <left>") 'windmove-left)
(global-set-key (kbd "C-c <right>") 'windmove-right)
(global-set-key (kbd "C-c <up>") 'windmove-up)
(global-set-key (kbd "C-c <down>") 'windmove-down)

;; Jump to things
(use-package avy
  :bind (("C-:"   . avy-goto-char)
         ("C-'"   . avy-goto-char-2)
         ("M-g f" . avy-goto-line)))

(use-package goto-line-preview
  :bind (([remap goto-line] . goto-line-preview)))

;;;; Completion:

(use-package vertico
  :init
  (vertico-mode))

;; Persist history over Emacs restarts.  Vertico sorts by history position.
(use-package savehist
  :init
  (savehist-mode))

(use-package emacs
  :custom
  ;; Enable context menu.  `vertico-multiform-mode' adds a menu in the
  ;; minibuffer to switch display modes.
  (context-menu-mode t)
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  ;; Hide commands in M-x which do not work in the current mode.  Vertico
  ;; commands are hidden in normal buffers.  This setting is useful beyond
  ;; Vertico.
  (read-extended-command-predicate #'command-completion-default-include-p)
  ;; Do not allow the cursor in the minibuffer prompt.
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt)))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-category-defaults nil) ; Disable defaults, use our settings
  (completion-pcm-leading-wildcard t))

;;;; User Utilities:

(use-package crux
  :bind
  (("C-x 4 t" . #'crux-transpose-windows) ; Swap buffers in current/other window
   ("C-c o" . #'crux-open-with) ; Open visited file with default application
   ("C-c D" . #'crux-delete-file-and-buffer) ; Delete visited file and its buffer
   ("C-c r" . #'crux-rename-file-and-buffer) ; Rename visited file and its buffer
   ("C-c c" . #'crux-copy-file-preserve-attributes) ; cp -a
   ("C-c !" . #'crux-sudo-edit) ; Edit visited file with sudo
   ("C-c I" . #'crux-find-user-init-file) ; Open init.el
   ("C-c P" . #'crux-kill-buffer-truename) ; Copy path to visited file
   ("C-c k" . #'crux-kill-other-buffers) ; Kill all buffers except current
   ("C-c t" . #'crux-visit-term-buffer) ; Open ansi-term
   ("C-c d" . #'crux-duplicate-current-line-or-region)))

(defun my-close-all-buffers ()
  "Close all buffers."
  (interactive)
  (mapc 'kill-buffer (buffer-list)))
(global-set-key (kbd "C-c W") #'my-close-all-buffers)

;; Copied from https://stackoverflow.com/a/207067
;; (c) Greg Mattes, CC BY-SA 4.0
(defun my-generalized-shell-command (command arg)
  "Unifies `shell-command' and `shell-command-on-region'.  If no region is
selected, run a shell command just like M-x shell-command (M-!).  If no
region is selected and an argument is a passed, run a shell command and
place its output after the mark as in C-u M-x `shell-command' (C-u M-!).
If a region is selected pass the text of that region to the shell and
replace the text in that region with the output of the shell command as
in C-u M-x `shell-command-on-region' (C-u M-|).  If a region is selected
AND an argument is passed (via C-u) send output to another buffer
instead of replacing the text in region."
  (interactive (list (read-from-minibuffer "Shell command: " nil nil nil 'shell-command-history)
                     current-prefix-arg))
  (let ((p (if mark-active (region-beginning) 0))
        (m (if mark-active (region-end) 0)))
    (if (= p m)
        ;; No active region
        (if (eq arg nil)
            (shell-command command)
          (shell-command command t))
      ;; Active region
      (if (eq arg nil)
          (shell-command-on-region p m command t t)
        (shell-command-on-region p m command)))))

(global-set-key (kbd "C-c \\") #'my-generalized-shell-command)
(global-set-key (kbd "C-|") #'my-generalized-shell-command)

;;;; Git:

(use-package git-modes)

(use-package magit
  :bind
  ("C-c g" . 'magit-file-dispatch))

(defun my-git-commit-mode-hook ()
  "Wrap Git commit messages at 72 columns."
  (setq fill-column 72)
  (turn-on-auto-fill))
(add-hook 'git-commit-mode-hook #'my-git-commit-mode-hook)

(use-package git-timemachine
  :commands git-timemachine)

;;;; Text Editing:

(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8-unix)
(prefer-coding-system 'utf-8)

(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)

(setq-default require-final-newline t)
(setq-default fill-column 80)
;; Virtual indentation/prefixes for wrapped lines.
(use-package adaptive-wrap
  :commands adaptive-wrap-prefix-mode)
(defun my-text-mode-hook ()
  "Enable wrapping behavior in text buffers."
  (auto-fill-mode 1)
  (visual-line-mode 1)
  (adaptive-wrap-prefix-mode 1))
(add-hook 'text-mode-hook #'my-text-mode-hook)

(global-set-key (kbd "C-c q") 'auto-fill-mode)
(global-set-key (kbd "C-c Q") 'refill-mode)

(defun my-french-spacing-toggle ()
  "Toggle `sentence-end-double-space' between t and nil."
  (interactive)
  (setq sentence-end-double-space (not sentence-end-double-space)))
(global-set-key (kbd "C-c C-.") 'my-french-spacing-toggle)

(setq kill-whole-line t)
(setq backward-delete-char-untabify-method 'hungry)

;; Cleanup whitespace only on edited lines.
(use-package ws-butler
  :hook ((prog-mode . ws-butler-mode)
         (text-mode . ws-butler-mode))
  :config
  ;; Fix indentation to be consistent with `indent-tabs-mode'.
  (setq ws-butler-convert-leading-tabs-or-spaces t))

(global-set-key (kbd "C-c w") 'whitespace-mode)

(when-let* ((aspell (executable-find "aspell")))
  (setq ispell-program-name aspell))
(defun my-flyspell-toggle ()
  "Toggle flyspell-mode and run flyspell-buffer when enabling it."
  (interactive)
  (if flyspell-mode
      (flyspell-mode 0)
    (if (derived-mode-p 'prog-mode)
        (flyspell-prog-mode)
      (flyspell-mode 1))
    (flyspell-buffer)))
(global-set-key (kbd "<f6>") #'my-flyspell-toggle)

;; my-open-line functions from: https://stackoverflow.com/a/2173393
;; (c) seh, CC BY-SA 4.0

;; like vi's "O" command
(defun my-open-line-above ()
  "Insert a newline above the current line and put point at beginning."
  (interactive)
  (unless (bolp)
    (beginning-of-line))
  (newline)
  (forward-line -1)
  (indent-according-to-mode))

;; like vi's "o" command
(defun my-open-line-below ()
  "Insert a newline below the current line and put point at beginning."
  (interactive)
  (unless (eolp)
    (end-of-line))
  (newline-and-indent))

(defun my-open-line (&optional abovep)
  "Insert a newline below the current line and put point at beginning.
With a prefix argument, insert a newline above the current line."
  (interactive "P")
  (if abovep
      (my-open-line-above)
    (my-open-line-below)))

(global-set-key (kbd "C-<return>") #'my-open-line)
(global-set-key (kbd "S-<return>") #'my-open-line-above)

;;;; Text Editing (Knuth-Plass fill-paragraph):

;; Optimal (non-greedy) paragraph filler bound to M-j.
;; Uses the Knuth-Plass DP algorithm: cost of a non-final line with s spare
;; columns is s².  The last line is never penalised.
;; Wide characters (e.g., CJK) count as 2 columns via `string-width'.
;; Respects `sentence-end-double-space'.

(defconst my-kp-abbreviations
  '("Mr." "Ms." "Mrs." "Dr." "Prof." "St." "vs." "approx."
    "fig." "Fig." "vol." "Vol." "e.g." "i.e." "viz.")
  "English abbreviations ending with `.' that do not end a sentence.")

(defun my-kp-sentence-end-p (word)
  "Return non-nil if WORD ends a sentence.
Strips trailing `\"', `'', `)', and `]' to find the base word, then
returns nil if the base is in `my-kp-abbreviations', and otherwise
returns non-nil when the base ends with `.', `?', or `!'."
  (let ((i (1- (length word))))
    (while (and (>= i 0) (memq (aref word i) '(?\" ?' ?\) ?\])))
      (setq i (1- i)))
    (when (>= i 0)
      (let ((base (substring word 0 (1+ i))))
        (and (memq (aref base (1- (length base))) '(?. ?? ?!))
             (not (member base my-kp-abbreviations)))))))

(defun my-kp-compute-gaps (words)
  "Return a vector of inter-word gap widths for WORDS.
Each gap is 1, except that when `sentence-end-double-space' is non-nil
a gap following a sentence-ending word (see `my-kp-sentence-end-p') is 2.
The vector has length (max 0 (1- (length WORDS)))."
  (let* ((n  (length words))
         (gv (make-vector (max 0 (1- n)) 1)))
    (when sentence-end-double-space
      (let ((wv (vconcat words))
            (i  0))
        (while (< i (1- n))
          (when (my-kp-sentence-end-p (aref wv i))
            (aset gv i 2))
          (setq i (1+ i)))))
    gv))

(defun my-kp-compute-breaks (words widths gaps max-width)
  "Return optimal line-break positions for WORDS at MAX-WIDTH columns.
WIDTHS is a vector of per-word column counts (via `string-width').
GAPS is a vector of inter-word spacings (typically 1 or 2).
Non-final lines are penalised by the square of their slack; the final
line incurs no penalty.  A word wider than MAX-WIDTH is forced onto its
own line without penalty.  Returns a sorted list of 0-indexed word
positions where new lines begin (the break before word 0 is implicit)."
  (let* ((n    (length words))
         (dp   (make-vector (1+ n) most-positive-fixnum))
         (prev (make-vector (1+ n) 0)))
    (aset dp 0 0)
    (let ((i 0))
      (while (< i n)
        (when (< (aref dp i) most-positive-fixnum)
          (let ((j i) (w 0) (stop nil))
            (while (and (< j n) (not stop))
              ;; Accumulate width: word widths + inter-word gaps.
              ;; gaps[j-1] is the space between word j-1 and word j.
              (setq w (if (= j i)
                          (aref widths j)
                        (+ w (aref gaps (1- j)) (aref widths j))))
              (cond
               ;; Words i..j fit on one line.
               ((<= w max-width)
                (let* ((slack   (- max-width w))
                       (penalty (if (= j (1- n)) 0 (* slack slack)))
                       (cost    (+ (aref dp i) penalty)))
                  (when (< cost (aref dp (1+ j)))
                    (aset dp (1+ j) cost)
                    (aset prev (1+ j) i)))
                (setq j (1+ j)))
               ;; Single word wider than max-width: force it alone.
               ((= j i)
                (when (< (aref dp i) (aref dp (1+ j)))
                  (aset dp (1+ j) (aref dp i))
                  (aset prev (1+ j) i))
                (setq stop t))
               ;; Multiple words overflow: stop extending this line.
               (t (setq stop t))))))
        (setq i (1+ i))))
    ;; Trace prev[] backwards to reconstruct line-start positions.
    (let (breaks (pos n))
      (while (> pos 0)
        (let ((p (aref prev pos)))
          (when (> p 0) (push p breaks))
          (setq pos p)))
      breaks)))

(defun my-kp-words-in-region (start end prefix)
  "Collect words from START..END, stripping PREFIX from each line start."
  (let ((plen (length prefix)) words)
    (dolist (line (split-string (buffer-substring-no-properties start end) "\n"))
      (let* ((stripped (if (and (> plen 0) (string-prefix-p prefix line))
                           (substring line plen) line))
             (trimmed  (string-trim stripped)))
        (unless (string-empty-p trimmed)
          (dolist (w (split-string trimmed nil t))
            (push w words)))))
    (nreverse words)))

(defun my-kp-join-lines (words gaps breaks prefix)
  "Assemble WORDS into newline-separated lines each prefixed with PREFIX.
GAPS is a vector of inter-word spacings.
BREAKS is a sorted list of 0-indexed positions where new lines begin."
  (let* ((wv (vconcat words))
         (n  (length words))
         (ss (cons 0 breaks))
         (es (append breaks (list n)))
         lines)
    (while ss
      (let ((s (pop ss)) (e (pop es)) parts)
        (let ((k s))
          (while (< k e)
            (push (aref wv k) parts)
            (when (< k (1- e))
              (push (make-string (aref gaps k) ?\s) parts))
            (setq k (1+ k))))
        (push (concat prefix (mapconcat #'identity (nreverse parts) "")) lines)))
    (mapconcat #'identity (nreverse lines) "\n")))

(defun my-kp-word-offset (wv gaps breaks prefix n)
  "Return byte offset in `my-kp-join-lines' output just before word N.
WV is a vector of word strings, GAPS a gap-width vector, BREAKS the
line-start index list, PREFIX the per-line prefix string.
Returns the offset past the last character when N >= (length WV)."
  (let* ((total (length wv))
         (plen  (length prefix))
         (ss    (cons 0 breaks))
         (es    (append breaks (list total)))
         (offset 0)
         (word-idx 0)
         done)
    (while (and ss (not done))
      (let ((s (pop ss)) (e (pop es)))
        (setq offset (+ offset plen))
        (let ((k s))
          (while (and (< k e) (not done))
            (when (= word-idx n) (setq done t))
            (unless done
              (setq offset (+ offset (length (aref wv k))))
              (when (< k (1- e))
                (setq offset (+ offset (aref gaps k))))
              (setq word-idx (1+ word-idx))
              (setq k (1+ k)))))
        (unless done
          (when ss (setq offset (+ offset 1))))))  ; newline between lines
    offset))

(defun my-kp-comment-line-p ()
  "Return non-nil if this line begins with a comment.
Checks `comment-start-skip' first, which correctly identifies comment
openers (e.g. `// ...' or `;; ...') even though `syntax-ppss' at the
delimiter characters themselves does not yet report being in a comment.
Falls back to `syntax-ppss' for block-comment continuation lines
\(e.g. ` * ...') where the first non-whitespace char is already inside
an open comment and `comment-start-skip' does not match."
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " \t")
    (and (not (eolp))
         (or (and comment-start-skip (looking-at comment-start-skip))
             (nth 4 (syntax-ppss))))))

(defun my-kp-prog-clamp-bounds (start end)
  "In `prog-mode', shrink START..END to the contiguous block of lines
matching point's comment status.  Starts from the line at point and
expands outward, stopping when the adjacent line no longer matches.
Returns a (NEW-START . NEW-END) cons.  Outside `prog-mode' returns
\(START . END)."
  (if (not (derived-mode-p 'prog-mode))
      (cons start end)
    (let ((target (my-kp-comment-line-p)))
      (cons
       ;; Walk backward while the previous line also matches.
       (save-excursion
         (beginning-of-line)
         (while (and (> (point) start)
                     (save-excursion
                       (forward-line -1)
                       (eq (my-kp-comment-line-p) target)))
           (forward-line -1))
         (line-beginning-position))
       ;; Walk forward while the next line also matches.
       (save-excursion
         (beginning-of-line)
         (while (and (< (line-end-position) end)
                     (save-excursion
                       (forward-line 1)
                       (eq (my-kp-comment-line-p) target)))
           (forward-line 1))
         (line-end-position))))))

(defun my-fill-paragraph-kp (&optional _justify)
  "Fill the paragraph at point using the Knuth-Plass algorithm.
Unlike \\[fill-paragraph] (greedy), this minimises total squared slack
across all non-final lines.  The last line is never penalised for being
short.  Wide characters (CJK etc.) count as 2 columns via `string-width'.
Respects `sentence-end-double-space'.  In `prog-mode', comment lines and
code lines are never merged.

Bound to \\[my-fill-paragraph-kp]."
  (interactive "P")
  (let* ((orig      (point))
         (raw-start (save-excursion
                      (backward-paragraph 1)
                      (skip-chars-forward " \t\n")
                      (line-beginning-position)))
         (raw-end   (save-excursion
                      (forward-paragraph 1)
                      (skip-chars-backward " \t\n")
                      (point)))
         (bounds    (my-kp-prog-clamp-bounds raw-start raw-end))
         (start     (car bounds))
         (end       (cdr bounds))
         (prefix    (or fill-prefix
                        (and adaptive-fill-mode
                             (let ((p (fill-context-prefix start end)))
                               (and (stringp p) p)))
                        ""))
         (max-w     (max 1 (- fill-column (string-width prefix))))
         (words     (my-kp-words-in-region start end prefix)))
    (when words
      (let* ((widths (vconcat (mapcar #'string-width words)))
             (gaps   (my-kp-compute-gaps words))
             (breaks (my-kp-compute-breaks words widths gaps max-w))
             (text   (my-kp-join-lines words gaps breaks prefix))
             (in-par (and (>= orig start) (<= orig end)))
             (n-bef  (when in-par
                       (length (my-kp-words-in-region start orig prefix)))))
        (if in-par
            (progn
              (goto-char start)
              (delete-region start end)
              (insert text)
              (goto-char (+ start (my-kp-word-offset
                                   (vconcat words) gaps breaks prefix n-bef))))
          (save-excursion
            (goto-char start)
            (delete-region start end)
            (insert text)))))))

(global-set-key (kbd "M-j") #'my-fill-paragraph-kp)

;;;; Markdown:

(use-package markdown-mode
  :mode "\\.md\\'")

;; Don't use a different font for code.
(with-eval-after-load 'markdown-mode
  (set-face-attribute 'markdown-code-face nil :inherit 'default))

;;;; Org:

(defun my-org-mode-hook ()
  "Personal org-mode settings."
  (setq org-special-ctrl-a/e t
        org-startup-folded 'showeverything
        org-use-sub-superscripts '{}
        org-pretty-entities t
        org-log-done t
        ;; Sufficient unto the day is the evil thereof.
        org-deadline-warning-days 0
        ;; Export as HTML5 (default is XHTML).
        org-html-doctype "html5"
        org-html-postamble nil
        org-src-preserve-indentation t))
(add-hook 'org-mode-hook #'my-org-mode-hook)

;;;; Programming:

(setq gdb-many-windows t
      gdb-show-main t
      gdb-restore-window-configuration-after-quit t
      gdb-debuginfod-enable-setting t)

;; Turn on line numbers by default only in GUI mode.  In the terminal, there are
;; typically fewer columns, so don't waste them.  Tested at hook-fire time so
;; emacsclient frames created under --daemon get the same treatment.
(defun my-prog-mode-line-numbers-hook ()
  "Enable line numbers in graphical prog-mode buffers."
  (when (display-graphic-p)
    (display-line-numbers-mode 1)))
(add-hook 'prog-mode-hook #'my-prog-mode-line-numbers-hook)

;; Suppress "Keep current list of tags tables also?"
(setq tags-add-tables nil)
;; Suppress "Tags file path/to/TAGS has changed, read new contents? (y or n)"
(setq tags-revert-without-query t)

(use-package editorconfig
  :config
  (setq editorconfig-trim-whitespaces-mode 'ws-butler-mode)
  (editorconfig-mode 1))

(with-eval-after-load 'eglot
  (define-key eglot-mode-map (kbd "C-c l r") #'eglot-rename)
  (define-key eglot-mode-map (kbd "C-c <f2>") #'eglot-rename))

;;;; Common Lisp:

;; Add extensions
(add-to-list 'auto-mode-alist '("\\.sbclrc\\'" . lisp-mode)) ; SBCL config file
(add-to-list 'auto-mode-alist '("\\.cl\\'" . lisp-mode)) ; *.cl files

(defun my-lisp-mode-hook ()
  "Load slime on first lisp-mode entry."
  (setq indent-tabs-mode nil)
  (unless (featurep 'slime)
    (require 'slime)
    (normal-mode)))

(when (executable-find "sbcl")
  ;; The lisp-mode hook above loads slime on first use via `require'.
  (use-package slime
    :defer t)
  (add-hook 'lisp-mode-hook #'my-lisp-mode-hook)
  (setq inferior-lisp-program "sbcl"))

;;;; C-family Programming Languages:

;; Derived from both:
;; https://stackoverflow.com/a/1450454
;; https://www.emacswiki.org/emacs/BackspaceWhitespaceToTabStop
;; (c) Trey Jackson, epich; CC BY-SA 4.0
(defun my-backspace-whitespace-to-tab-stop ()
  "Delete whitespace backwards to the next tab-stop, otherwise delete one character."
  (interactive)
  (if indent-tabs-mode
      (call-interactively 'backward-delete-char)
    (let ((movement (% (current-column) tab-width))
          (p (point)))
      (when (= movement 0) (setq movement tab-width))
      ;; Account for edge case near beginning of buffer
      (setq movement (min (- p 1) movement))
      (save-match-data
        (if (string-match "[^\t ]*\\([\t ]+\\)$" (buffer-substring-no-properties (- p movement) p))
            (backward-delete-char (- (match-end 1) (match-beginning 1)))
          (call-interactively 'backward-delete-char))))))

(with-eval-after-load 'cc-mode
  (define-key c-mode-base-map (kbd "C-m") 'c-context-line-break))

(defun my-c-mode-common-hook ()
  (setq-local c-auto-align-backslashes nil)
  (local-set-key (kbd "DEL") 'my-backspace-whitespace-to-tab-stop))

(add-hook 'c-mode-common-hook #'my-c-mode-common-hook)

;; Format C/C++ buffers on save when `clang-format' is available and the file
;; lives in a project with a `.clang-format' file.
(when (executable-find "clang-format")
  (use-package clang-format
    :commands (clang-format-buffer))
  (defun my-clang-format-on-save ()
    "Run `clang-format-buffer' if a `.clang-format' file exists in the project."
    (when (and buffer-file-name
               (locate-dominating-file buffer-file-name ".clang-format"))
      (clang-format-buffer)))
  (defun my-clang-format-setup ()
    "Install a buffer-local before-save hook to run clang-format."
    (add-hook 'before-save-hook #'my-clang-format-on-save nil t))
  (add-hook 'c-mode-hook #'my-clang-format-setup)
  (add-hook 'c++-mode-hook #'my-clang-format-setup))

;;;; C:

(setq-default c-tab-always-indent nil)

;; If supported, use Doxygen style for C/C++ rather than the GtkDoc.
(setq-default c-doc-comment-style
              '((java-mode . javadoc)
                (pike-mode . autodoc)
                (c-mode    . doxygen)
                (c++-mode  . doxygen)))

(setq c-default-style "linux")

;; C styles based on path patterns.  The value can either be a string (e.g.,
;; "linux") or a function.  The path patterns are tested from first to last, and
;; the first match wins.  Buffers whose path matches no pattern fall through to
;; CC-mode's own `c-default-style' (set above).
;;
;; local-init.el can add entries for the local machine.
(defvar my-c-dir-styles
  '(("linux" . "linux")
    ("freebsd" . "bsd")
    ("openbsd" . "bsd")
    ("gnu" . "gnu"))
  "Mapping between path patterns and C coding style.")

(when *is-linux*
  (add-to-list 'my-c-dir-styles '("/usr/src" . "linux")))
(when *is-bsd*
  (add-to-list 'my-c-dir-styles '("/usr/src" . "bsd")))

(defun my-c-style-from-path ()
  "Set C style based on its path pattern."
  (let ((style (assoc-default buffer-file-name my-c-dir-styles
                              (lambda (pattern path)
                                (and (stringp path)
                                     (string-match pattern path))))))
    (cond
     ((stringp style) (c-set-style style))
     ((functionp style) (funcall style)))))

(add-hook 'c-mode-hook #'my-c-style-from-path)

;;;; Just:

(use-package just-mode
  :mode (("\\.just\\'" . just-mode)
         ("[Jj]ustfile\\'" . just-mode)))

;;;; Makefile:

(add-to-list 'auto-mode-alist '("\\.mak\\'" . makefile-gmake-mode))

(defun my-makefile-gmake-mode-hook ()
  "Use real tabs in Makefiles."
  (setq indent-tabs-mode t
        tab-width 8))
(add-hook 'makefile-gmake-mode-hook #'my-makefile-gmake-mode-hook)

;;;; Meson:

(use-package meson-mode
  :mode (("meson\\.build\\'" . meson-mode)
         ("meson_options\\.txt\\'" . meson-mode)))

;;;; Shell:

(setq sh-styles-alist
      '(("my-sh"
         (sh-basic-offset . 2)
         (sh-first-lines-indent . 0)
         (sh-indent-after-case . +)
         (sh-indent-after-do . +)
         (sh-indent-after-done . 0)
         (sh-indent-after-else . +)
         (sh-indent-after-if . +)
         (sh-indent-after-loop-construct . +)
         (sh-indent-after-open . +)
         (sh-indent-comment . t)
         (sh-indent-for-case-alt . +)
         (sh-indent-for-case-label . 0)
         (sh-indent-for-continuation . +)
         (sh-indent-for-do . 0)
         (sh-indent-for-done . 0)
         (sh-indent-for-else . 0)
         (sh-indent-for-fi . 0)
         (sh-indent-for-then . 0))))
(defun my-sh-set-shell-hook ()
  "Apply the `my-sh' style to shell-script buffers."
  (sh-load-style "my-sh"))
(add-hook 'sh-set-shell-hook #'my-sh-set-shell-hook)

;;;; Nushell:

(use-package nushell-mode
  :mode "\\.nu\\'")

;;;; Lua:

(use-package lua-mode
  :mode "\\.lua\\'")

;;;; Go:

(use-package go-mode
  :mode "\\.go\\'")

;;;; Rust:

(use-package rust-mode
  :mode "\\.rs\\'"
  :init
  (when (executable-find "rustfmt")
    (setq rust-format-on-save t)))

;;;; Nix:

(use-package nix-mode
  :mode "\\.nix\\'")

;;;; Local Changes:

(let ((local-init (my-emacs-d-path "local-init.el")))
  (when (file-exists-p local-init)
    (load-file local-init)))

(setq custom-file (my-emacs-d-path "custom.el"))
(when (file-exists-p custom-file)
  (load-file custom-file))

;;; init.el ends here
