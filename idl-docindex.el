 ;;; idl-docindex.el --- 

;; $Id$

;; Copyright (C) 2003 Free Software Foundation, Inc.
;; Copyright (C) 2003 Kevin A. Burton (burton@openprivacy.org)

;; Author: Kevin A. Burton (burton@peerfear.org)
;; Maintainer: Kevin A. Burton (burton@peerfear.org)
;; Location: http://www.peerfear.org/el
;; Keywords: 
;; Version: 1.0.1

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

(defvar idl-docindex--token-alist '() "Buffer name -> file associated list.")

(defvar idl-docindex-data-file "~/.idl-docindex.el" "File for `idl-docindex' file.")

(defun idl-docindex-build-index(path &optional no-save)
  "Build a index starting with the given path."
  (interactive
   (list
    (read-file-name "Build idl-docindex from: ")))

  (let((current-path nil)
       (files (directory-files path)))

    (dolist(file files)

      (setq current-path (concat path "/" file))
      
      ;;go into subdirectories

      (when (and (file-directory-p current-path)
                 (not (string-equal file "."))
                 (not (string-equal file "..")))

        (idl-docindex-build-index current-path t))

      (when (string-match "\\.idl$" file)
        (add-to-list 'idl-docindex--token-alist (cons file current-path)))))

  (message "Found %i tokens... " (length idl-docindex--token-alist))
  
  (when (not no-save)
    (idl-docindex-save)

    (message "Found %i tokens... done" (length idl-docindex--token-alist))))

(defun idl-docindex-save()
  "Save the docindex information to disk."
  (interactive)
  
  (save-excursion

    (let((find-file-hooks nil))    
    
      (set-buffer (find-file-noselect idl-docindex-data-file))
      
      ;;whatever is in this buffer is now obsolete
      (erase-buffer)

      (insert "(setq idl-docindex--token-alist '")
      (prin1 idl-docindex--token-alist (current-buffer))
      (insert ")")
      (save-buffer)
      (kill-buffer (current-buffer))
      
      (message "Wrote %s" idl-docindex-data-file))))

(defun idl-docindex-load()
  "Read the idl-docindex data file from disk"
  (when (file-readable-p idl-docindex-data-file)
    (message "Reading %s..." idl-docindex-data-file)
    
    (load-file idl-docindex-data-file)
    
    (message "Reading %s...done" idl-docindex-data-file)))

(defun idl-docindex-find-file(name)
  "Use completion (when in an interactive clause) to find the given buffer and
load it."
  (interactive

   (let*((thing (concat (thing-at-point 'word) ".idl"))
         (entry (assoc thing idl-docindex--token-alist)))

     (list
      ;;we don't have an entry... use completion to find what we want from the token list.
      (completing-read "IDL name: "
                       idl-docindex--token-alist
                       nil
                       nil
                       entry))))

  (find-file (cdr (assoc name idl-docindex--token-alist))))

(idl-docindex-load)

(when (boundp 'idl-mode-map)
  (define-key idl-mode-map [C-return] 'idl-docindex-find-file))

(provide 'idl-docindex)

;;; idl-docindex.el ends here