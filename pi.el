;;; pi.el --- Run Pi coding agent in VTERM with project awareness -*- lexical-binding: t; -*-

;; Author: Levi Strope <levi.strope@gmail.com>
;; Maintainer: Levi Strope <levi.strope@gmail.com>
;; Copyright (C) 2025 Levi Strope
;; Version: 0.1.0
;; URL: https://github.com/localredhead/pi.el
;; Package-Requires: ((emacs "27.1") (vterm "0.0.2"))
;; Keywords: tools, processes
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

;;; SPDX-License-Identifier: Apache-2.0

;;; Commentary:

;; Run Pi (https://github.com/mariozechner/pi-coding-agent) coding agent inside Emacs
;; using `vterm` (emacs-libvterm).  VTERM handles ANSI cursor positioning,
;; interactive menus, and mouse events correctly — giving you the full Pi
;; TUI experience inside Emacs.
;;
;; Quick start:
;;   M-x pi                     ; Launch Pi in the current project's buffer
;;   M-x pi-toggle              ; Show / hide Pi (preserves session)
;;   M-x pi-cwd                 ; Launch Pi using current directory
;;   M-x pi-other-window        ; Launch in another window
;;   C-u M-x pi                 ; Force a fresh session
;;
;; Customization:
;;   M-x customize-group RET pi RET

;;; Code:

(require 'cl-lib)
(require 'subr-x)

;;---------------------------------------------------------------------------
;; Vterm declarations (loaded at runtime)
;;---------------------------------------------------------------------------
(declare-function vterm "vterm")
(declare-function vterm-mode "vterm")
(declare-function vterm-send-string "vterm" (string))
(declare-function vterm-send-return "vterm" ())
(declare-function vterm-check-proc "vterm" (&optional buffer))
(declare-function vterm--get-shell "vterm")
(defvar vterm-shell)
(defvar vterm-buffer-name)

;;---------------------------------------------------------------------------
;; Project.el declarations (Emacs 27+)
;;---------------------------------------------------------------------------
(declare-function project-root "project" (&optional project))

;;---------------------------------------------------------------------------
;; Customization
;;---------------------------------------------------------------------------

(defgroup pi nil
  "Run Pi coding agent inside VTERM with project awareness."
  :group 'applications
  :prefix "pi-")

(defcustom pi-binary "pi"
  "The shell command used to launch Pi.
Can be a full path or a name found on `exec-path`."
  :type 'string
  :group 'pi)

(defcustom pi-shell shell-file-name
  "Shell to use inside vterm.
Defaults to `shell-file-name'.  Use \"/usr/bin/env zsh -l\" etc."
  :type 'string
  :group 'pi)

(defcustom pi-buffer-name "*pi:%s*"
  "Format string for the Pi vterm buffer name.
The %s placeholder is replaced with the project name."
  :type 'string
  :group 'pi)

(defcustom pi-auto-launch-command t
  "If non-nil, automatically send the `pi` command after shell starts.
When nil, vterm opens to a shell prompt and you type `pi` yourself."
  :type 'boolean
  :group 'pi)

(defcustom pi-startup-wait 1.0
  "Seconds to wait before sending the Pi command after vterm starts.
Increase if your shell is slow to load."
  :type 'number
  :group 'pi)

(defcustom pi-use-project-root t
  "If non-nil, cd to project root before launching Pi.
Uses `project-root' (Emacs 27+) or `projectile-project-root'."
  :type 'boolean
  :group 'pi)

(defcustom pi-display-function #'pop-to-buffer-same-window
  "Function used to display the Pi vterm buffer.
  `pop-to-buffer-same-window'  — Reuse selected window (default)
  `pop-to-buffer'              — Emacs decides
  `switch-to-buffer'           — Always use selected window
  `display-buffer'             — Use `display-buffer-alist' rules"
  :type 'function
  :group 'pi)

(defcustom pi-pre-launch-hook '(pi--maybe-cd-project)
  "Hook run before launching Pi.
Each function receives the vterm buffer."
  :type 'hook
  :group 'pi)


(defcustom pi-mode-line " Pi"
  "Mode line lighter for `pi-mode'."
  :type 'string
  :group 'pi)

;;---------------------------------------------------------------------------
;; Project detection
;;---------------------------------------------------------------------------

(defun pi--project-root ()
  "Return the project root directory, or nil."
  (or (pi--project-el-root)
      (pi--projectile-root)))

(defun pi--project-el-root ()
  "Get project root using Emacs built-in project.el (Emacs 27+)."
  (when (fboundp 'project-current)
    (when-let* ((proj (project-current nil)))
      (when-let* ((root (project-root proj)))
        (file-name-as-directory root)))))

(defun pi--projectile-root ()
  "Get project root using projectile, if available."
  (when (fboundp 'projectile-project-root)
    (when-let* ((root (projectile-project-root)))
      (file-name-as-directory root))))

(defun pi--project-name (dir)
  "Return a short name for DIR suitable for a buffer name."
  (or (and dir (file-name-nondirectory (directory-file-name dir)))
      "unknown"))

(defun pi--maybe-cd-project (buffer)
  "Default hook: cd into the project root in BUFFER."
  (when pi-use-project-root
    (when-let* ((root (pi--project-root)))
      (let ((cmd (concat "cd " (shell-quote-argument root) "\n")))
        (with-current-buffer buffer
          (when (fboundp 'vterm-send-string)
            (vterm-send-string cmd)))))))

;;---------------------------------------------------------------------------
;; Buffer management
;;---------------------------------------------------------------------------

(defun pi--buffer-name (dir)
  "Generate a buffer name based on DIR."
  (format pi-buffer-name (pi--project-name dir)))

(defun pi--find-existing (dir)
  "Return a live Pi vterm buffer for DIR, or nil."
  (let ((buf (get-buffer (pi--buffer-name dir))))
    (when (and buf
               (buffer-live-p buf)
               (with-current-buffer buf
                 (and (derived-mode-p 'vterm-mode)
                      (fboundp 'vterm-check-proc)
                      (vterm-check-proc buf))))
      buf)))

;;---------------------------------------------------------------------------
;; Core launch
;;---------------------------------------------------------------------------

(defun pi--send-pi-command ()
  "Send the Pi command into the current vterm buffer.
Scheduled after a delay so the shell prompt is ready."
  (when pi-auto-launch-command
    (let ((buf (current-buffer)))
      (run-at-time pi-startup-wait nil
        (lambda ()
          (with-current-buffer buf
            (when (and (derived-mode-p 'vterm-mode)
                       (fboundp 'vterm-send-string))
              (vterm-send-string pi-binary)
              (vterm-send-return))))))))

;;;###autoload
(defun pi (&optional dir other-window force-new)
  "Launch Pi in a VTERM buffer with project awareness.

DIR is the working directory (defaults to project root or `default-directory').
OTHER-WINDOW  — if non-nil, display in another window.
FORCE-NEW     — if non-nil, create a fresh session even if one exists.

Interactively:
  M-x pi              Use current project
  C-u M-x pi          Force new session"
  (interactive
   (list (pi--project-root)
         nil
         current-prefix-arg))

  (unless (executable-find pi-binary)
    (user-error "pi: binary `%s' not found on exec-path" pi-binary))

  (unless (require 'vterm nil t)
    (user-error "pi: the `vterm' package is required. Install from MELPA."))

  (catch 'pi
    (let ((work-dir (file-name-as-directory
                     (or dir
                         (and pi-use-project-root (pi--project-root))
                         default-directory))))

      ;; Reuse existing session
      (unless force-new
        (when-let* ((buf (pi--find-existing work-dir)))
          (funcall (if other-window #'pop-to-buffer pi-display-function) buf)
          (message "pi: switched to existing session")
          (throw 'pi buf)))

      ;; Create new vterm buffer
      (let* ((buf-name (pi--buffer-name work-dir))
             (buf (generate-new-buffer buf-name)))
        ;; Dynamically bind vterm vars before launching the buffer
        (let ((vterm-shell pi-shell)
              (vterm-buffer-name buf-name))
          (funcall (if other-window #'pop-to-buffer pi-display-function) buf)
          (with-current-buffer buf
            (unless (derived-mode-p 'vterm-mode)
              (vterm-mode))
            (pi-mode 1)
            (run-hook-with-args 'pi-pre-launch-hook buf)
            (pi--send-pi-command)))
        (message "pi: launching Pi for %s" work-dir)
        (throw 'pi buf)))))

;;;###autoload
(defun pi-other-window ()
  "Launch Pi in VTERM, displaying in another window."
  (interactive)
  (pi nil t))

;;;###autoload
(defun pi-cwd ()
  "Launch Pi in VTERM using the current buffer's directory (no project lookup)."
  (interactive)
  (pi default-directory nil current-prefix-arg))

;;;###autoload
(defun pi-restart ()
  "Kill the current Pi session and start fresh."
  (interactive)
  (let ((work-dir (or (pi--project-root) default-directory)))
    (when-let* ((buf (pi--find-existing work-dir)))
      (kill-buffer buf)
      (message "pi: killed session for %s" work-dir))
    (pi work-dir nil t)))

;;;###autoload
(defun pi-select ()
  "Display the Pi buffer for the current project, creating if needed."
  (interactive)
  (pi (or (pi--project-root) default-directory)))

;;;###autoload
(defun pi-toggle ()
  "Toggle the Pi vterm buffer visibility.
- If visible in any window → hide the window (session stays alive).
- If exists but not visible → show it in the current window.
- If no session exists → launch a new Pi session.

This is the recommended way to quickly dismiss and restore Pi without
killing the underlying session.  After hiding, all terminal state
(command history, TUI selections, etc.) is preserved."
  (interactive)
  (let* ((work-dir (or (pi--project-root) default-directory))
         (buf (pi--find-existing work-dir)))
    (if buf
        (let ((wins (get-buffer-window-list buf nil t)))
          (if wins
              (progn
                (dolist (w wins)
                  (when (window-live-p w)
                    (condition-case nil
                        ;; Try to delete the window first
                        (delete-window w)
                      (error
                       ;; Protected window — switch to the most recently used
                       ;; buffer other than Pi (respects project context)
                       (with-selected-window w
                         (switch-to-buffer (other-buffer buf t)))))))
                (message "pi: hidden"))
            (funcall pi-display-function buf)
            (message "pi: restored session")))
      (pi work-dir nil t))))

;;---------------------------------------------------------------------------
;; Pi Minor Mode
;;---------------------------------------------------------------------------

(defvar pi-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Note: Doom Emacs users should bind via :map vterm-mode-map
    ;; e.g.  (map! :map vterm-mode-map :leader "p t" #'pi-toggle)
    map)
  "Keymap for `pi-mode'.")

;;;###autoload
(define-minor-mode pi-mode
  "Minor mode for Pi-specific enhancements in a vterm buffer.
Automatically enabled in buffers created by `pi'."
  :lighter pi-mode-line
  :keymap pi-mode-map
  :group 'pi
  (when pi-mode
    (run-hooks 'pi-mode-hook)))

;;---------------------------------------------------------------------------
;; Display helpers
;;---------------------------------------------------------------------------

(defun pi--display-buffer-action ()
  "Return a `display-buffer' action for Pi vterm buffers."
  '((display-buffer-in-side-window)
    (side . bottom)
    (window-height . 0.35)
    (dedicated . t)))

;;;###autoload
(defun pi-setup-display-rules ()
  "Configure `display-buffer-alist' so Pi buffers appear in a side window.
Call this from init.el if you want Pi always in a bottom window."
  (interactive)
  (add-to-list 'display-buffer-alist
               (cons (lambda (name _) (string-prefix-p "*pi:" name))
                     (pi--display-buffer-action))))

(provide 'pi)
;;; pi.el ends here
