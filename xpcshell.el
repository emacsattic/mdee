;;; xpcshell.el --- Mozilla xpcshell integration for Emacs.

;; $Id$

;; Copyright (C) 2000-2003 Free Software Foundation, Inc.
;; Copyright (C) 2000-2003 Kevin A. Burton (burton@openprivacy.org)

;; Author: Kevin A. Burton (burton@openprivacy.org)
;; Maintainer: Kevin A. Burton (burton@openprivacy.org)
;; Location: http://relativity.yi.org
;; Keywords: 
;; Version: 1.0.0

;; This file is [not yet] part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 2 of the License, or any later version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.
;;
;; You should have received a copy of the GNU General Public License along with
;; this program; if not, write to the Free Software Foundation, Inc., 59 Temple
;; Place - Suite 330, Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; Mozilla xpcshell javascript interpreter shell implementation.

;; NOTE: If you enjoy this software, please consider a donation to the EFF
;; (http://www.eff.org)

;;; Code:

;;FIXME: we should try to find out if this is in the PATH or default to
;;/usr/lib/mozilla/xpcshell or test other locations.
(defcustom xpcshell-shell-command "xpcshell"
  "Command to use to execute xpcshell."
  :type 'string
  :group 'xpcshell)

;;do some sanity checks on xpcshell-shell-command to see if we have a better
;;place for it

(defcustom xpcshell-shell-command-args  '()
  "*Command line arguments for `xpcshell-shell-command'."
  :type '(repeat (string :tag "Argument"))
  :group 'xpcshell)

(defcustom xpcshell-shell-prompt-pattern "^js> *"
  "*xpcshell shell prompt pattern."
  :type 'regexp
  :group 'xpcshell)

(defcustom xpcshell-shell-mode-hook nil
  "Hook for customizing `xpcshell-shell-mode'."
  :type 'hook
  :group 'xpcshell)

(defcustom xpcshell-init-on-startup nil
  "When enabled we will startup xpcshell when Emacs starts up.  This is a nice
feature because this allows us to be certain that the xpcshell is always running
and since it is mostly async code we don't have much of a performance hit."
  :type 'boolean
  :group 'xpcshell)

(defcustom xpcshell-suppress-function-bodies t
  "*When enabled we will replace function body definitions with ... bodies so
that the xpcshell output isn't as verbose."
  :type 'boolean
  :group 'xpcshell)

(defvar xpcshell-buffer-name "*xpcshell*" "Temp buffer name for xpcshell.")

(defun xpcshell()
  "Mozilla xpcshell integration."

  (interactive)

  ;;make sure we init required environment variables under Linux
  (dolist(var '("LD_LIBRARY_PATH" "MOZILLA_FIVE_HOME"))
    (when (null (getenv var))
      (setenv var (file-name-directory xpcshell-shell-command))))

  ;;FIXME: become much smarter to verify that the 'xpcshell' command can be
  ;;executed.  Also check the PATH to see if it is there too.
  
  (unless (comint-check-proc xpcshell-buffer-name)

    (set-buffer (get-buffer-create xpcshell-buffer-name))
    
    ;;use the default directory of xpcshell for all new shells so we can
    ;;have a chance to load .js files
    (let((default-directory (file-name-directory (locate-library "xpcshell"))) )
      (apply 'make-comint "xpcshell"
             xpcshell-shell-command nil xpcshell-shell-command-args))
    
    (xpcshell-shell-mode))

  (display-buffer xpcshell-buffer-name)
  (set-window-point (get-buffer-window xpcshell-buffer-name)
                    (save-excursion
                      (set-buffer xpcshell-buffer-name)
                      (point-max))))

(defun xpcshell-shell-mode ()
  "Major mode for interacting with a xpcshell shell."
  (comint-mode)
  (setq comint-prompt-regexp xpcshell-shell-prompt-pattern)
  (setq major-mode 'xpcshell-shell-mode)
  (setq mode-name "xpcshell")
  (setq mode-line-process '(":%s"))
  (run-hooks 'xpcshell-shell-mode-hook))

(defun xpcshell-eval-region(begin end)
  "Evaluate the region in the xpcshell.  See `eval-region' for an example in
lisp."
  (interactive "r")

  (xpcshell-eval-string (buffer-substring-no-properties begin end)))

(defun xpcshell-eval-string(string)
  "Evaluate the region in the xpcshell.  See `eval-region' for an example in
lisp."
  (interactive
   (read-string "Eval javascript: "))
  
  (let* ((process (get-process "xpcshell"))
         (comint-eol-on-send nil)
         (point-at-end-before-eval nil) ;;the point at the end of the buffer before we eval
         (temp-file (make-temp-file "xpcshell"))
         (comint-process-echoes nil))

    ;;FIXME: the default directory hack is not working 
    
    ;;make the region one long string so that multiple shell prompts aren't issued

    ;;get rid of comments... 

    ;;try to startup the xpcshell
    (when (not process)
      (xpcshell))
    
    (if process
        (save-excursion
          (set-buffer (process-buffer process))
          (goto-char (point-max))

          (setq point-at-end-before-eval (point-max))

          ;;write out the temp file
          (save-excursion
            (set-buffer (get-buffer-create "*temp*"))
            (insert string)

            (write-region (point-min) (point-max) temp-file nil 'no-wrote)
          
            (kill-buffer (current-buffer)))
        
          (comint-send-string process (format "load( \"%s\");" temp-file))
          (call-interactively 'comint-send-input)

          (if (not (accept-process-output process 10 100))
              (error "No reply from xpcshell"))

          ;;we should be using a process sentinel
          (xpcshell-cleanup-prompts point-at-end-before-eval
                                    (point-max))

          ;;remove the temp file?
          (delete-file temp-file)
        
          (goto-char (point-max))
        
          ;;go back to the xpcshell buffer
          (xpcshell))
      (error "xpcshell process not running"))))

(defun xpcshell-cleanup-prompts(begin end)
  "Given a region, clean up the extra prompts within it.  This is necessary
because the xpcshell process will echo a 'js> ' prompt for every variable or
function we declare.  For large files this will result in a long string of
repeated prompts which is annoying (we really only want one)."
  (interactive "r")

  (let((prompt-pattern "js> "))

    ;;cleanup function bodies
    (when xpcshell-suppress-function-bodies
      (save-excursion
        (goto-char begin)
        
        (while (re-search-forward "^function .*$" nil t)
          (let((function-end (match-end 0)))
            (when (re-search-forward prompt-pattern nil t)
              (save-excursion
                (goto-char function-end)
                
                (insert " ... }")
                
                (delete-region (+ 6 function-end) (match-end 0))
                
                ))))))

    ;;clean up js prompts
    (save-excursion

      ;;find the bounds off our cleanup
      (goto-char end)
      (when (re-search-backward prompt-pattern begin t)
        (save-restriction

          (narrow-to-region begin
                            (match-beginning 0))

          ;;now search from the beginning to the bounds replaceing the prompts
          (goto-char (point-min))

          (while (re-search-forward prompt-pattern nil t)
            (replace-match "")))))))

(defun xpcshell-eval-buffer(&optional buffer)
  "Evaluate the current buffer."
  (interactive)

  (when (null buffer)
    (setq buffer (current-buffer)))

  (xpcshell-eval-region (point-min) (point-max)))

(defun xpcshell-emacs-startup-hook()
  "Perform all operations we need on emacs startup."
  
  (when xpcshell-init-on-startup
    (save-window-excursion
      (xpcshell))))

;;add ECB compilation buffer suppprt
(when (boundp 'ecb-compilation-buffer-names)
  (add-to-list 'ecb-compilation-buffer-names (cons xpcshell-buffer-name nil)))

(add-hook 'emacs-startup-hook 'xpcshell-emacs-startup-hook)

(provide 'xpcshell)

;;; xpcshell.el ends here
