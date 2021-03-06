#| -*-Scheme-*-

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008, 2009, 2010, 2011, 2012 Massachusetts Institute
    of Technology

This file is part of MIT/GNU Scheme.

MIT/GNU Scheme is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

MIT/GNU Scheme is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MIT/GNU Scheme; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301,
USA.

|#

;;;; SCode Combinator Abstractions
;;; package: (runtime scode-combinator)

(declare (usual-integrations))


;;;; Sequence

(define-integrable (%make-sequence first second)
  (&typed-pair-cons (ucode-type sequence-2) first second))

(define-integrable (sequence? object)
  (object-type? (ucode-type sequence-2) object))

(define-integrable (%sequence-immediate-first sequence) (&pair-car sequence))
(define-integrable (%sequence-immediate-second sequence) (&pair-cdr sequence))

(define-guarantee sequence "SCode sequence")

(define (make-sequence actions)
  (if (null? actions)
      (error "MAKE-SEQUENCE: No actions"))
  (let loop ((actions actions))
    (if (null? (cdr actions))
	(car actions)
	(%make-sequence (car actions) (loop (cdr actions))))))

(define (sequence-first expression)
  (guarantee-sequence expression 'SEQUENCE-FIRST)
  (%sequence-immediate-first expression))

(define (sequence-second expression)
  (guarantee-sequence expression 'SEQUENCE-SECOND)
  (%sequence-immediate-second expression))

(define (sequence-immediate-first expression)
  (guarantee-sequence expression 'SEQUENCE-IMMEDIATE-FIRST)
  (%sequence-immediate-first expression))

(define (sequence-immediate-second expression)
  (guarantee-sequence expression 'SEQUENCE-IMMEDIATE-SECOND)
  (%sequence-immediate-second expression))

(define (sequence-immediate-actions expression)
  (guarantee-sequence expression 'SEQUENCE-IMMEDIATE-ACTIONS)
  (list (%sequence-immediate-first expression)
	(%sequence-immediate-second expression)))

(define (sequence-actions expression)
  (if (sequence? expression)
      (append! (sequence-actions (%sequence-immediate-first expression))
	       (sequence-actions (%sequence-immediate-second expression)))
      (list expression)))

(define (sequence-components expression receiver)
  (receiver (sequence-actions expression)))

(define (copy-sequence expression)
  (guarantee-sequence expression 'COPY-SEQUENCE)
  (%make-sequence (%sequence-immediate-first expression)
		  (%sequence-immediate-second expression)))


;;;; Conditional

(define (make-conditional predicate consequent alternative)
  (&typed-triple-cons (ucode-type conditional)
		      predicate
		      consequent
		      alternative))

(define (conditional? object)
  (object-type? (ucode-type conditional) object))

(define-guarantee conditional "SCode conditional")

(define undefined-conditional-branch unspecific)

(define (conditional-predicate conditional)
  (guarantee-conditional conditional 'CONDITIONAL-PREDICATE)
  (&triple-first conditional))

(define (conditional-consequent conditional)
  (guarantee-conditional conditional 'CONDITIONAL-CONSEQUENT)
  (&triple-second conditional))

(define (conditional-alternative conditional)
  (guarantee-conditional conditional 'CONDITIONAL-ALTERNATIVE)
  (&triple-third conditional))

(define (conditional-components conditional receiver)
  (receiver (conditional-predicate conditional)
	    (conditional-consequent conditional)
	    (conditional-alternative conditional)))

(define (conditional-subexpressions expression)
  (conditional-components expression list))

;;;; Disjunction

(define (make-disjunction predicate alternative)
  (&typed-pair-cons (ucode-type disjunction) predicate alternative))

(define (disjunction? object)
  (object-type? (ucode-type disjunction) object))

(define-guarantee disjunction "SCode disjunction")

(define (disjunction-predicate disjunction)
  (guarantee-disjunction disjunction 'DISJUNCTION-PREDICATE)
  (&pair-car disjunction))

(define (disjunction-alternative disjunction)
  (guarantee-disjunction disjunction 'DISJUNCTION-ALTERNATIVE)
  (&pair-cdr disjunction))

(define (disjunction-components disjunction receiver)
  (receiver (disjunction-predicate disjunction)
	    (disjunction-alternative disjunction)))

(define (disjunction-subexpressions expression)
  (disjunction-components expression list))

;;;; Combination

(define (combination? object)
  (or (object-type? (ucode-type combination) object)
      (object-type? (ucode-type combination-1) object)
      (object-type? (ucode-type combination-2) object)
      (object-type? (ucode-type primitive-combination-0) object)
      (object-type? (ucode-type primitive-combination-1) object)
      (object-type? (ucode-type primitive-combination-2) object)
      (object-type? (ucode-type primitive-combination-3) object)))

(define-guarantee combination "SCode combination")

(define (make-combination operator operands)
  (&typed-vector-cons (ucode-type combination)
		      (cons operator operands)))

(define-syntax combination-dispatch
  (sc-macro-transformer
   (lambda (form environment)
     (let ((name (list-ref form 1))
	   (combination (close-syntax (list-ref form 2) environment))
	   (case-0 (close-syntax (list-ref form 3) environment))
	   (case-1 (close-syntax (list-ref form 4) environment))
	   (case-2 (close-syntax (list-ref form 5) environment))
	   (case-n (close-syntax (list-ref form 6) environment)))
       `(COND ((OBJECT-TYPE? (UCODE-TYPE PRIMITIVE-COMBINATION-0)
			     ,combination)
	       ,case-0)
	      ((OR (OBJECT-TYPE? (UCODE-TYPE COMBINATION-1) ,combination)
		   (OBJECT-TYPE? (UCODE-TYPE PRIMITIVE-COMBINATION-1)
				 ,combination))
	       ,case-1)
	      ((OR (OBJECT-TYPE? (UCODE-TYPE COMBINATION-2) ,combination)
		   (OBJECT-TYPE? (UCODE-TYPE PRIMITIVE-COMBINATION-2)
				 ,combination))
	       ,case-2)
	      ((OR (OBJECT-TYPE? (UCODE-TYPE COMBINATION) ,combination)
		   (OBJECT-TYPE? (UCODE-TYPE PRIMITIVE-COMBINATION-3)
				 ,combination))
	       ,case-n)
	      (ELSE
	       (ERROR:NOT-COMBINATION ,combination ',name)))))))

(define (combination-size combination)
  (combination-dispatch combination-size combination
			1 2 3 (&vector-length combination)))

(define (combination-operator combination)
  (combination-dispatch combination-operator combination
			(object-new-type (ucode-type primitive) combination)
			(&pair-car combination)
			(&triple-first combination)
			(&vector-ref combination 0)))

(define (combination-operands combination)
  (combination-dispatch
   combination-operands combination
   '()
   (list (&pair-cdr combination))
   (list (&triple-second combination) (&triple-third combination))
   (&subvector->list combination 1 (&vector-length combination))))

(define (combination-components combination receiver)
  (combination-dispatch
   combination-components combination
   (receiver (object-new-type (ucode-type primitive) combination) '())
   (receiver (&pair-car combination) (list (&pair-cdr combination)))
   (receiver (&triple-first combination)
	     (list (&triple-second combination) (&triple-third combination)))
   (receiver (&vector-ref combination 0)
	     (&subvector->list combination 1 (&vector-length combination)))))

(define (combination-subexpressions expression)
  (combination-components expression cons))

;;;; Unassigned?

(define (make-unassigned? name)
  (make-combination (ucode-primitive lexical-unassigned?)
		    (list (make-the-environment) name)))

(define (unassigned?? object)
  (and (combination? object)
       (eq? (combination-operator object)
	    (ucode-primitive lexical-unassigned?))
       (let ((operands (combination-operands object)))
	 (and (the-environment? (car operands))
	      (symbol? (cadr operands))))))

(define-guarantee unassigned? "SCode unassigned test")

(define (unassigned?-name expression)
  (guarantee-unassigned? expression 'UNASSIGNED?-NAME)
  (cadr (combination-operands expression)))

(define (unassigned?-components expression receiver)
  (receiver (unassigned?-name expression)))