#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v8/src/sf/toplev.scm,v 3.3 1987/05/09 23:22:58 cph Exp $

Copyright (c) 1987 Massachusetts Institute of Technology

This material was developed by the Scheme project at the Massachusetts
Institute of Technology, Department of Electrical Engineering and
Computer Science.  Permission to copy this software, to redistribute
it, and to use it for any purpose is granted, subject to the following
restrictions and understandings.

1. Any copy made of this software must include this copyright notice
in full.

2. Users of this software agree to make their best efforts (a) to
return to the MIT Scheme project any improvements or extensions that
they make, so that these may be included in future releases; and (b)
to inform MIT of noteworthy uses of this software.

3. All materials developed as a consequence of the use of this
software shall duly acknowledge such use, in accordance with the usual
standards of acknowledging credit in academic research.

4. MIT has made no warrantee or representation that the operation of
this software will be error-free, and MIT is under no obligation to
provide any services, by way of maintenance, update, or otherwise.

5. In conjunction with products arising from the use of this material,
there shall be no use of the name of the Massachusetts Institute of
Technology nor of any adaptation thereof in any advertising,
promotional, or sales literature without prior written consent from
MIT in each case. |#

;;;; SCode Optimizer: Top Level

(declare (usual-integrations))

;;;; User Interface

(define (integrate/procedure procedure declarations)
  (if (compound-procedure? procedure)
      (procedure-components procedure
	(lambda (*lambda environment)
	  (scode-eval (integrate/scode *lambda declarations false)
		      environment)))
      (error "INTEGRATE/PROCEDURE: Not a compound procedure" procedure)))

(define (integrate/sexp s-expression syntax-table declarations receiver)
  (integrate/simple (lambda (s-expressions)
		      (phase:syntax s-expressions syntax-table))
		    (list s-expression) declarations receiver))

(define (integrate/scode scode declarations receiver)
  (integrate/simple identity-procedure scode declarations receiver))

(define (sf input-string #!optional bin-string spec-string)
  (if (unassigned? bin-string) (set! bin-string false))
  (if (unassigned? spec-string) (set! spec-string false))
  (syntax-file input-string bin-string spec-string))

(define (scold input-string #!optional bin-string spec-string)
  "Use this only for syntaxing the cold-load root file.
Currently only the 68000 implementation needs this."
  (if (unassigned? bin-string) (set! bin-string false))
  (if (unassigned? spec-string) (set! spec-string false))
  (fluid-let ((wrapping-hook wrap-with-control-point))
    (syntax-file input-string bin-string spec-string)))

(define (sf/set-file-syntax-table! pathname syntax-table)
  (pathname-map/insert! file-info/syntax-table
			(pathname/normalize pathname)
			syntax-table))

(define (sf/add-file-declarations! pathname declarations)
  (let ((pathname (pathname/normalize pathname)))
    (pathname-map/insert! file-info/declarations
			  pathname
			  (append! (file-info/get-declarations pathname)
				   (list-copy declarations)))))

(define (file-info/find pathname)
  (let ((pathname (pathname/normalize pathname)))
    (return-2 (pathname-map/lookup file-info/syntax-table
				   pathname
				   identity-procedure
				   (lambda () false))
	      (file-info/get-declarations pathname))))

(define (file-info/get-declarations pathname)
  (pathname-map/lookup file-info/declarations
		       pathname
		       identity-procedure
		       (lambda () '())))

(define (pathname/normalize pathname)
  (pathname-new-version
   (merge-pathnames (pathname->absolute-pathname (->pathname pathname))
		    sf/default-input-pathname)
   false))

(define file-info/syntax-table
  (pathname-map/make))

(define file-info/declarations
  (pathname-map/make))

;;;; File Syntaxer

(define sf/default-input-pathname
  (make-pathname false false false "scm" 'NEWEST))

(define sf/default-externs-pathname
  (make-pathname false false false "ext" 'NEWEST))

(define sf/output-pathname-type "bin")
(define sf/unfasl-pathname-type "unf")

(define (syntax-file input-string bin-string spec-string)
  (let ((eval-sf-expression
	 (lambda (input-string)
	   (let ((input-path
		  (pathname->input-truename
		   (merge-pathnames (->pathname input-string)
				    sf/default-input-pathname))))
	     (if (not input-path)
		 (error "SF: File does not exist" input-string))
	     (let ((bin-path
		    (let ((bin-path
			   (pathname-new-type input-path
					      sf/output-pathname-type)))
		      (if bin-string
			  (merge-pathnames (->pathname bin-string) bin-path)
			  bin-path))))
	       (let ((spec-path
		      (and (or spec-string sfu?)
			   (let ((spec-path
				  (pathname-new-type bin-path
						     sf/unfasl-pathname-type)))
			     (if spec-string
				 (merge-pathnames (->pathname spec-string)
						  spec-path)
				 spec-path)))))
		 (syntax-file* input-path bin-path spec-path)))))))
    (if (list? input-string)
	(for-each (lambda (input-string)
		    (eval-sf-expression input-string))
		  input-string)
	(eval-sf-expression input-string)))
  *the-non-printing-object*)

(define (syntax-file* input-pathname bin-pathname spec-pathname)
  (let ((start-date (date))
	(start-time (time))
	(input-filename (pathname->string input-pathname))
	(bin-filename (pathname->string bin-pathname))
	(spec-filename (and spec-pathname (pathname->string spec-pathname))))
    (newline)
    (write-string "Syntax file: ")
    (write input-filename)
    (write-string " ")
    (write bin-filename)
    (write-string " ")
    (write spec-filename)
    (transmit-values
	(transmit-values (file-info/find input-pathname)
	  (lambda (syntax-table declarations)
	    (integrate/file input-pathname syntax-table declarations
			    spec-pathname)))
      (lambda (expression externs events)
	(fasdump (wrapping-hook
		  (make-comment `((SOURCE-FILE . ,input-filename)
				  (DATE . ,start-date)
				  (TIME . ,start-time)
				  (FLUID-LET . ,*fluid-let-type*))
				(set! expression false)))
		 bin-pathname)
	(write-externs-file (pathname-new-type
			     bin-pathname
			     (pathname-type sf/default-externs-pathname))
			    (set! externs false))
	(if spec-pathname
	    (begin (newline)
		   (write-string "Writing ")
		   (write spec-filename)
		   (with-output-to-file spec-pathname
		     (lambda ()
		       (newline)
		       (write `(DATE ,start-date ,start-time))
		       (newline)
		       (write `(FLUID-LET ,*fluid-let-type*))
		       (newline)
		       (write `(SOURCE-FILE ,input-filename))
		       (newline)
		       (write `(BINARY-FILE ,bin-filename))
		       (for-each (lambda (event)
				   (newline)
				   (write `(,(car event)
					    (RUNTIME ,(cdr event)))))
				 events)))
		   (write-string " -- done")))))))

(define (read-externs-file pathname)
  (let ((pathname
	 (merge-pathnames (->pathname pathname) sf/default-externs-pathname)))
    (if (file-exists? pathname)
	(fasload pathname)
	(begin (warn "Nonexistent externs file" (pathname->string pathname))
	       '()))))

(define (write-externs-file pathname externs)
  (cond ((not (null? externs))
	 (fasdump externs pathname))
	((file-exists? pathname)
	 (delete-file pathname))))

(define (print-spec identifier names)
  (newline)
  (newline)
  (write-string "(")
  (write identifier)
  (let loop
      ((names
	(sort names
	      (lambda (x y)
		(string<? (symbol->string x)
			  (symbol->string y))))))
    (if (not (null? names))
	(begin (newline)
	       (write (car names))
	       (loop (cdr names)))))
  (write-string ")"))

(define (wrapping-hook scode)
  scode)

(define control-point-tail
  `(3 ,(primitive-set-type (microcode-type 'NULL) (* 4 4))
      () () () () () () () () () () () () () () ()))

(define (wrap-with-control-point scode)
  (system-list-to-vector type-code-control-point
			 `(,return-address-restart-execution
			   ,scode
			   ,system-global-environment
			   ,return-address-non-existent-continuation
			   ,@control-point-tail)))

(define type-code-control-point
  (microcode-type 'CONTROL-POINT))

(define return-address-restart-execution
  (make-return-address (microcode-return 'RESTART-EXECUTION)))

(define return-address-non-existent-continuation
  (make-return-address (microcode-return 'NON-EXISTENT-CONTINUATION)))

;;;; Optimizer Top Level

(define (integrate/file file-name syntax-table declarations compute-free?)
  (integrate/kernel (lambda ()
		      (phase:syntax (phase:read file-name) syntax-table))
		    declarations))

(define (integrate/simple preprocessor input declarations receiver)
  (transmit-values
      (integrate/kernel (lambda () (preprocessor input)) declarations)
    (or receiver
	(lambda (expression externs events)
	  expression))))

(define (integrate/kernel get-scode declarations)
  (fluid-let ((previous-time false)
	      (previous-name false)
	      (events '()))
    (transmit-values
	(transmit-values
	    (transmit-values
		(phase:transform (canonicalize-scode (get-scode) declarations))
	      phase:optimize)
	  phase:generate-scode)
      (lambda (externs expression)
	(end-phase)
	(return-3 expression externs (reverse! events))))))

(define (canonicalize-scode scode declarations)
  (let ((declarations
	 ((access process-declarations syntaxer-package) declarations)))
    (if (null? declarations)
	scode
	(scan-defines (make-sequence
		       (list (make-block-declaration declarations)
			     scode))
		      make-open-block))))

(define (phase:read filename)
  (mark-phase "Read")
  (read-file filename))

(define (phase:syntax s-expression #!optional syntax-table)
  (if (or (unassigned? syntax-table) (not syntax-table))
      (set! syntax-table (make-syntax-table system-global-syntax-table)))
  (mark-phase "Syntax")
  (syntax* s-expression syntax-table))

(define (phase:transform scode)
  (mark-phase "Transform")
  (transform/expression scode))

(define (phase:optimize block expression)
  (mark-phase "Optimize")
  (integrate/expression block expression))

(define (phase:generate-scode operations environment expression)
  (mark-phase "Generate SCode")
  (return-2 (operations->external operations environment)
	    (cgen/expression expression)))

(define previous-time)
(define previous-name)
(define events)

(define (mark-phase this-name)
  (end-phase)
  (newline)
  (write-string "    ")
  (write-string this-name)
  (write-string "...")
  (set! previous-name this-name))

(define (end-phase)
  (let ((this-time (runtime)))
    (if previous-time
	(let ((dt (- this-time previous-time)))
	  (set! events (cons (cons previous-name dt) events))
	  (newline)
	  (write-string "    Time: ")
	  (write dt)
	  (write-string " seconds.")))
    (set! previous-time this-time)))