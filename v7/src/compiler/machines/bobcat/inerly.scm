#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/machines/bobcat/inerly.scm,v 1.6 1988/08/31 06:00:59 cph Rel $

Copyright (c) 1988 Massachusetts Institute of Technology

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

;;;; 68000 Instruction Set Macros.  Early version

(declare (usual-integrations))

;;;; Transformers and utilities

(define early-instructions '())
(define early-transformers '())
(define early-ea-database)

(define (define-early-transformer name transformer)
  (set! early-transformers
	(cons (cons name transformer)
	      early-transformers)))

(define (make-ea-transformer #!optional modes keywords)
  (make-database-transformer
    (mapcan (lambda (rule)
	      (apply
	       (lambda (pattern variables categories expression)
		 (if (and (or (default-object? modes)
			      (eq-subset? modes categories))
			  (or (default-object? keywords)
			      (not (memq (car pattern) keywords))))
		     (list (early-make-rule pattern variables expression))
		     '()))
	       rule))
	    early-ea-database)))

(define (eq-subset? s1 s2)
  (or (null? s1)
      (and (memq (car s1) s2)
	   (eq-subset? (cdr s1) s2))))

(syntax-table-define early-syntax-table 'DEFINE-EA-TRANSFORMER
  (macro (name . restrictions)
    `(DEFINE-EARLY-TRANSFORMER ',name
       (APPLY MAKE-EA-TRANSFORMER ',restrictions))))

(syntax-table-define early-syntax-table 'DEFINE-SYMBOL-TRANSFORMER
  (macro (name . assoc)
    `(DEFINE-EARLY-TRANSFORMER ',name (MAKE-SYMBOL-TRANSFORMER ',assoc))))

(syntax-table-define early-syntax-table 'DEFINE-REG-LIST-TRANSFORMER
  (macro (name . assoc)
    `(DEFINE-EARLY-TRANSFORMER ',name (MAKE-BIT-MASK-TRANSFORMER 16 ',assoc))))

;;;; Instruction and addressing mode macros

(syntax-table-define early-syntax-table 'DEFINE-INSTRUCTION
  (macro (opcode . patterns)
    `(SET! EARLY-INSTRUCTIONS
	   (CONS
	    (LIST ',opcode
		  ,@(map (lambda (pattern)
			   `(early-parse-rule
			     ',(car pattern)
			     (lambda (pat vars)
			       (early-make-rule
				pat
				vars
				(scode-quote
				 (instruction->instruction-sequence
				  ,(parse-instruction (cadr pattern)
						      (cddr pattern)
						      true)))))))
			 patterns))
		 EARLY-INSTRUCTIONS))))

(syntax-table-define early-syntax-table 'EXTENSION-WORD
  (macro descriptors
    (expand-descriptors descriptors
      (lambda (instruction size source destination)
	(if (or source destination)
	    (error "EXTENSION-WORD: Source or destination used"))
	(if (not (zero? (remainder size 16)))
	    (error "EXTENSION-WORD: Extensions must be 16 bit multiples" size))
	(optimize-group-syntax instruction true)))))

(syntax-table-define early-syntax-table 'VARIABLE-EXTENSION
  (macro (binding . clauses)
    (variable-width-expression-syntaxer
     (car binding)
     (cadr binding)
     (map  (lambda (clause)
	     `((LIST ,(caddr clause))
	       ,(cadr clause)		; Size
	       ,@(car clause)))		; Range
	  clauses))))

;;;; Early effective address assembly.

;;; *** NOTE: If this format changes, insutl.scm must also be changed! ***

(syntax-table-define early-syntax-table 'DEFINE-EA-DATABASE
  (macro rules
    `(SET! EARLY-EA-DATABASE
	   (LIST
	    ,@(map (lambda (rule)
		     (if (null? (cdddr rule))
			 (apply make-position-dependent-early rule)
			 (apply make-position-independent-early rule)))
		   rules)))))

(define (make-ea-selector-expander late-name index)
  (scode->scode-expander
   (lambda (operands if-expanded if-not-expanded)
     if-not-expanded
     (let ((default
	     (lambda ()
	       (if-expanded
		(scode/make-combination
		 (scode/make-variable late-name)
		 operands))))
	   (operand (car operands)))
       (if (not (scode/combination? operand))
	   (default)
	   (scode/combination-components operand
	    (lambda (operator operands)
	      (if (or (not (scode/variable? operator))
		      (not (eq? (scode/variable-name operator)
				'MAKE-EFFECTIVE-ADDRESS)))
		  (default)
		  (if-expanded (list-ref operands index))))))))))

;; The indices here are the argument number to MAKE-EFFECTIVE-ADDRESS.
(define ea-keyword-expander (make-ea-selector-expander 'EA-KEYWORD 0))
(define ea-mode-expander (make-ea-selector-expander 'EA-MODE 1))
(define ea-register-expander (make-ea-selector-expander 'EA-REGISTER 2))
(define ea-extension-expander (make-ea-selector-expander 'EA-EXTENSION 3))
(define ea-categories-expander (make-ea-selector-expander 'EA-CATEGORIES 4))

;;;; Utilities

(define (make-position-independent-early pattern categories mode register
					 . extension)
  (let ((keyword (car pattern)))
    `(EARLY-PARSE-RULE
      ',pattern
      (LAMBDA (PAT VARS)
	(LIST PAT
	      VARS
	      ',categories
	      (SCODE-QUOTE
	       (MAKE-EFFECTIVE-ADDRESS
		',keyword
		,(integer-syntaxer mode 'UNSIGNED 3)
		,(integer-syntaxer register 'UNSIGNED 3)
		(LAMBDA (IMMEDIATE-SIZE INSTRUCTION-TAIL)
		  (DECLARE (INTEGRATE IMMEDIATE-SIZE INSTRUCTION-TAIL))
		  IMMEDIATE-SIZE	;ignore if not referenced
		  ,(if (null? extension)
		       'INSTRUCTION-TAIL
		       `(CONS-SYNTAX ,(car extension) INSTRUCTION-TAIL)))
		',categories)))))))

(define (make-position-dependent-early pattern categories code-list)
  (let ((keyword (car pattern))
	(code (cdr code-list)))
    (let ((name (car code))
	  (mode (cadr code))
	  (register (caddr code))
	  (extension (cadddr code)))
      `(EARLY-PARSE-RULE
	',pattern
	(LAMBDA (PAT VARS)
	  (LIST PAT
		VARS
		',categories
		(SCODE-QUOTE
		 (LET ((,name (GENERATE-LABEL 'MARK)))
		   (MAKE-EFFECTIVE-ADDRESS
		    ',keyword
		    ,(process-ea-field mode)
		    ,(process-ea-field register)
		    (LAMBDA (IMMEDIATE-SIZE INSTRUCTION-TAIL)
		      (DECLARE (INTEGRATE IMMEDIATE-SIZE INSTRUCTION-TAIL))
		      IMMEDIATE-SIZE	;ignore if not referenced
		      ,(if (null? extension)
			   'INSTRUCTION-TAIL
			   `(CONS (LIST 'LABEL ,name)
				  (CONS-SYNTAX ,extension INSTRUCTION-TAIL))))
		    ',categories)))))))))