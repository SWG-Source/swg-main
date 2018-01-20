;;
;; Copyright 2001, Sony Online Entertainment, Inc.
;; All rights reserved.
;;

;;; declare variables
(defvar workspace-directory nil "workspace base directory")
(defvar workspace-completion-obarray nil "workspace completion data")
(defvar workspace-completion-hashsize 2047 "workspace completion hash entry count")
(defvar workspace-headerflip-source-extension-alist '((".c") (".cpp") (".cxx") (".C") (".plsql")) "workspace headerflip source extension alist")
(defvar workspace-headerflip-header-extension-alist '((".h") (".hpp") (".hxx") (".plsqlh")) "workspace headerflip header extension alist")

;;; Read a file containing workspace entries.  Each line contains
;;; the short filename followed by the path to the filename.  The
;;; path listed is relative to the workspace file path.

(defun workspace-find-workspace (workspace-pathname)
  "Open a workspace file.  Replaces any existing workspace file."
  (interactive "fWorkspace Filename: ")
  
  ;; pull directory out of the workspace pathname.  we'll need it later.
  (posix-string-match "\\(.*/\\).*$" workspace-pathname)
  (setq workspace-directory (substring workspace-pathname (match-beginning 1) (match-end 1)))

  ;; create a temp buffer for workspace processing
  (with-temp-buffer

    ;; insert-file-contents of the workspace file
    (insert-file-contents workspace-pathname)

    ;; initialize completion hash
    (setq workspace-completion-obarray (make-vector workspace-completion-hashsize 0))

    ;; build lookup table entry for each entry in workspace
    (while (posix-search-forward "^\\(.*\\):\\(.*\\)$" nil t)

      ;; add entry to completion obarray
      (let
	  (
	   (completion-entry (intern-soft (match-string 1) workspace-completion-obarray))
	   (completion-data (list (match-string 2)))
	   )

	(if completion-entry
	    ;; entry already in array, append completion data to entry's list value
	    (set completion-entry (append (symbol-value completion-entry) completion-data))
	  
	  ;; entry doesn't exist, create it and set value to completion-data list
	  (setq completion-entry (intern (match-string 1) workspace-completion-obarray))
	  (set completion-entry completion-data)
	  )
	)
      )
    )
  )

;;; workspace-find-file function.  This works like find-file (C-x f),
;;; but allows the user to enter the short filename of a workspace
;;; file instead of the whole path.  If there is only one file with
;;; the given short filename, that file will be opened.  If multiple
;;; files exist in the workspace with the same short name, the user is
;;; prompted to differentiate which one is desired.  Standard Emacs
;;; completion is available at all stages.

(defun workspace-find-file ()
  "Find file within workspace using short filename (no path)."
  (interactive)

  (let (
	(completion-entry-name (completing-read "Workspace Filename: " workspace-completion-obarray nil t))
	)
    (let (
	  (completion-entry (intern completion-entry-name workspace-completion-obarray))
	  )
      (let (
	    (completion-list (symbol-value completion-entry))
	    (completion-list-copy ())
	    (directory nil)
	    (path-completion-list ())
	    ; (full-pathname (concat workspace-directory (car (symbol-value completion-entry)) completion-entry-name))
	    )

	;; if there's only one completion entry, open it.  Otherwise, we need to
	;; provide the user with a selection of files to open.
	(if (null (cdr completion-list))
	    ;; only one entry, no selection required
	    (find-file (concat workspace-directory (car completion-list) completion-entry-name))
	  
	  ;; multiple entries for the short filename.  must provide a choice.
	  ;; build short filename's path completion list.
	  (setq completion-list-copy (copy-sequence completion-list))
	  (while (setq directory (car completion-list-copy))
	    ;; add directory + short filename to alist of choices.
	    ;; note: the alist does not associate anything with the pathname in this case.
	    (setq path-completion-list (cons (list (concat directory completion-entry-name)) path-completion-list))

	    ;; remove directory from copy list
	    (setq completion-list-copy (cdr completion-list-copy))
	    )

	  ;; ask user to choose workspace pathname
	  (let (
		(chosen-filename (completing-read "Choose path: " path-completion-list nil t))
		)
	    (find-file (concat workspace-directory chosen-filename))
	    )
	  )
	)
      )
    )
  )

;;; Function used internally to find and open the first existing file
;;; that starts with a given base filename and an assoc-list of
;;; extensions.

(defun workspace-open-base-find-extension (pathname-base extension-alist)
  "Workspace internal function used to try to open a given base filename trying to append each extension in the alist."

  ;; open the first pathname (base + ext) that exists
  (let (
	(alist-copy (copy-sequence extension-alist))
	(alist-entry nil)
	(extension nil)
	(try-pathname nil)
	)
    (while (setq alist-entry (car alist-copy))
      ;; get extension
      (setq extension (car alist-entry))
      
      ;; build try pathname
      (setq try-pathname (concat pathname-base extension))

      ;; open file if filename is exists and is readable
      (if (file-readable-p try-pathname)
	  (find-file try-pathname))

      ;; increment loop
      (setq alist-copy (cdr alist-copy))
      )
    )
  )

;;; This funciton provides header-flip functionality.  If the user is
;;; in a source-code implementation file, execution of this function
;;; will open the corresponding header file (or vice versa).
;;; Implementation and header file extensions are defined in separate
;;; assoc-lists at the top of this file.

(defun workspace-header-flip ()
  "Flip between header and implementation file."
  (interactive)

  ;; get pathname of current buffer
  (let (
	(pathname (buffer-file-name))
	(extension nil)
	(pathname-no-extension nil)
	(is-source nil)
	(is-header nil)
	)
    
    ;; find extension of pathname
    (posix-string-match "\\(.*\\)\\(\\..*\\)$" pathname)
    (if (match-beginning 2)
	;; we have an extension
	(progn
	  ;; get the extension
	  (setq extension (substring pathname (match-beginning 2) (match-end 2)))

	  ;; determine if we're considered a source or header
	  (if (assoc extension workspace-headerflip-source-extension-alist)
	      (setq is-source t))
	  (if (assoc extension workspace-headerflip-header-extension-alist)
	      (setq is-header t))

	  ;; only do more work if we're a source or header
	  (if (or is-source is-header)
	      (progn
		;; get pathname without extension
		(setq pathname-no-extension (substring pathname (match-beginning 1) (match-end 1)))

		(if is-source
		    ;; if source, try to open base pathname with any header extension attached
		    (workspace-open-base-find-extension pathname-no-extension workspace-headerflip-header-extension-alist)

		  ;; if source, try to open base pathname with any header extension attached
		  (workspace-open-base-find-extension pathname-no-extension workspace-headerflip-source-extension-alist)
		  )
		)
	    )
	  )

      ;; no extension found
      (prin1 (format "failed to find extension for [%s]" pathname))
      )
    )
  )

(provide 'workspace)
