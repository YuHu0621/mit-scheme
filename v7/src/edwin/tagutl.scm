;;; -*-Scheme-*-
;;;
;;;	Copyright (c) 1986 Massachusetts Institute of Technology
;;;
;;;	This material was developed by the Scheme project at the
;;;	Massachusetts Institute of Technology, Department of
;;;	Electrical Engineering and Computer Science.  Permission to
;;;	copy this software, to redistribute it, and to use it for any
;;;	purpose is granted, subject to the following restrictions and
;;;	understandings.
;;;
;;;	1. Any copy made of this software must include this copyright
;;;	notice in full.
;;;
;;;	2. Users of this software agree to make their best efforts (a)
;;;	to return to the MIT Scheme project any improvements or
;;;	extensions that they make, so that these may be included in
;;;	future releases; and (b) to inform MIT of noteworthy uses of
;;;	this software.
;;;
;;;	3. All materials developed as a consequence of the use of this
;;;	software shall duly acknowledge such use, in accordance with
;;;	the usual standards of acknowledging credit in academic
;;;	research.
;;;
;;;	4. MIT has made no warrantee or representation that the
;;;	operation of this software will be error-free, and MIT is
;;;	under no obligation to provide any services, by way of
;;;	maintenance, update, or otherwise.
;;;
;;;	5. In conjunction with products arising from the use of this
;;;	material, there shall be no use of the name of the
;;;	Massachusetts Institute of Technology nor of any adaptation
;;;	thereof in any advertising, promotional, or sales literature
;;;	without prior written consent from MIT in each case.
;;;

;;;; Tags Facility
;;;  From GNU Emacs (thank you RMS)

(declare (usual-integrations))
(using-syntax edwin-syntax-table

(define-command ("Visit Tags Table" argument)
  "Tell tags commands to use a given tags table file."
  (set-variable!
   "Tags Table Pathname"
   (prompt-for-pathname "Visit tags table"
			(or (ref-variable "Tags Table Pathname")
			    (pathname-new-type (current-default-pathname)
					       "TAG")))))

(define-command ("Find Tag" argument)
  "Find tag (in current tags table) whose name contains a given string.
 Selects the buffer that the tag is contained in
and puts point at its definition.
 With argument, searches for the next tag in the tags table that matches
the string used in the previous Find Tag."
  (&find-tag-command argument find-file))

(define-command ("Find Tag Other Window" argument)
  "Like \\[Find Tag], but selects buffer in another window."
  (&find-tag-command argument find-file-other-window))

(define (&find-tag-command previous-tag? find-file)
  (if previous-tag?
      (find-tag previous-find-tag-string
		;; Kludgerous.  User should not be able to flush
		;; tags buffer.  Maybe should be done another way.
		(or (object-unhash previous-find-tag-mark)
		    (editor-error "No previous Find Tag (or buffer killed)"))
		find-file)
      (let ((string (prompt-for-string "Find tag" previous-find-tag-string)))
	(set! previous-find-tag-string string)
	(find-tag string
		  (buffer-start (tags-table-buffer))
		  find-file))))

(define-command ("Generate Tags Table" argument)
  "Generate a tags table from a files list of Scheme files.
 A files list is a file containing only strings which are file names.
 The generated tags table has the same name as the files list, except that
the file type is TAG."
  (let ((pathname
	 (prompt-for-pathname "Files List"
			      (pathname-new-type (current-default-pathname)
						 "FLS"))))
    (let ((truename (pathname->input-truename pathname)))
      (if (not truename) (editor-error "No such file"))
      (make-tags-table (read-file truename)
		       (let ((pathname (pathname-new-type pathname "TAG")))
			 (if (integer? (pathname-version pathname))
			     (pathname-new-version pathname 'NEWEST)
			     pathname))
		       scheme-tag-regexp))))

(define (tags-table-buffer)
  (if (not (ref-variable "Tags Table Pathname"))
      (visit-tags-table-command false))
  (let ((pathname (ref-variable "Tags Table Pathname")))
    (or (pathname->buffer pathname)
	(let ((buffer (new-buffer (pathname->buffer-name pathname))))
	  (read-buffer buffer pathname)
	  (if (not (eqv? (extract-right-char (buffer-start buffer)) #\Page))
	      (editor-error "File " (pathname->string pathname)
			    " not a valid tag table"))
	  buffer))))

(define (tag->pathname tag)
  (define (loop mark)
    (let ((file-mark (skip-chars-backward "^,\n" (line-end mark 1))))
      (let ((mark (mark+ (line-start file-mark 1)
			 (with-input-from-mark file-mark read))))
	(if (mark> mark tag)
	    (string->pathname (extract-string (line-start file-mark 0)
					      (mark-1+ file-mark)))
	    (loop mark)))))
  (loop (group-start tag)))

(define (tags-table-pathnames)
  (let ((buffer (tags-table-buffer)))
    (define (loop mark)
      (let ((file-mark (skip-chars-backward "^,\n" (line-end mark 1))))
	(let ((mark (mark+ (line-start file-mark 1)
			   (with-input-from-mark file-mark read))))
	  (cons (string->pathname (extract-string (line-start file-mark 0)
						  (mark-1+ file-mark)))
		(if (group-end? mark)
		    '()
		    (loop mark))))))
    (or (buffer-get buffer tags-table-pathnames)
	(let ((pathnames (loop (buffer-start buffer))))
	  (buffer-put! buffer tags-table-pathnames pathnames)
	  pathnames))))

;;;; Find Tag

(define previous-find-tag-string
  false)

(define previous-find-tag-mark
  (object-hash false))

(define (find-tag string start find-file)
  (define (loop mark)
    (let ((mark (search-forward string mark)))
      (and mark
	   (or (re-match-forward find-tag-match-regexp mark)
	       (loop mark)))))
  (let ((tag (loop start)))
    (set! previous-find-tag-mark (object-hash tag))
    (if (not tag)
	(editor-failure "Tag not found")
	(let ((regexp
	       (string-append
		"^"
		(re-quote-string (extract-string (mark-1+ tag)
						 (line-start tag 0)))))
	      (start (with-input-from-mark tag read)))
	  (find-file
	   (merge-pathnames (tag->pathname tag)
			    (pathname-directory-path
			     (ref-variable "Tags Table Pathname"))))
	  (let* ((buffer (current-buffer))
		 (group (buffer-group buffer))
		 (end (group-end-index group)))
	    (define (loop offset)
	      (let ((index (- start offset)))
		(if (positive? index)
		    (or (re-search-forward regexp
					   (make-mark group index)
					   (make-mark group
						      (min (+ start offset)
							   end)))
			(loop (* 3 offset)))
		    (re-search-forward regexp (make-mark group 0)))))
	    (buffer-widen! buffer)
	    (push-current-mark! (current-point))
	    (let ((mark (loop 1000)))
	      (if (not mark)
		  (editor-failure "Tag no longer in file")
		  (set-current-point! (line-start mark 0)))))))))

(define find-tag-match-regexp
  (let ((rubout (char->string #\Rubout)))
    (string-append "[^" (char->string char:newline) rubout "]*" rubout)))

;;;; Tags Table Generation

(define scheme-tag-regexp
  "^(def\\(ine-variable\\(\\s \\|\\s>\\)*\"[^\"]+\"\\|ine-command\\(\\s \\|\\s>\\)*(\\(\\s \\|\\s>\\)*\"[^\"]+\"\\|ine-\\(method\\|procedure\\)\\(\\s \\|\\s>\\)+\\(\\sw\\|\\s_\\)+\\(\\(\\s \\|\\s>\\)*(+\\(\\s \\|\\s>\\)*\\|\\(\\s \\|\\s>\\)+\\)\\(\\sw\\|\\s_\\)+\\|\\(\\sw\\|\\s_\\)*\\(\\(\\s \\|\\s>\\)*(+\\(\\s \\|\\s>\\)*\\|\\(\\s \\|\\s>\\)+\\)\\(\\sw\\|\\s_\\)+\\)")

(define (make-tags-table input-filenames output-filename definition-regexp)
  (let ((input-buffer (temporary-buffer " *tags-input*"))
	(output-buffer (temporary-buffer " *tags-output*")))
    (let ((output (buffer-point output-buffer)))
      (define (do-file filename)
	(insert-string "\f\n" output)
	(insert-string filename output)
	(insert-char #\, output)
	(let ((recording-mark (mark-right-inserting output)))
	  (insert-newline output)
	  (let ((file-start (mark-index output)))
	    (read-buffer input-buffer (->pathname filename))
	    (let ((end (buffer-end input-buffer)))
	      (define (definition-loop mark)
		(if (and mark (re-search-forward definition-regexp mark end))
		    (let ((end (re-match-end 0)))
		      (let ((start (line-start end 0)))
			(insert-string (extract-string start end) output)
			(insert-char #\Rubout output)
			(insert-string (write-to-string (mark-index start))
				       output)
			(insert-newline output)
			(definition-loop (line-start start 1))))))
	      (definition-loop (buffer-start input-buffer)))
	    (insert-string (write-to-string (- (mark-index output) file-start))
			   recording-mark))))
      (for-each do-file input-filenames))
    (set-buffer-point! output-buffer (buffer-start output-buffer))
    (kill-buffer input-buffer)
    (set-visited-pathname output-buffer (->pathname output-filename))
    (write-buffer output-buffer)
    (kill-buffer output-buffer)))

;;;; Tags Search

(define-command ("Tags Search" argument)
  "Search through all files listed in tag table for a given string.
Stops when a match is found.
To continue searching for next match, use command \\[Tags Loop Continue]."
  (let ((string
	 (prompt-for-string "Tags Search"
			    (ref-variable "Previous Search String"))))
    (set-variable! "Previous Search String" string)
    (tags-search (re-quote-string string))))

(define-command ("RE Tags Search" argument)
  "Search through all files listed in tag table for a given regexp.
Stops when a match is found.
To continue searching for next match, use command \\[Tags Loop Continue]."
  (let ((regexp
	 (prompt-for-string "RE Tags Search"
			    (ref-variable "Previous Search Regexp"))))
    (set-variable! "Previous Search Regexp" regexp)
    (tags-search regexp)))

(define-command ("Tags Query Replace" argument)
  "Query replace a given string with another one though all files listed
in tag table.  If you exit (C-G or Altmode), you can resume the query
replace with the command \\[Tags Loop Continue]."
  (replace-string-arguments "Tags Query Replace"
    (lambda (source target)
      (let ((replacer (replace-string "Tags Query Replace" false true false)))
	(set! tags-loop-operator
	      (lambda (buffer start)
		(select-buffer-no-record buffer)
		(set-current-point! start)
		(replacer source target))))))
  (set! tags-loop-done clear-message)
  (tags-loop-start (tags-table-pathnames)))

(define-command ("Tags Loop Continue" argument)
  "Continue last \\[Tags Search] or \\[Tags Query Replace] command."
  (let ((buffer (object-unhash tags-loop-buffer)))
    (if (and (not (null? tags-loop-entry))
	     buffer)
	(tags-loop-continue buffer (buffer-point buffer))
	(editor-error "No Tags Loop in progress"))))

(define tags-loop-buffer (object-hash false))
(define tags-loop-entry '())
(define tags-loop-operator)
(define tags-loop-done)

(define (tags-search regexp)
  (set! tags-loop-operator
	(lambda (buffer start)
	  (let ((mark (re-search-forward regexp start)))
	    (and mark
		 (begin (if (not (eq? (current-buffer) buffer))
			    (select-buffer buffer))
			(set-current-point! mark)
			(temporary-message "Tags Search succeeded")
			true)))))
  (set! tags-loop-done
	(lambda ()
	  (editor-failure "Tags Search failed")))
  (tags-loop-start (tags-table-pathnames)))

(define (tags-loop-start entries)
  (set! tags-loop-entry entries)
  (if (null? entries)
      (tags-loop-done)
      (let ((buffer (find-file-noselect (car entries))))
	(set! tags-loop-buffer (object-hash buffer))
	(tags-loop-continue buffer (buffer-start buffer)))))

(define (tags-loop-continue buffer start)
  (if (not (and (buffer-alive? buffer)
		(tags-loop-operator buffer start)))
      (tags-loop-start (cdr tags-loop-entry))))

(define find-file-noselect
  (file-finder identity-procedure))

;;; end USING-SYNTAX
)

;;; Edwin Variables:
;;; Scheme Environment: (access tags-package edwin-package)
;;; Scheme Syntax Table: edwin-syntax-table
;;; Tags Table Pathname: (access edwin-tags-pathname edwin-package)
;;; End:
