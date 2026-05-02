;;; pi-test.el --- Tests for pi.el -*- lexical-binding: t; -*-

;; Author: Levi Strope <levi.strope@gmail.com>

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

;;; Commentary:

;; Tests for pi.el

;;; Code:

(require 'ert)

(when (not (featurep 'pi))
  (require 'pi))

(ert-deftest pi-test-loaded ()
  "Test that pi.el loads properly."
  (should (featurep 'pi)))

(ert-deftest pi-test-variables ()
  "Test that custom variables are properly defined."
  (should (boundp 'pi-binary))
  (should (boundp 'pi-shell))
  (should (boundp 'pi-buffer-name))
  (should (boundp 'pi-auto-launch-command))
  (should (boundp 'pi-startup-wait))
  (should (boundp 'pi-use-project-root))
  (should (boundp 'pi-display-function))
  (should (boundp 'pi-pre-launch-hook))
  (should (boundp 'pi-mode-hook))
  (should (boundp 'pi-mode-line)))

(ert-deftest pi-test-group ()
  "Test that pi custom group is defined."
  (should (get 'pi 'custom-group)))

(ert-deftest pi-test-functions ()
  "Test that functions are properly defined."
  (should (fboundp 'pi))
  (should (fboundp 'pi-other-window))
  (should (fboundp 'pi-cwd))
  (should (fboundp 'pi-restart))
  (should (fboundp 'pi-select))
  (should (fboundp 'pi-toggle))
  (should (fboundp 'pi--project-root))
  (should (fboundp 'pi--buffer-name))
  (should (fboundp 'pi--find-existing))
  (should (fboundp 'pi--send-pi-command))
  (should (fboundp 'pi-mode))
  (should (fboundp 'pi--display-buffer-action))
  (should (fboundp 'pi-setup-display-rules)))

(ert-deftest pi-test-project-name ()
  "Test that project name extraction works."
  (should (stringp (pi--project-name "/some/path/to/project")))
  (should (equal (pi--project-name "/some/path/to/project") "project"))
  (should (equal (pi--project-name nil) "unknown")))

(ert-deftest pi-test-buffer-name-format ()
  "Test that buffer name format works correctly."
  (let ((pi-buffer-name "*pi:%s*"))
    (should (equal (pi--buffer-name "/path/to/myproject") "*pi:myproject*"))))

(provide 'pi-test)
;;; pi-test.el ends here
