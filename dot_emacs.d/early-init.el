;;; early-init.el --- GNU Emacs early init  -*- lexical-binding: t; -*-

;;; Code:

;; Disable the built-in package manager because straight is being used instead.
(setq package-enable-at-startup nil)

;; The minibuffer doesn't need a scroll bar: disable it.
;; https://www.gnu.org/software/emacs/manual/html_node/elisp/Scroll-Bars.html
(add-hook 'after-make-frame-functions
          (lambda (frame)
            (set-window-scroll-bars
             (minibuffer-window frame) 0 nil 0 nil t)
            (set-window-fringes
             (minibuffer-window frame) 0 0 nil t)))

;;; early-init.el ends here
