#| -*-Scheme-*-

$Id: framex.scm,v 14.19 1995/07/27 20:42:20 adams Exp $

Copyright (c) 1988-1995 Massachusetts Institute of Technology

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

;;;; Debugging Info
;;; package: (runtime debugging-info)

(declare (usual-integrations))

(define (stack-frame/debugging-info frame)
  (let ((method
	 (stack-frame-type/debugging-info-method (stack-frame/type frame))))
    (if (not method)
	;; (error "STACK-FRAME/DEBUGGING-INFO: missing method" frame)
	(stack-frame/debugging-info/default frame)
	(method frame))))

(define (stack-frame/debugging-info/default frame)
  (values (make-debugging-info/noise
	   (lambda (long?)
	     (with-output-to-string
	       (lambda ()
		 (display "Unknown (methodless) ")
		 (if long?
		     (pp frame)
		     (write frame))))))
	  undefined-environment
	  undefined-expression))

(define (debugging-info/undefined-expression? expression)
  (or (eq? expression undefined-expression)
      (debugging-info/noise? expression)))

(define (debugging-info/noise? expression)
  (and (pair? expression)
       (eq? (car expression) undefined-expression)))

(define-integrable (debugging-info/noise expression)
  (cdr expression))

(define-integrable (make-debugging-info/noise noise)
  (cons undefined-expression noise))

(define-integrable (debugging-info/undefined-environment? environment)
  (eq? environment undefined-environment))

(define-integrable (debugging-info/unknown-expression? expression)
  (eq? expression unknown-expression))

(define-integrable (debugging-info/compiled-code? expression)
  (eq? expression compiled-code))

(define (make-evaluated-object object)
  (if (scode-constant? object)
      object
      (cons evaluated-object-tag object)))

(define (debugging-info/evaluated-object? expression)
  (and (pair? expression)
       (eq? (car expression) evaluated-object-tag)))

(define-integrable (debugging-info/evaluated-object-value expression)
  (cdr expression))

(define (validate-subexpression frame subexpression)
  (if (eq? (stack-frame/previous-type frame) stack-frame-type/pop-return-error)
      undefined-expression
      subexpression))

(define undefined-expression "undefined expression")
(define undefined-environment "undefined environment")
(define unknown-expression "unknown expression")
(define compiled-code "compiled code")
(define evaluated-object-tag "evaluated")
(define stack-frame-type/pop-return-error)

(define (method/null frame)
  frame
  (values undefined-expression undefined-environment undefined-expression))

(define (method/environment-only frame)
  (values undefined-expression (stack-frame/ref frame 2) undefined-expression))

(define ((method/standard select-subexpression) frame)
  (let ((expression (stack-frame/ref frame 1)))
    (values expression
	    (stack-frame/ref frame 2)
	    (validate-subexpression frame (select-subexpression expression)))))

(define ((method/expression-only select-subexpression) frame)
  (let ((expression (stack-frame/ref frame 1)))
    (values expression
	    undefined-environment
	    (validate-subexpression frame (select-subexpression expression)))))

(define (method/primitive-combination-3-first-operand frame)
  (let ((expression (stack-frame/ref frame 1)))
    (values expression
	    (stack-frame/ref frame 3)
	    (validate-subexpression frame (&vector-ref expression 2)))))

(define (method/combination-save-value frame)
  (let ((expression (stack-frame/ref frame 1)))
    (values expression
	    (stack-frame/ref frame 2)
	    (validate-subexpression
	     frame
	     (&vector-ref expression (stack-frame/ref frame 3))))))

(define (method/eval-error frame)
  (values (stack-frame/ref frame 1)
	  (stack-frame/ref frame 2)
	  undefined-expression))

(define (method/force-snap-thunk frame)
  (let ((promise (stack-frame/ref frame 1)))
    (values (%make-combination
	     (ucode-primitive force 1)
	     (list (make-evaluated-object promise)))
	    undefined-environment
	    (cond ((promise-forced? promise) undefined-expression)
		  ((promise-non-expression? promise) unknown-expression)
		  (else
		   (validate-subexpression frame
					   (promise-expression promise)))))))

(define ((method/application-frame index) frame)
  (values (%make-combination
	   (make-evaluated-object (stack-frame/ref frame index))
	   (stack-frame-list frame (1+ index)))
	  undefined-environment
	  undefined-expression))

(define ((method/compiler-reference scode-maker) frame)
  (values (scode-maker (stack-frame/ref frame 3))
	  (stack-frame/ref frame 2)
	  undefined-expression))

(define ((method/compiler-assignment scode-maker) frame)
  (values (scode-maker (stack-frame/ref frame 3)
		       (make-evaluated-object (stack-frame/ref frame 4)))
	  (stack-frame/ref frame 2)
	  undefined-expression))

(define ((method/compiler-reference-trap scode-maker) frame)
  (values (scode-maker (stack-frame/ref frame 2))
	  (stack-frame/ref frame 3)
	  undefined-expression))

(define ((method/compiler-assignment-trap scode-maker) frame)
  (values (scode-maker (stack-frame/ref frame 2)
		       (make-evaluated-object (stack-frame/ref frame 4)))
	  (stack-frame/ref frame 3)
	  undefined-expression))

(define (method/compiler-lookup-apply-restart frame)
  (values (%make-combination (stack-frame/ref frame 3)
			     (stack-frame-list frame 5))
	  undefined-environment
	  undefined-expression))

(define (method/compiler-lookup-apply-trap-restart frame)
  (values (%make-combination (make-variable (stack-frame/ref frame 2))
			     (stack-frame-list frame 6))
	  (stack-frame/ref frame 3)
	  undefined-expression))

(define (method/compiler-error-restart frame)
  (let ((primitive (stack-frame/ref frame 2)))
    (if (primitive-procedure? primitive)
	(values (%make-combination (make-variable 'apply)
				   (list primitive
					 unknown-expression))
		undefined-environment
		undefined-expression)
	(stack-frame/debugging-info/default frame))))

(define (stack-frame-list frame start)
  (let ((end (stack-frame/length frame)))
    (let loop ((index start))
      (if (< index end)
	  (cons (make-evaluated-object (stack-frame/ref frame index))
		(loop (1+ index)))
	  '()))))

(define (method/hardware-trap frame)
  (values (make-debugging-info/noise (hardware-trap-noise frame))
	  undefined-environment
	  undefined-expression))

(define ((hardware-trap-noise frame) long?)
  (with-output-to-string
    (lambda ()
      (hardware-trap-frame/describe frame long?))))

(define ((method/compiled-code frame-elements->entry) frame)
  (let ((entry (frame-elements->entry (stack-frame/elements frame))))
    (define (get-environment)
      (stack-frame/environment frame entry undefined-environment))
    (let ((object
	   (compiled-entry/dbg-object entry))
	  (lose
	   (lambda ()
	     (values compiled-code (get-environment) undefined-expression))))
      (cond ((not object)
	     (lose))
	    ((dbg-continuation? object)
	     (let* ((expression (dbg-continuation/outer object))
		    (element    (dbg-continuation/inner object))
		    (win2
		     (lambda (environment subexp)
		       (values expression environment subexp)))
		    (win
		     (lambda (select-subexp)
		       (win2
			(get-environment)
			(validate-subexpression
			 frame
			 (select-subexp expression))))))
	       (case (dbg-continuation/type object)
		 ((COMBINATION-ELEMENT)
		  (win2 (get-environment) element))
		 ((SEQUENCE-ELEMENT)
		  (win2 (get-environment) element))
		 ((CONDITIONAL-PREDICATE)
		  (win2 (get-environment) element))
		 ((SEQUENCE-2-SECOND)
		  (win &pair-car))
		 ((ASSIGNMENT-CONTINUE
		   DEFINITION-CONTINUE)
		  (win &pair-cdr))
		 ((SEQUENCE-3-SECOND
		   CONDITIONAL-DECIDE)
		  (win &triple-first))
		 ((SEQUENCE-3-THIRD)
		  (win &triple-second))
		 ((COMBINATION-OPERAND)
		  (values
		   expression
		   (get-environment)
		   (validate-subexpression
		    frame
		    (if (zero? element)
			(combination-operator expression)
			(list-ref (combination-operands expression)
				  (-1+ element))))))
		 (else
		  (lose)))))
	    ((dbg-procedure? object)
	     (values (lambda-body (dbg-procedure/source-code object))
		     (and (dbg-procedure/block object)
			  (get-environment))
		     undefined-expression))
	    ((dbg-expression? object)
	     ;; no expression!
	     (lose))
	    (else
	     (lose))))))

(define (initialize-package!)

  (define (&vector-first vector)
    (&vector-ref vector 0))

  (define (&vector-second vector)
    (&vector-ref vector 1))

  (define (&vector-fourth vector)
    (&vector-ref vector 3))

  (define (&vector-fifth vector)
    (&vector-ref vector 4))

  (define (record-method name method)
    (set-stack-frame-type/debugging-info-method!
     (microcode-return/name->type name)
     method))

  (set! stack-frame-type/pop-return-error
	(microcode-return/name->type 'POP-RETURN-ERROR))
  (record-method 'COMBINATION-APPLY method/null)
  (record-method 'GC-CHECK method/null)
  (record-method 'MOVE-TO-ADJACENT-POINT method/null)
  (record-method 'REENTER-COMPILED-CODE method/null)
  (record-method 'REPEAT-DISPATCH method/environment-only)
  (let ((method (method/standard &pair-car)))
    (record-method 'DISJUNCTION-DECIDE method)
    (record-method 'SEQUENCE-2-SECOND method))
  (let ((method (method/standard &pair-cdr)))
    (record-method 'ASSIGNMENT-CONTINUE method)
    (record-method 'COMBINATION-1-PROCEDURE method)
    (record-method 'DEFINITION-CONTINUE method))
  (let ((method (method/standard &triple-first)))
    (record-method 'CONDITIONAL-DECIDE method)
    (record-method 'SEQUENCE-3-SECOND method))
  (let ((method (method/standard &triple-second)))
    (record-method 'COMBINATION-2-PROCEDURE method)
    (record-method 'SEQUENCE-3-THIRD method))
  (let ((method (method/standard &triple-third)))
    (record-method 'COMBINATION-2-FIRST-OPERAND method)
    (record-method 'PRIMITIVE-COMBINATION-2-FIRST-OPERAND method))
  (record-method 'PRIMITIVE-COMBINATION-3-SECOND-OPERAND
		 (method/standard &vector-fourth))
  (let ((method (method/expression-only &pair-car)))
    (record-method 'ACCESS-CONTINUE method)
    (record-method 'IN-PACKAGE-CONTINUE method))
  (record-method 'PRIMITIVE-COMBINATION-1-APPLY
		 (method/expression-only &pair-cdr))
  (record-method 'PRIMITIVE-COMBINATION-2-APPLY
		 (method/expression-only &triple-second))
  (record-method 'PRIMITIVE-COMBINATION-3-APPLY
		 (method/expression-only &vector-second))
  (record-method 'COMBINATION-SAVE-VALUE method/combination-save-value)
  (record-method 'PRIMITIVE-COMBINATION-3-FIRST-OPERAND
		 method/primitive-combination-3-first-operand)
  (record-method 'EVAL-ERROR method/eval-error)
  (record-method 'FORCE-SNAP-THUNK method/force-snap-thunk)
  (let ((method (method/application-frame 3)))
    (record-method 'INTERNAL-APPLY method)
    (record-method 'INTERNAL-APPLY-VAL method))
  (let ((method (method/compiler-reference identity-procedure)))
    (record-method 'COMPILER-REFERENCE-RESTART method)
    (record-method 'COMPILER-SAFE-REFERENCE-RESTART method))
  (record-method 'COMPILER-ACCESS-RESTART
		 (method/compiler-reference make-variable))
  (record-method 'COMPILER-UNASSIGNED?-RESTART
		 (method/compiler-reference make-unassigned?))
  (record-method 'COMPILER-UNBOUND?-RESTART
		 (method/compiler-reference
		  (lambda (name)
		    (%make-combination (ucode-primitive lexical-unbound?)
				       (list (make-the-environment) name)))))
  (record-method 'COMPILER-ASSIGNMENT-RESTART
		 (method/compiler-assignment make-assignment-from-variable))
  (record-method 'COMPILER-DEFINITION-RESTART
		 (method/compiler-assignment make-definition))
  (let ((method (method/compiler-reference-trap make-variable)))
    (record-method 'COMPILER-REFERENCE-TRAP-RESTART method)
    (record-method 'COMPILER-SAFE-REFERENCE-TRAP-RESTART method))
  (record-method 'COMPILER-UNASSIGNED?-TRAP-RESTART
		 (method/compiler-reference-trap make-unassigned?))
  (record-method 'COMPILER-ASSIGNMENT-TRAP-RESTART
		 (method/compiler-assignment-trap make-assignment))
  (record-method 'COMPILER-LOOKUP-APPLY-RESTART
		 method/compiler-lookup-apply-restart)
  (record-method 'COMPILER-LOOKUP-APPLY-TRAP-RESTART
		 method/compiler-lookup-apply-trap-restart)
  (record-method 'COMPILER-OPERATOR-LOOKUP-TRAP-RESTART
		 method/compiler-lookup-apply-trap-restart)
  (record-method 'COMPILER-ERROR-RESTART
		 method/compiler-error-restart)
  (record-method 'HARDWARE-TRAP method/hardware-trap)

  (set-stack-frame-type/debugging-info-method!
   stack-frame-type/compiled-return-address
   (method/compiled-code &vector-first))

  (let ((method (method/compiled-code &vector-fifth)))
    (set-stack-frame-type/debugging-info-method!
     stack-frame-type/interrupt-compiled-procedure
     method)
    (set-stack-frame-type/debugging-info-method!
     stack-frame-type/interrupt-compiled-return-address
     method)
    )

  ;;(set-stack-frame-type/debugging-info-method!
  ;; stack-frame-type/interrupt-compiled-expression
  ;; method/compiled-code)
  )


(define-integrable (stack-frame-type/debugging-info-method type)
  (1d-table/get (stack-frame-type/properties type) method-tag false))

(define-integrable (set-stack-frame-type/debugging-info-method! type method)
  (1d-table/put! (stack-frame-type/properties type) method-tag method))

(define method-tag "stack-frame-type/debugging-info-method")