#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/machines/i386/lapgen.scm,v 1.1 1992/01/30 06:33:15 jinx Exp $
$MC68020-Header: /scheme/compiler/bobcat/RCS/lapgen.scm,v 4.42 1991/05/28 19:14:26 jinx Exp $

Copyright (c) 1992 Massachusetts Institute of Technology

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

;;;; RTL Rules utilities for i386 and family.
;;; package: (compiler lap-syntaxer)

(declare (usual-integrations))

(define (require-register! machine-reg)
  (flush-register! machine-reg)
  (need-register! machine-reg))

(define-integrable (flush-register! machine-reg)
  (prefix-instructions! (clear-registers! machine-reg)))

(define (rtl-target:=machine-register! rtl-reg machine-reg)
  (if (machine-register? rtl-reg)
      (begin
	(require-register! machine-reg)
	(if (not (= rtl-reg machine-reg))
	    (suffix-instructions!
	     (register->register-transfer machine-reg rtl-reg))))
      (begin
	(delete-register! rtl-reg)
	(flush-register! machine-reg)
	(add-pseudo-register-alias! rtl-reg machine-reg))))

(define (object->machine-register! object mreg)
  (require-register! mreg)
  (load-constant (INST-EA (R ,mreg)) object))

(define (assign-register->register target source)
  (move-to-alias-register! source (register-type target) target)
  (LAP))

(define (convert-object/constant->register target constant conversion)
  (delete-dead-registers!)
  (let ((target (target-register-reference target)))
    (if (non-pointer-object? constant)
	;; Is this correct if conversion is object->address ?
	(load-non-pointer target 0 (careful-object-datum constant))
	(LAP ,@(load-constant target constant)
	     ,@(conversion target)))))

(define (non-pointer->literal object)
  (make-non-pointer-literal (object-type object)
			    (careful-objct-datum object)))

(define (load-immediate target value)
  (if (zero? value)
      (XOR W ,target ,target)
      (MOV W ,target (& ,value))))

(define (load-non-pointer target type datum)
  (let ((immediate-value (make-non-pointer-literal type datum)))
    (if (zero? immediate-value)
	(XOR W ,target ,target)
	(MOV W ,target (&U ,immediate-value)))))

(define (load-constant target obj)
  (if (non-pointer-object? obj)
      (load-non-pointer target (object-type obj) (careful-object-datum obj))
      (load-pc-relative target (free-constant-label obj))))

(define (load-pc-relative target label-expr)
  (with-pc-relative-address
    (lambda (pc-label pc-register)
      (LAP (MOV W ,target (@RO ,pc-register (- ,label-expr ,pc-label)))))))

(define (load-pc-relative-address target label-expr)
  (with-pc-relative-address
    (lambda (pc-label pc-register)
      (LAP (LEA ,target (@RO ,pc-register (- ,label-expr ,pc-label)))))))

(define (compare/register*register reg1 reg2)
  (cond ((register-alias reg1 'GENERAL)
	 =>
	 (lambda (alias)
	   (LAP (CMP W ,(register-reference alias) ,(any-reference reg2)))))
	((register-alias reg2 'GENERAL)
	 =>
	 (lambda (alias)
	   (LAP (CMP W ,(any-reference reg1) ,(register-reference alias)))))
	(else
	 (LAP (CMP W ,(source-register-reference reg1)
		   ,(any-reference reg2))))))

(define (two-arg-register-operation
	 operate commutative?
	 target-type source-reference alternate-source-reference
	 target source1 source2)
  (let* ((worst-case
	  (lambda (target source1 source2)
	    (LAP ,@(if (eq? target-type 'FLOAT)
		       (load-float-register source1 target)
		       (LAP (MOV W ,target ,source1)))
		 ,@(operate target source2))))
	 (new-target-alias!
	  (lambda ()
	    (let ((source1 (alternate-source-reference source1))
		  (source2 (source-reference source2)))
	      (delete-dead-registers!)
	      (worst-case (reference-target-alias! target target-type)
			  source1
			  source2)))))
    (cond ((pseudo-register? target)
	   (reuse-pseudo-register-alias
	    source1 target-type
	    (lambda (alias)
	      (let ((source2 (if (= source1 source2)
				 (register-reference alias)
				 (source-reference source2))))
		(delete-register! alias)
		(delete-dead-registers!)
		(add-pseudo-register-alias! target alias)
		(operate (register-reference alias) source2)))
	    (lambda ()
	      (if commutative?
		  (reuse-pseudo-register-alias
		   source2 target-type
		   (lambda (alias2)
		     (let ((source1 (source-reference source1)))
		       (delete-register! alias2)
		       (delete-dead-registers!)
		       (add-pseudo-register-alias! target alias2)
		       (operate (register-reference alias2) source1)))
		   new-target-alias!)
		  (new-target-alias!)))))
	  ((not (eq? target-type (register-type target)))
	   (error "two-arg-register-operation: Wrong type register"
		  target target-type))
	  (else
	   (worst-case (register-reference target)
		       (alternate-source-reference source1)
		       (source-reference source2))))))

;;; *** Here ***

;;;; Register-Allocator Interface

(define (reference->register-transfer source target)
  (if (and (effective-address/register? source)
	   (= (lap:ea-R-register source) target))
      (LAP)
      (LAP (MOV L ,source ,(register-reference target)))))

(define (register->register-transfer source target)
  (LAP ,@(machine->machine-register source target)))

(define (home->register-transfer source target)
  (LAP ,@(pseudo->machine-register source target)))

(define (register->home-transfer source target)
  (LAP ,@(machine->pseudo-register source target)))

(define-integrable (pseudo-register-home register)
  (offset-reference regnum:regs-pointer
		    (pseudo-register-offset register)))

(define-integrable (sort-machine-registers registers)
  registers)

(define available-machine-registers
  ;; r9 is value register.
  ;; r10 - r13 are taken up by Scheme.
  ;; r14 is sp and r15 is pc.
  (list r0 r1 r2 r3 r4 r5 r6 r7 r8))

(define (register-types-compatible? type1 type2)
  (boolean=? (eq? type1 'FLOAT) (eq? type2 'FLOAT)))

(define (register-type register)
  ;; This will have to be changed when floating point support is added.
  (if (or (machine-register? register)
	  (register-value-class=word? register))
      'GENERAL
      (error "unable to determine register type" register)))

(define register-reference
  (let ((references (make-vector number-of-machine-registers)))
    (let loop ((i 0))
      (if (< i number-of-machine-registers)
	  (begin
	    (vector-set! references i (INST-EA (R ,i)))
	    (loop (1+ i)))))
    (lambda (register)
      (vector-ref references register))))

(define mask-reference
  (register-reference regnum:pointer-mask))

(define (lap:make-label-statement label)
  ;; This should use LAP rather than INST, but
  ;; that requires changing back/linear.scm
  (INST (LABEL ,label)))

(define (lap:make-unconditional-branch label)
  (LAP (BR (@PCR ,label))))		; Unsized

(define (lap:make-entry-point label block-start-label)
  block-start-label
  (LAP (ENTRY-POINT ,label)
       ,@(make-external-label expression-code-word label)))

;;;; Basic Machine Instructions

(define-integrable (pseudo->machine-register source target)
  (memory->machine-register (pseudo-register-home source) target))

(define-integrable (machine->pseudo-register source target)
  (machine-register->memory source (pseudo-register-home target)))

(define (pseudo-float? register)
  (and (pseudo-register? register)
       (value-class=float? (pseudo-register-value-class register))))

(define (pseudo-word? register)
  (and (pseudo-register? register)
       (value-class=word? (pseudo-register-value-class register))))

(define-integrable (machine->machine-register source target)
  (LAP (MOV L
	    ,(register-reference source)
	    ,(register-reference target))))

(define-integrable (machine-register->memory source target)
  (LAP (MOV L
	    ,(register-reference source)
	    ,target)))

(define-integrable (memory->machine-register source target)
  (LAP (MOV L
	    ,source
	    ,(register-reference target))))

(define (byte-offset-reference register offset)
  (if (zero? offset)
      (INST-EA (@R ,register))
      (INST-EA (@RO ,(datum-size offset) ,register ,offset))))

(define-integrable (offset-reference register offset)
  (byte-offset-reference register (* 4 offset)))

(define-integrable (pseudo-register-offset register)
  ;; Offset into register block for temporary registers
  (+ (+ (* 16 4) (* 40 8))
     (* 2 (register-renumber register))))

(define (datum-size datum)
  (cond ((<= -128 datum 127) 'B)
	((<= -32768 datum 32767) 'W)
	(else 'L)))

;;;; Utilities needed by the rules files.

(define-integrable (standard-target-reference target)
  (delete-dead-registers!)
  (reference-target-alias! target 'GENERAL))

(define-integrable (any-register-reference register)
  (standard-register-reference register false true))

(define-integrable (standard-temporary-reference)
  (reference-temporary-register! 'GENERAL))

;;; Assignments

(define-integrable (convert-object/constant->register target constant
						      rtconversion
						      ctconversion)
  (let ((target (standard-target-reference target)))
    (if (non-pointer-object? constant)
	(ctconversion constant target)
	(rtconversion (constant->ea constant) target))))

(define-integrable (convert-object/register->register target source conversion)
  ;; `conversion' often expands into multiple references to `target'.
  (with-register-copy-alias! source 'GENERAL target
    (lambda (target)
      (conversion target target))
    conversion))

(define-integrable (convert-object/offset->register target address
						    offset conversion)
  (let ((source (indirect-reference! address offset)))
    (conversion source 
		(standard-target-reference target))))

;;; Predicates

(define (predicate/memory-operand? expression)
  (or (rtl:offset? expression)
      (and (rtl:post-increment? expression)
	   (interpreter-stack-pointer?
	    (rtl:post-increment-register expression)))))

(define (predicate/memory-operand-reference expression)
  (case (rtl:expression-type expression)
    ((OFFSET) (offset->indirect-reference! expression))
    ((POST-INCREMENT) (INST-EA (@R+ 14)))
    (else (error "Illegal memory operand" expression))))

(define (compare/register*register register-1 register-2 cc)
  (set-standard-branches! cc)
  (LAP (CMP L ,(any-register-reference register-1)
	    ,(any-register-reference register-2))))

(define (compare/register*memory register memory cc)
  (set-standard-branches! cc)
  (LAP (CMP L ,(any-register-reference register) ,memory)))

(define (compare/memory*memory memory-1 memory-2 cc)
  (set-standard-branches! cc)
  (LAP (CMP L ,memory-1 ,memory-2)))

;;;; Utilities needed by the rules files (contd.)

;;; Interpreter and interface calls

(define (interpreter-call-argument? expression)
  (or (rtl:register? expression)
      (rtl:constant? expression)
      (and (rtl:cons-pointer? expression)
	   (rtl:machine-constant? (rtl:cons-pointer-type expression))
	   (rtl:machine-constant? (rtl:cons-pointer-datum expression)))
      (and (rtl:offset? expression)
	   (rtl:register? (rtl:offset-base expression)))))

(define (interpreter-call-argument->machine-register! expression register)
  (let ((target (register-reference register)))
    (case (car expression)
      ((REGISTER)
       (load-machine-register! (rtl:register-number expression) register))
      ((CONSTANT)
       (LAP ,@(clear-registers! register)
	    ,@(load-constant (rtl:constant-value expression) target)))
      ((CONS-POINTER)
       (LAP ,@(clear-registers! register)
	    ,@(load-non-pointer (rtl:machine-constant-value
				 (rtl:cons-pointer-type expression))
				(rtl:machine-constant-value
				 (rtl:cons-pointer-datum expression))
				target)))
      ((OFFSET)
       (let ((source-reference (offset->indirect-reference! expression)))
	 (LAP ,@(clear-registers! register)
	      (MOV L ,source-reference ,target))))
      (else
       (error "Unknown expression type" (car expression))))))

;;;; Utilities needed by the rules files (contd.)

;;; Object structure.

(define (cons-pointer/ea type-ea datum target)
  (LAP (ROTL (S ,scheme-datum-width) ,type-ea ,target)
       (BIS L ,datum ,target)))

(define (cons-pointer/constant type datum target)
  (if (ea/same? datum target)
      (LAP (BIS L (&U ,(make-non-pointer-literal type 0)) ,target))
      (cons-pointer/ea (INST-EA (S ,type)) datum target)))

(define (set-type/ea type-ea target)
  (LAP (INSV ,type-ea (S ,scheme-datum-width) (S ,scheme-type-width)
	     ,target)))

(define-integrable (set-type/constant type target)
  (set-type/ea (INST-EA (S ,type)) target))

(define-integrable (extract-type source target)
  (LAP (EXTV Z (S ,scheme-datum-width) (S ,scheme-type-width)
	     ,source ,target)))

(define (object->type source target)
  (extract-type source target))

(define-integrable (ct/object->type object target)
  (load-immediate (object-type object) target))

(define (object->datum source target)
  (if (eq? source target)
      (LAP (BIC L ,mask-reference ,target))
      (LAP (BIC L ,mask-reference ,source ,target))))

(define-integrable (ct/object->datum object target)
  (load-immediate (object-datum object) target))

(define (object->address source target)
  (declare (integrate-operator object->datum))
  (object->datum source target))

(define-integrable (ct/object->address object target)
  (declare (integrate-operator ct/object->datum))
  (ct/object->datum object target))

(define (compare-type type ea)
  (set-standard-branches! 'EQL)
  (LAP (CMPV Z (S ,scheme-datum-width) (S ,scheme-type-width)
	     ,ea ,(make-immediate type))))

;;;; Utilities needed by the rules files (contd.)

(define-integrable (ea/same? ea1 ea2)
  (equal? ea1 ea2))

(define (ea/copy source target)
  (if (ea/same? source target)
      (LAP)
      (LAP (MOV L ,source ,target))))

(define (increment/ea ea offset)
  (cond ((zero? offset)
	 (LAP))
	((= offset 1)
	 (LAP (INC L ,ea)))
	((= offset -1)
	 (LAP (DEC L ,ea)))
	((<= 0 offset 63)
	 (LAP (ADD L (S ,offset) ,ea)))
	((<= -63 offset 0)
	 (LAP (SUB L (S ,(- 0 offset)) ,ea)))
	((effective-address/register? ea)
	 (let ((size (datum-size offset)))
	   (if (not (eq? size 'L))
	       (LAP (MOVA L (@RO ,size ,(lap:ea-R-register ea) ,offset)
			  ,ea))
	       (LAP (ADD L (& ,offset) ,ea)))))
	(else
	 (LAP (ADD L (& ,offset) ,ea)))))

(define (add-constant/ea source offset target)
  (if (ea/same? source target)
      (increment/ea target offset)
      (cond ((zero? offset)
	     (LAP (MOV L ,source ,target)))
	    ((<= 0 offset 63)
	     (LAP (ADD L (S ,offset) ,source ,target)))
	    ((<= -63 offset 0)
	     (LAP (SUB L (S ,(- 0 offset)) ,source ,target)))
	    ((effective-address/register? source)
	     (let ((size (datum-size offset)))
	       (if (not (eq? size 'L))
		   (LAP (MOVA L (@RO ,size ,(lap:ea-R-register source) ,offset)
			      ,target))
		   (LAP (ADD L (& ,offset) ,source ,target)))))
	    (else
	     (LAP (ADD L (& ,offset) ,source ,target))))))

(define-integrable (increment-rn rn value)
  (increment/ea (INST-EA (R ,rn)) value))

;;;; Utilities needed by the rules files (contd.)

;;; Constants

(define (make-immediate value)
  (if (<= 0 value 63)
      (INST-EA (S ,value))
      (INST-EA (& ,value))))

(define (constant->ea constant)
  (if (non-pointer-object? constant)
      (non-pointer->ea (object-type constant)
		       (careful-object-datum constant))
      (INST-EA (@PCR ,(constant->label constant)))))

(define (non-pointer->ea type datum)
  (if (and (zero? type)
	   (<= 0 datum 63))
      (INST-EA (S ,datum))
      (INST-EA (&U ,(make-non-pointer-literal type datum)))))

(define (load-constant constant target)
  (if (non-pointer-object? constant)
      (load-non-pointer (object-type constant)
			(object-datum constant)
			target)
      (LAP (MOV L (@PCR ,(constant->label constant)) ,target))))

(define (load-non-pointer type datum target)
  (if (not (zero? type))
      (LAP (MOV L (&U ,(make-non-pointer-literal type datum)) ,target))
      (load-immediate datum target)))

(define (load-immediate value target)
  (cond ((zero? value)
	 (LAP (CLR L ,target)))
	((<= 0 value 63)
	 (LAP (MOV L (S ,value) ,target)))
	(else
	 (let ((size (datum-size value)))
	   (if (not (eq? size 'L))
	       (LAP (CVT ,size L (& ,value) ,target))
	       (LAP (MOV L (& ,value) ,target)))))))

(define-integrable (load-rn value rn)
  (load-immediate value (INST-EA (R ,rn))))

;;;; Utilities needed by the rules files (contd.)

;;; Predicate utilities

(define (set-standard-branches! condition-code)
  (set-current-branches!
   (lambda (label)
     (LAP (B ,condition-code (@PCR ,label))))
   (lambda (label)
     (LAP (B ,(invert-cc condition-code) (@PCR ,label))))))

(define (test-byte n effective-address)
  (cond ((zero? n)
	 (LAP (TST B ,effective-address)))
	((<= 0 n 63)
	 (LAP (CMP B ,effective-address (S ,n))))
	(else
	 (LAP (CMP B ,effective-address (& ,n))))))

(define (test-non-pointer type datum effective-address)
  (cond ((not (zero? type))
	 (LAP (CMP L
		   ,effective-address
		   (&U ,(make-non-pointer-literal type datum)))))
	((zero? datum)
	 (LAP (TST L ,effective-address)))
	((<= 0 datum 63)
	 (LAP (CMP L ,effective-address (S ,datum))))
	(else
	 (LAP (CMP L
		   ,effective-address
		   (&U ,(make-non-pointer-literal type datum)))))))

(define (invert-cc condition-code)
  (cdr (or (assq condition-code
		 '((NEQU . EQLU) (EQLU . NEQU)
		   (NEQ . EQL) (EQL . NEQ)
		   (GTR . LEQ) (LEQ . GTR)
		   (GEQ . LSS) (LSS . GEQ)
		   (VC . VS) (VS . VC)
		   (CC . CS) (CS . CC)
		   (GTRU . LEQU) (LEQU . GTRU)
		   (GEQU . LSSU) (LSSU . GEQU)))
	   (error "INVERT-CC: Not a known CC" condition-code))))

(define (invert-cc-noncommutative condition-code)
  ;; Despite the fact that the name of this procedure is similar to
  ;; that of `invert-cc', it is quite different.  `invert-cc' is used
  ;; when the branches of a conditional are being exchanged, while
  ;; this is used when the arguments are being exchanged.
  (cdr (or (assq condition-code
		 '((NEQU . NEQU) (EQLU . EQLU)
     		   (NEQ . NEQ) (EQL . EQL)
		   (GTR . LSS) (LSS . GTR)
		   (GEQ . LEQ) (LEQ . GEQ)
		   ;; *** Are these two really correct? ***
		   (VC . VC) (VS . VS)
		   (CC . CC) (CS . CS)
		   (GTRU . LSSU) (LSSU . GTRU)
		   (GEQU . LEQU) (LEQU . GEQU)))
	   (error "INVERT-CC-NONCOMMUTATIVE: Not a known CC" condition-code))))

;;;; Utilities needed by the rules files (contd.)

(define-integrable (effective-address/register? ea)
  (eq? (lap:ea-keyword ea) 'R))

(define-integrable (effective-address/register-indirect? ea)
  (eq? (lap:ea-keyword ea) '@R))

(define-integrable (effective-address/register-offset? ea)
  (eq? (lap:ea-keyword ea) '@RO))

(define (offset->indirect-reference! offset)
  (indirect-reference! (rtl:register-number (rtl:offset-base offset))
		       (rtl:offset-number offset)))

(define-integrable (indirect-reference! register offset)
  (offset-reference (allocate-indirection-register! register) offset))

(define-integrable (indirect-byte-reference! register offset)
  (byte-offset-reference (allocate-indirection-register! register) offset))

(define (allocate-indirection-register! register)
  (load-alias-register! register 'GENERAL))

(define (generate-n-times n limit instruction-gen with-counter)
  (if (> n limit)
      (let ((loop (generate-label 'LOOP)))
	(with-counter
	  (lambda (counter)
	    (LAP ,@(load-rn (-1+ n) counter)
		 (LABEL ,loop)
		 ,@(instruction-gen)
		 (SOB GEQ (R ,counter) (@PCR ,loop))))))
      (let loop ((n n))
	(if (zero? n)
	    (LAP)
	    (LAP ,@(instruction-gen)
		 ,@(loop (-1+ n)))))))

;;;; Utilities needed by the rules files (contd.)

;;; CHAR->ASCII utilities

(define (coerce->any/byte-reference register)
  (if (machine-register? register)
      (register-reference register)
      (let ((alias (register-alias register false)))
	(if alias
	    (register-reference alias)
	    (indirect-char/ascii-reference!
	     regnum:regs-pointer
	     (pseudo-register-offset register))))))

(define-integrable (indirect-char/ascii-reference! register offset)
  (indirect-byte-reference! register (* offset 4)))

(define (char->signed-8-bit-immediate character)
  (let ((ascii (char->ascii character)))
    (if (< ascii 128)
	ascii
	(- ascii 256))))

(define-integrable (lap:ea-keyword expression)
  (car expression))

(define-integrable (lap:ea-R-register expression)
  (cadr expression))

(define-integrable (lap:ea-@R-register expression)
  (cadr expression))

(define-integrable (lap:ea-@RO-register expression)
  (caddr expression))

(define-integrable (lap:ea-@RO-offset expression)
  (cadddr expression))

;;;; Utilities needed by the rules files (contd.)

;;; Layout of the Scheme register array.

(define-integrable reg:compiled-memtop (INST-EA (@R 10)))
(define-integrable reg:environment (INST-EA (@RO B 10 #x000C)))
(define-integrable reg:temp (INST-EA (@RO B 10 #x0010)))
(define-integrable reg:lexpr-primitive-arity (INST-EA (@RO B 10 #x001C)))

(let-syntax ((define-codes
	       (macro (start . names)
		 (define (loop names index)
		   (if (null? names)
		       '()
		       (cons `(DEFINE-INTEGRABLE
				,(symbol-append 'CODE:COMPILER-
						(car names))
				,index)
			     (loop (cdr names) (1+ index)))))
		 `(BEGIN ,@(loop names start)))))
  (define-codes #x012
    primitive-apply primitive-lexpr-apply
    apply error lexpr-apply link
    interrupt-closure interrupt-dlink interrupt-procedure 
    interrupt-continuation interrupt-ic-procedure
    assignment-trap cache-reference-apply
    reference-trap safe-reference-trap unassigned?-trap
    -1+ &/ &= &> 1+ &< &- &* negative? &+ positive? zero?
    access lookup safe-lookup unassigned? unbound?
    set! define lookup-apply))

(let-syntax ((define-entries
	       (macro (start . names)
		 (define (loop names index)
		   (if (null? names)
		       '()
		       (cons `(DEFINE-INTEGRABLE
				,(symbol-append 'ENTRY:COMPILER-
						(car names))
				(INST-EA (@RO B 10 ,index)))
			     (loop (cdr names) (+ index 8)))))
		 `(BEGIN ,@(loop names start)))))
  (define-entries #x40
    scheme-to-interface			; Main entry point (only one necessary)
    scheme-to-interface-jsb		; Used by rules3&4, for convenience.
    trampoline-to-interface		; Used by trampolines, for convenience.
    ;; If more are added, the size of the addressing mode must be changed.
    ))

(define-integrable (invoke-interface code)
  (LAP ,@(load-rn code 0)
       (JMP ,entry:compiler-scheme-to-interface)))

#|
;; If the entry point scheme-to-interface-jsb were not available,
;; this code should replace the definition below.
;; The others can be handled similarly.

(define-integrable (invoke-interface-jsb code)
  (LAP ,@(load-rn code 0)
       (MOVA B (@PCO B 10) (R 1))
       (JMP ,entry:compiler-scheme-to-interface)))
|#

(define-integrable (invoke-interface-jsb code)
  (LAP ,@(load-rn code 0)
       (JSB ,entry:compiler-scheme-to-interface-jsb)))
