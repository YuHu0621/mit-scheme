#| -*-Scheme-*-

$Id: lapopt.scm,v 1.4 1998/02/14 07:12:14 adams Exp $

Copyright (c) 1992-1998 Massachusetts Institute of Technology

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

;;;; LAP Optimizer for Intel i386.
;;; package: (compiler lap-optimizer)

(declare (usual-integrations))

(define (optimize-linear-lap instructions)
  (rewrite-lap instructions))

;; i386 LAPOPT uses its own pattern matcher because we want to match
;; patterns while ignoring comments.

(define (comment? thing)
  (and (pair? thing) (eq? (car thing) 'COMMENT)))

(define (match pat thing dict)		; -> #F or dictionary (alist)
  (if (pair? pat)
      (if (eq? (car pat) '?)
	  (cond ((assq (cadr pat) dict)
		 => (lambda (pair)
		      (and (equal? (cdr pair) thing)
			   dict)))
		(else (cons (cons (cadr pat) thing) dict)))
	  (and (pair? thing)
	       (let ((dict* (match (car pat) (car thing) dict)))
		 (and dict*
		      (match (cdr pat) (cdr thing) dict*)))))
      (and (eqv? pat thing)
	   dict)))

(define (match-sequence pats things dict comments success fail)
  ;; SUCCESS = (lambda (dict* comments* things-tail) ...)
  ;; FAIL =  (lambda () ...)

  (define (eat-comment)
    (match-sequence pats (cdr things) dict (cons (car things) comments)
		    success fail))

  (cond ((not (pair? pats)) ; i.e. null
	 (if (and (pair? things)
		  (comment? (car things)))
	     (eat-comment)
	     (success dict comments things)))
	((not (pair? things))
	 (fail))
	((comment? (car things))
	 (eat-comment))
	((match (car pats) (car things) dict)
	 => (lambda (dict*)
	      (match-sequence (cdr pats) (cdr things) dict* comments
			      success fail)))
	(else (fail))))

(define-structure
    (rule)
  name					; used only for information
  pattern				; INSNs (in reverse order)
  predicate				; (lambda (dict) ...) -> bool
  constructor)				; (lambda (dict) ...) -> lap


(define *rules* '())
(define *rule-window* 0)		; length of longest pattern

(define (define-lapopt name pattern predicate constructor)
  (set! *rules*
	(cons (make-rule name
			 (reverse pattern)
			 (if ((access procedure? system-global-environment)
			      predicate)
			     predicate
			     (lambda (dict) dict #T))
			 constructor)
	      *rules*))
  (set! *rule-window* (max *rule-window* (length pattern)))
  name)

;; Rules are tried in the reverse order in which they are defined.
;;
;; Rules are matched against the LAP from the bottom up.
;;
;; Once a rule has been applied, the rewritten LAP is matched again*,
;; so a rule must rewrite to something different to avoid a loop.  (A
;; good way to ensure this is to always rewrite to fewer
;; instructions.)
;;
;; *The matching `rewinds' slightly to ensure all patterns that might
;; overlap the rewritten LAP are considered.

(define (rewrite-lap lap)
  (let loop ((unseen (reverse lap)) (finished '()))
    (if (null? unseen)
	finished
	(if (comment? (car unseen))
	    (loop (cdr unseen) (cons (car unseen) finished))
	    (let try-rules ((rules *rules*))
	      (if (null? rules)
		  (loop (cdr unseen) (cons (car unseen) finished))
		  (let ((rule (car rules)))
		    (match-sequence
		     (rule-pattern rule)
		     unseen
		     '(("empty"))	; initial dict, distinct from #F and ()
		     '()		; initial comments
		     (lambda (dict comments unseen*)
		       (let ((dict (alist->dict dict)))
			 (if ((rule-predicate rule) dict)
			     (let* ((insns ((rule-constructor rule) dict))
				    (rewritten
				     (cons
				      `(COMMENT (LAP-OPT ,(rule-name rule)))
				      (append comments insns))))
			       (let backup-loop
				   ((i (- *rule-window* (length insns)))
				    (unseen
				     (append (reverse rewritten) unseen*))
				    (finished finished))
				 (if (and (> i 0) (pair? finished))
				     (backup-loop
				      (if (eq? (caar finished) 'COMMENT)
					  i
					  (- i 1))
				      (cons (car finished) unseen)
				      (cdr finished))
				     (loop unseen finished))))
			     (try-rules (cdr rules)))))
		     (lambda ()
		       (try-rules (cdr rules)))))))))))

;; The DICT passed to the rule predicate and action procedures is a
;; procedure mapping pattern names to their matched values.

(define (alist->dict dict)
  (lambda (symbol)
    (cond ((assq symbol dict) => cdr)
	  (else (error "Undefined lapopt pattern symbol" symbol dict)))))

(define-lapopt 'PUSH-POP->MOVE
  `((PUSH (? reg1))
    (POP  (? reg2)))
  #F
  (lambda (dict)
    `((MOV W ,(dict 'reg2) ,(dict 'reg1)))))

(define-lapopt 'PUSH-POP->NOP
  `((PUSH (? reg))
    (POP  (? reg)))
  #F
  (lambda (dict)
    dict
    `()))

;; The following rules must have the JMP else we don't know if the
;; register that we are avoiding loading is dead.

(define-lapopt 'LOAD-PUSH-POP-JUMP->REGARGETTED-LOAD-JUMP
  ;; Note that reg1 must match a register because of the PUSH insn.
  `((MOV W (? reg1) (? ea/value))
    (PUSH (? reg1))
    (POP  (R ,ecx))
    (JMP (@RO B 6 (? hook-offset))))
  #F
  (lambda (dict)
    `((MOV W (R ,ecx) ,(dict 'ea/value))
      (JMP (@RO B 6 ,(dict 'hook-offset))))))

(define-lapopt 'LOAD-STACKTOPWRITE-POP-JUMP->RETARGETTED-LOAD-JUMP
  `((MOV W (? reg) (? ea/value))
    (MOV W (@r ,esp) (? reg))
    (POP (R ,ecx))
    (JMP (@RO B 6 (? hook-offset))))
  #F
  (lambda (dict)
    `((MOV W (R ,ecx) ,(dict 'ea/value))
      (ADD W (R ,esp) (& 4))
      (JMP (@RO B 6 ,(dict 'hook-offset))))))


(define-lapopt 'STACKWRITE-POP-JUMP->RETARGETTED-LOAD-JUMP
  `((MOV W (@RO B ,esp (? stack-offset)) (? ea/value))
    (ADD W (R ,esp) (& (? stack-offset)))
    (POP (R ,ecx))
    (JMP (@RO B 6 (? hook-offset))))
  #F
  (lambda (dict)
    `((MOV W (R ,ecx) ,(dict 'ea/value))
      (ADD W (R ,esp) (& ,(+ 4 (dict 'stack-offset))))
      (JMP (@RO B 6 ,(dict 'hook-offset))))))



;; The following rules recognize arithmetic followed by tag injection,
;; and fold the tag-injection into the arithmetic.  We can do this
;; because we know the bottom six bits of the fixnum are all 0.  This
;; is particularly crafty in the generic arithmetic case, as it does
;; not mess up the overflow detection.
;;
;; These patterns match the code generated by subtractions too.

(define fixnum-tag (object-type 1))

(define-lapopt 'FIXNUM-ADD-CONST-TAG
  `((ADD W (R (? reg)) (& (? const)))
    (OR W (R (? reg)) (& ,fixnum-tag))
    (ROR W (R (? reg)) (& 6)))
  #F
  (lambda (dict)
    `((ADD W (R ,(dict 'reg)) (& ,(+ (dict 'const) fixnum-tag)))
      (ROR W (R ,(dict 'reg)) (& 6)))))

(define-lapopt 'FIXNUM-ADD-REG-TAG
  `((ADD W (R (? reg)) (R (? reg-2)))
    (OR W (R (? reg)) (& ,fixnum-tag))
    (ROR W (R (? reg)) (& 6)))
  #F
  (lambda (dict)
    `((LEA (R ,(dict 'reg)) (@ROI B ,(dict 'reg) ,fixnum-tag ,(dict 'reg-2) 1))
      (ROR W (R ,(dict 'reg)) (& 6)))))

(define-lapopt 'GENERIC-ADD-TAG
  `((ADD W (R (? reg)) (& (? const)))
    (JO (@PCR (? label)))
    (OR W (R (? reg)) (& ,fixnum-tag))
    (ROR W (R (? reg)) (& 6)))
  #F
  (lambda (dict)
    `((ADD W (R ,(dict 'reg)) (& ,(+ (dict 'const) fixnum-tag)))
      (JO (@PCR ,(dict 'label)))
      (ROR W (R ,(dict 'reg)) (& 6)))))

;; If the fixnum tag is even, the zero LSB works as a place to hold
;; the overflow from addition which can be discarded by masking it
;; out.  We must arrange that the constant is positive, so we don't
;; borrow from the tag bits.

(if (even? fixnum-tag)
    (define-lapopt 'FIXNUM-ADD-CONST-IN-PLACE
      `((SAL W (? reg) (& ,scheme-type-width))
	(ADD W (? reg) (& (? const)))
	(OR W (? reg)  (& ,fixnum-tag))
	(ROR W (? reg) (& ,scheme-type-width)))
      #F
      (lambda (dict)
	(let ((const (sar-32 (dict 'const) scheme-type-width))
	      (mask  (make-non-pointer-literal
		      fixnum-tag
		      (-1+ (expt 2 scheme-datum-width)))))
	  (let ((const
		 (if (negative? const)
		     (+ const (expt 2 scheme-datum-width))
		     const)))
	    `(,(if (= const 1)
		   `(INC W ,(dict 'reg)) ; shorter instruction
		   `(ADD W ,(dict 'reg) (& ,const)))
	      (AND W ,(dict 'reg) (& ,mask))))))))

;; Similar tag-injection combining rule for fix:or is a little more
;; general.

(define (or-32-signed x y)
  (bit-string->signed-integer
   (bit-string-or (signed-integer->bit-string 32 x)
		  (signed-integer->bit-string 32 y))))

(define (and-32-signed x y)
  (bit-string->signed-integer
   (bit-string-and (signed-integer->bit-string 32 x)
		   (signed-integer->bit-string 32 y))))

(define (ror-32-signed w count)
  (let ((bs (signed-integer->bit-string 32 w)))
    (bit-string->signed-integer
     (bit-string-append (bit-substring bs count 32)
			(bit-substring bs 0 count)))))

(define (sar-32 w count)
  (let ((bs (signed-integer->bit-string 32 w)))
    (bit-string->signed-integer (bit-substring bs count 32))))

(define-lapopt 'OR-OR
  `((OR W (R (? reg)) (& (? const-1)))
    (OR W (R (? reg)) (& (? const-2))))
  #F
  (lambda (dict)
    `((OR W (R ,(dict 'reg))
	  (& ,(or-32-signed (dict 'const-1) (dict 'const-2)))))))

(define-lapopt 'AND-AND
  `((AND W (R (? reg)) (& (? const-1)))
    (AND W (R (? reg)) (& (? const-2))))
  #F
  (lambda (dict)
    `((AND W (R ,(dict 'reg))
	   (& ,(and-32-signed (dict 'const-1) (dict 'const-2)))))))

;; These rules match a whole fixnum detag-AND/OR-retag operation.  In
;; principle, these operations could be done in rulfix.scm, but the
;; instruction combiner wants all the intermediate steps.


;; Relies on OR-OR collapsing the constant with the tag injection
(define-lapopt 'FIXNUM-OR-CONST-IN-PLACE
  `((SAL W (? reg) (& ,scheme-type-width))
    (OR W (? reg) (& (? const)))
    (ROR W (? reg) (& ,scheme-type-width)))
  #F
  (lambda (dict)
    `((OR W ,(dict 'reg)
	  (& ,(careful-object-datum
	       (sar-32 (dict 'const) scheme-type-width)))))))

(define-lapopt 'FIXNUM-AND-OR-CONST-IN-PLACE
  `((SAL W (? reg) (& ,scheme-type-width))
    (AND W (? reg) (& (? const-1)))
    (OR W (? reg) (& (? const-2)))
    (ROR W (? reg) (& ,scheme-type-width)))
  #F
  (lambda (dict)
    (let ((and-value
	   (careful-object-datum (sar-32 (dict 'const-1) scheme-type-width)))
	  (or-value
	   (careful-object-datum (sar-32 (dict 'const-2) scheme-type-width))))
      (define (tagged value) (make-non-pointer-literal fixnum-tag value))
      ;; Either AND must keep the tag bits, or OR must inject them, so
      ;; at least one of AND or OR must be a 32-bit pattern.  Choose to
      ;; minimize code size, break ties in favor of GC safely on
      ;; illegal operands.
      (cond ((zero? or-value)
	     `((AND W ,(dict 'reg) (& ,(tagged and-value)))))
	    ((fits-in-signed-byte? and-value)
	     `((AND W ,(dict 'reg) (& ,and-value))
	       (OR W ,(dict 'reg)  (& ,(tagged or-value)))))
	    ((fits-in-signed-byte? or-value)
	     `((AND W ,(dict 'reg) (& ,(tagged and-value)))
	       (OR W ,(dict 'reg)  (& ,or-value))))
	    (else			; neither fits
	     `((AND W ,(dict 'reg) (& ,(tagged and-value)))
	       (OR W ,(dict 'reg)  (& ,(tagged or-value)))))))))

;; FIXNUM-NOT.  The first (partial) pattern uses the XOR operation to
;; put the tag bits in the low part of the result.  This pattern
;; occurs in the hash table hash functions, where the OBJECT->FIXNUM
;; has been shared by CSE.

(define-lapopt 'FIXNUM-NOT-TAG
  `((NOT W (? reg))
    (AND W (? reg) (& #x-40))
    (OR W (? reg) (& ,fixnum-tag))
    (ROR W (? reg) (& ,scheme-type-width)))
  #F
  (lambda (dict)
    (let ((magic-bits (+ (* -1 (expt 2 scheme-type-width)) fixnum-tag)))
      `((XOR W ,(dict 'reg) (& ,magic-bits))
	(ROR W ,(dict 'reg) (& ,scheme-type-width))))))

(define-lapopt 'FIXNUM-NOT-IN-PLACE
  `((SAL W (? reg) (& ,scheme-type-width))
    (NOT W (? reg))
    (AND W (? reg) (& #x-40))
    (OR W (? reg) (& ,fixnum-tag))
    (ROR W (? reg) (& ,scheme-type-width)))
  #F
  (lambda (dict)
    `((XOR W ,(dict 'reg) (& ,(-1+ (expt 2 scheme-datum-width)))))))


;; CLOSURES
;;
;; This rule recognizes code duplicated at the end of the CONS-CLOSURE
;; and CONS-MULTICLOSURE and the following CONS-POINTER. (This happens
;; because of the hack of storing the entry point as a tagged object
;; in the closure to allow GC to work correctly with relative jumps in
;; the closure code.  A better fix would be to alter the GC to make
;; absolute the addresses during closure transport.)
;;
;; The rule relies on the fact the REG-TEMP is a temporary for the
;; expansions of CONS-CLOSURE and CONS-MULTICLOSURE, so it is dead
;; afterwards, and is specific in matching because it is the only code
;; that stores an entry at a negative offset from the free pointer.

(define-lapopt 'CONS-CLOSURE-FIXUP
  `((LEA (? reg-temp) (@RO UW (? regno-closure) #xA0000000))
    (MOV W (@RO B ,regnum:free-pointer -4) (? regno-temp))
    (LEA (? reg-object) (@RO UW (? regno-closure) #xA0000000)))
  #F
  (lambda (dict)
    `((LEA ,(dict 'reg-object) (@RO UW ,(dict 'regno-closure) #xA0000000))
      (MOV W (@RO B ,regnum:free-pointer -4) ,(dict 'reg-object)))))
