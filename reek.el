;;; reek.el --- An Emacs interface for Reek -*- lexical-binding: t -*-

;; Copyright © 2011-2015 Daniel Choi

;; Author: Daniel Choi
;; URL: https://github.com/daniel-choi/reek-emacs
;; Version: 0.1.0
;; Keywords: project, convenience
;; Package-Requires: ((dash "1.0.0") (emacs "24"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; This library allows the user to easily invoke reek to get feedback
;; about stylistic issues in Ruby code.
;;
;;; Code:

(require 'dash)
(require 'tramp)

(defgroup reek nil
  "An Emacs interface for Reek."
  :group 'tools
  :group 'convenience)

(defvar reek-project-root-files
  '(".projectile" ".git" ".hg" ".bzr" "_darcs" "Gemfile")
  "A list of files considered to mark the root of a project.")

(defcustom reek-keymap-prefix (kbd "C-c C-e")
  "Reek keymap prefix."
  :group 'reek
  :type 'string)

(defvar reek-check-command
  "reek --single-line --no-wiki-links --sort-by smelliness"
  "The command used to run Reek checks.")

(defun reek-local-file-name (file-name)
  "Retrieve local filename if FILE-NAME is opened via TRAMP."
  (cond ((tramp-tramp-file-p file-name)
         (tramp-file-name-localname (tramp-dissect-file-name file-name)))
        (t
         file-name)))

(defun reek-project-root ()
  "Retrieve the root directory of a project if available.
The current directory is assumed to be the project's root otherwise."
  (or (->> reek-project-root-files
           (--map (locate-dominating-file default-directory it))
           (-remove #'null)
           (car))
      (error "You're not into a project")))

(defun reek--dir-command (command &optional directory)
  "Run COMMAND on DIRECTORY (if present).
Alternatively prompt user for directory."
  (reek-ensure-installed)
  (let ((directory
         (or directory
             (read-directory-name "Select directory:"))))
    (compilation-start
     (concat command " " (reek-local-file-name directory))
     'compilation-mode
     (lambda (arg) (message arg) (reek-buffer-name directory)))))

(defun reek-buffer-name (file-or-dir)
  "Generate a name for the Reek buffer from FILE-OR-DIR."
  (concat "*Reek " file-or-dir "*"))

;;;###autoload
(defun reek-check-project ()
  "Run on current project."
  (interactive)
  (reek-check-directory (reek-project-root)))

;;;###autoload
(defun reek-check-directory (&optional directory)
  "Run on DIRECTORY if present.
Alternatively prompt user for directory."
  (interactive)
  (reek--dir-command reek-check-command directory))

(defun reek--file-command (command)
  "Run COMMAND on currently visited file."
  (reek-ensure-installed)
  (let ((file-name (buffer-file-name (current-buffer))))
    (if file-name
        (compilation-start
         (concat command " " (reek-local-file-name file-name))
         'compilation-mode
         (lambda (_arg) (reek-buffer-name file-name)))
      (error "Buffer is not visiting a file"))))

;;;###autoload
(defun reek-check-current-file ()
  "Run on current file."
  (interactive)
  (reek--file-command reek-check-command))

(defun reek-ensure-installed ()
  "Check if Reek is installed."
  (unless (executable-find "reek")
    (error "Reek is not installed")))

;;; Minor mode
(defvar reek-mode-map
  (let ((map (make-sparse-keymap)))
    (let ((prefix-map (make-sparse-keymap)))
      (define-key prefix-map (kbd "p") 'reek-check-project)
      (define-key prefix-map (kbd "d") 'reek-check-directory)
      (define-key prefix-map (kbd "f") 'reek-check-current-file)
      (define-key map reek-keymap-prefix prefix-map))
    map)
  "Keymap for Reek mode.")

;;;###autoload
(define-minor-mode reek-mode
  "Minor mode to interface with RuboCop."
  :lighter " Reek"
  :keymap reek-mode-map
  :group 'reek)

(provide 'reek)
