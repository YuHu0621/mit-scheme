#| -*-Scheme-*-

$Id: thread.scm,v 1.8 1993/01/29 16:31:20 cph Exp $

Copyright (c) 1991-1993 Massachusetts Institute of Technology

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

;;;; Multiple Threads of Control
;;; package: (runtime thread)

(declare (usual-integrations))

(define-structure (thread
		   (constructor make-thread ())
		   (conc-name thread/))
  (execution-state 'RUNNING)
  ;; One of:
  ;; RUNNING
  ;; RUNNING-WITHOUT-PREEMPTION
  ;; WAITING
  ;; DEAD

  (next false)
  ;; Pointer to next thread in run queue, or #F if none.

  (continuation false)
  ;; #F if current thread or exited, else continuation for thread.

  (block-events? false)
  ;; If true, events may not be delivered to this thread.  Instead,
  ;; they are queued.

  (pending-events (make-ring) read-only true)
  ;; Doubly-linked circular list of events waiting to be delivered.

  (joined-threads '())
  ;; List of threads that have successfully called JOIN-THREAD on this
  ;; thread.

  (exit-value no-exit-value-marker)
  ;; If the thread exits, the exit value is stored here so that
  ;; joined threads can get it.  If the thread has been detached,
  ;; this field holds a condition of type THREAD-DETACHED.

  (properties (make-1d-table) read-only true))

(define-integrable (guarantee-thread thread procedure)
  (declare (integrate-operator thread?))
  (if (not (thread? thread))
      (error:wrong-type-argument thread "thread" procedure)))

(define no-exit-value-marker
  (list 'NO-EXIT-VALUE-MARKER))

(define-integrable (thread-waiting? thread)
  (eq? 'WAITING (thread/execution-state thread)))

(define-integrable (thread-dead? thread)
  (eq? 'DEAD (thread/execution-state thread)))

;;; Threads whose execution state is RUNNING.
(define first-running-thread)
(define last-running-thread)

(define thread-timer-running?)
(define root-continuation-default)

(define-integrable (without-interrupts thunk)
  (let ((interrupt-mask (set-interrupt-enables! interrupt-mask/gc-ok)))
    (let ((value (thunk)))
      (set-interrupt-enables! interrupt-mask)
      value)))

(define (initialize-package!)
  (initialize-error-conditions!)
  (set! first-running-thread false)
  (set! last-running-thread false)
  (set! thread-timer-running? false)
  (set! timer-records false)
  (set! timer-interval 100)
  (set! last-real-time false)
  (let ((thread (make-thread)))
    (set-thread/continuation! thread false)
    (thread-running thread)
    (detach-thread thread))
  (add-event-receiver! event:before-exit stop-thread-timer))

(define (create-thread root-continuation thunk)
  (if (not (or (not root-continuation) (continuation? root-continuation)))
      (error:wrong-type-argument root-continuation
				 "continuation or #f"
				 create-thread))
  (call-with-current-continuation
   (lambda (return)
     (%within-continuation (or root-continuation root-continuation-default)
			   true
       (lambda ()
	 (fluid-let ((state-space:local (make-state-space)))
	   (call-with-current-continuation
	    (lambda (continuation)
	      (let ((thread (make-thread)))
		(set-thread/continuation! thread continuation)
		(thread-running thread)
		(%within-continuation return true (lambda () thread)))))
	   (set-interrupt-enables! interrupt-mask/all)
	   (exit-current-thread (thunk))))))))

(define (create-thread-continuation)
  root-continuation-default)

(define (with-create-thread-continuation continuation thunk)
  (if (not (continuation? continuation))
      (error:wrong-type-argument continuation
				 "continuation"
				 with-create-thread-continuation))
  (fluid-let ((root-continuation-default continuation))
    (thunk)))

(define-integrable (current-thread)
  (or first-running-thread (error "No current thread!")))

(define (thread-continuation thread)
  (guarantee-thread thread thread-continuation)
  (without-interrupts
   (lambda ()
     (and (thread-waiting? thread)
	  (thread/continuation thread)))))

(define (thread-running thread)
  (set-thread/execution-state! thread 'RUNNING)
  (let ((prev last-running-thread))
    (if prev
	(set-thread/next! prev thread)
	(set! first-running-thread thread)))
  (set! last-running-thread thread)
  (%maybe-toggle-thread-timer))

(define (thread-not-running thread state)
  (set-thread/execution-state! thread state)
  (let ((thread* (thread/next thread)))
    (set-thread/next! thread false)
    (set! first-running-thread thread*)
    (if (not thread*)
	(begin
	  (set! last-running-thread thread*)
	  (%maybe-toggle-thread-timer)
	  ;; Busy-waiting here is a bad idea -- should implement a
	  ;; primitive to block the Scheme process while waiting for
	  ;; a signal.
	  (set-interrupt-enables! interrupt-mask/all)
	  (do () (false)))
	(run-thread thread*))))

(define (run-thread thread)
  (let ((continuation (thread/continuation thread)))
    (set-thread/continuation! thread false)
    (let ((event
	   (and (not (thread/block-events? thread))
		(ring/dequeue (thread/pending-events thread) false))))
      (%within-continuation continuation true
	(if (not event)
	    %maybe-toggle-thread-timer
	    (lambda ()
	      (%maybe-toggle-thread-timer)
	      (handle-thread-event thread event)
	      (set-thread/block-events?! thread false)))))))

(define (suspend-current-thread)
  (without-interrupts
   (lambda ()
     (let ((thread (current-thread)))
       (let ((block-events? (thread/block-events? thread))
	     (event (ring/dequeue (thread/pending-events thread) false)))
	 (if event
	     (handle-thread-event thread event)
	     (begin
	       (set-thread/block-events?! thread false)
	       (call-with-current-continuation
		(lambda (continuation)
		  (set-thread/continuation! thread continuation)
		  (thread-not-running thread 'WAITING)))))
	 (if (not block-events?)
	     (unblock-events thread)))))))

(define (disallow-preempt-current-thread)
  (set-thread/execution-state! (current-thread) 'RUNNING-WITHOUT-PREEMPTION))

(define (allow-preempt-current-thread)
  (set-thread/execution-state! (current-thread) 'RUNNING))

(define (thread-timer-interrupt-handler)
  (set-interrupt-enables! interrupt-mask/gc-ok)
  (deliver-timer-events)
  (let ((thread first-running-thread))
    (cond ((not thread)
	   (%maybe-toggle-thread-timer))
	  ((thread/continuation thread)
	   (run-thread thread))
	  ((not (eq? 'RUNNING-WITHOUT-PREEMPTION
		     (thread/execution-state thread)))
	   (yield-thread thread))
	  (else
	   (%maybe-toggle-thread-timer)))))

(define (yield-current-thread)
  (let ((thread (current-thread)))
    (without-interrupts
     (lambda ()
       ;; Allow preemption now, since the current thread has
       ;; volunteered to yield control.
       (set-thread/execution-state! thread 'RUNNING)
       (yield-thread thread)))))

(define (other-running-threads?)
  (thread/next (current-thread)))

(define-integrable (yield-thread thread)
  (let ((next (thread/next thread)))
    (if (not next)
	(%maybe-toggle-thread-timer)
	(call-with-current-continuation
	 (lambda (continuation)
	   (set-thread/continuation! thread continuation)
	   (set-thread/next! thread false)
	   (set-thread/next! last-running-thread thread)
	   (set! last-running-thread thread)
	   (set! first-running-thread next)
	   (run-thread next))))))

(define (exit-current-thread value)
  (let ((thread (current-thread)))
    (set-interrupt-enables! interrupt-mask/gc-ok)
    (if (eq? no-exit-value-marker (thread/exit-value thread))
	(release-joined-threads thread value))
    (thread-not-running thread 'DEAD)))

(define (join-thread thread event-constructor)
  (guarantee-thread thread join-thread)
  (let ((self (current-thread)))
    (if (eq? thread self)
	(signal-thread-deadlock self "join thread" join-thread thread)
	(without-interrupts
	 (lambda ()
	   (let ((value (thread/exit-value thread)))
	     (cond ((eq? value no-exit-value-marker)
		    (set-thread/joined-threads!
		     thread
		     (cons (cons self event-constructor)
			   (thread/joined-threads thread))))
		   ((eq? value detached-thread-marker)
		    (signal-thread-detached thread))
		   (else
		    (signal-thread-event
		     self
		     (event-constructor thread value))))))))))

(define (detach-thread thread)
  (guarantee-thread thread detach-thread)
  (without-interrupts
   (lambda ()
     (if (eq? (thread/exit-value thread) detached-thread-marker)
	 (signal-thread-detached thread))
     (release-joined-threads thread detached-thread-marker))))

(define detached-thread-marker
  (list 'DETACHED-THREAD-MARKER))

(define (release-joined-threads thread value)
  (set-thread/exit-value! thread value)
  (do ((joined (thread/joined-threads thread) (cdr joined)))
      ((null? joined))
    (let ((thread (caar joined))
	  (event ((cdar joined) thread value)))
      (if (not (thread-dead? thread))
	  (begin
	    (ring/enqueue (thread/pending-events thread) event)
	    (if (and (not (thread/block-events? thread))
		     (thread-waiting? thread))
		(thread-running thread)))))))

;;;; Events

(define (block-thread-events)
  (without-interrupts
   (lambda ()
     (let ((thread (current-thread)))
       (let ((result (thread/block-events? thread)))
	 (set-thread/block-events?! thread true)
	 result)))))

(define (unblock-thread-events)
  (without-interrupts
   (lambda ()
     (unblock-events (current-thread)))))

(declare (integrate-operator unblock-events))

(define (unblock-events thread)
  (let loop ()
    (let ((event (ring/dequeue (thread/pending-events thread) false)))
      (if event
	  (begin
	    (handle-thread-event thread event)
	    (loop)))))
  (set-thread/block-events?! thread false))

(define (signal-thread-event thread event)
  (guarantee-thread thread signal-thread-event)
  (let ((self first-running-thread))
    (if (eq? thread self)
	(let ((block-events? (block-thread-events)))
	  (ring/enqueue (thread/pending-events thread) event)
	  (if (not block-events?)
	      (unblock-thread-events)))
	(without-interrupts
	 (lambda ()
	   (if (thread-dead? thread)
	       (signal-thread-dead thread "signal event to"
				   signal-thread-event thread event))
	   (ring/enqueue (thread/pending-events thread) event)
	   (if (and (not (thread/block-events? thread))
		    (thread-waiting? thread))
	       (begin
		 (thread-running thread)
		 (if (not self)
		     (run-thread thread)))))))))

(define-integrable (handle-thread-event thread event)
  (set-thread/block-events?! thread true)
  (set-interrupt-enables! interrupt-mask/all)
  (event)
  (set-interrupt-enables! interrupt-mask/gc-ok)
  (set-thread/block-events?! thread true))

;;;; Timer Events

(define last-real-time)
(define timer-records)
(define timer-interval)

(define-structure (timer-record
		   (type vector)
		   (conc-name timer-record/))
  (time false read-only false)
  (thread false read-only true)
  next
  delivered?)

(define (sleep-current-thread interval)
  (let ((time (+ (real-time-clock) interval)))
    (let ((block-events? (block-thread-events)))
      (let ((new-record (vector time (current-thread) false false)))
	(without-interrupts
	 (lambda ()
	   (let loop ((record timer-records) (prev false))
	     (if (or (not record) (< time (timer-record/time record)))
		 (begin
		   (set-timer-record/next! new-record record)
		   (if prev
		       (set-timer-record/next! prev new-record)
		       (set! timer-records new-record)))
		 (loop (timer-record/next record) record)))))
	(do () ((timer-record/delivered? new-record))
	  (suspend-current-thread)))
      (if (not block-events?)
	  (unblock-thread-events)))))

(define (deliver-timer-events)
  (let ((time (real-time-clock)))
    (if (and last-real-time
	     (< time last-real-time))
	;; The following adjustment is correct, assuming that the
	;; real-time timer wraps around to 0, and assuming that there
	;; has been no GC or OS time slice between the time when the
	;; timer interrupt was delivered and the time when REAL-TIME-CLOCK
	;; was called above.
	(let ((wrap-value (+ last-real-time
			     (if (not timer-interval)
				 0
				 (- timer-interval time)))))
	  (let update ((record timer-records))
	    (if record
		(begin
		  (set-timer-record/time!
		   record
		   (- (timer-record/time record) wrap-value))
		  (update (timer-record/next record)))))))
    (set! last-real-time time)
    (let loop ((record timer-records))
      (if (or (not record) (< time (timer-record/time record)))
	  (set! timer-records record)
	  (begin
	    (set-timer-record/delivered?! record true)
	    (let ((thread (timer-record/thread record)))
	      (if (thread-waiting? thread)
		  (thread-running thread)))
	    (loop (timer-record/next record))))))
  unspecific)

(define-integrable (threads-pending-timer-events?)
  timer-records)

(define (thread-timer-interval)
  timer-interval)

(define (set-thread-timer-interval! interval)
  (if (not (or (false? interval)
	       (and (exact-integer? interval)
		    (> interval 0))))
      (error:wrong-type-argument interval false 'SET-THREAD-TIMER-INTERVAL!))
  (without-interrupts
    (lambda ()
      (set! timer-interval interval)
      (%maybe-toggle-thread-timer))))

(define (start-thread-timer)
  (without-interrupts %maybe-toggle-thread-timer))

(define (stop-thread-timer)
  (without-interrupts %stop-thread-timer))

(define (%maybe-toggle-thread-timer)
  (if (and timer-interval
	   (or (let ((current-thread first-running-thread))
		 (and current-thread
		      (thread/next current-thread)))
	       (threads-pending-timer-events?)))
      (if (not thread-timer-running?)
	  (begin
	    ((ucode-primitive real-timer-set) timer-interval timer-interval)
	    (set! thread-timer-running? true)
	    unspecific))
      (%stop-thread-timer)))

(define (%stop-thread-timer)
  (if thread-timer-running?
      (begin
	((ucode-primitive real-timer-clear))
	(set! thread-timer-running? false)
	((ucode-primitive clear-interrupts!) interrupt-bit/timer))))

;;;; Mutexes

(define-structure (thread-mutex
		   (constructor make-thread-mutex ())
		   (conc-name thread-mutex/))
  (waiting-threads (make-ring) read-only true)
  (owner false))

(define-integrable (guarantee-thread-mutex mutex procedure)
  (declare (integrate-operator thread-mutex?))
  (if (not (thread-mutex? mutex))
      (error:wrong-type-argument mutex "thread-mutex" procedure)))

(define (thread-mutex-owner mutex)
  (guarantee-thread-mutex mutex thread-mutex-owner)
  (thread-mutex/owner mutex))

(define (lock-thread-mutex mutex)
  (guarantee-thread-mutex mutex lock-thread-mutex)
  (without-interrupts
   (lambda ()
     (let ((thread (current-thread))
	   (owner (thread-mutex/owner mutex)))
       (cond ((not owner)
	      (set-thread-mutex/owner! mutex thread))
	     ((eq? owner thread)
	      (signal-thread-deadlock thread "lock thread mutex"
				      lock-thread-mutex mutex))
	     (else
	      (%lock-thread-mutex mutex thread)))))))

(define-integrable (%lock-thread-mutex mutex thread)
  (ring/enqueue (thread-mutex/waiting-threads mutex) thread)
  (do () ((eq? thread (thread-mutex/owner mutex)))
    (suspend-current-thread)))

(define (try-lock-thread-mutex mutex)
  (guarantee-thread-mutex mutex try-lock-thread-mutex)
  (without-interrupts
   (lambda ()
     (and (not (thread-mutex/owner mutex))
	  (begin
	    (set-thread-mutex/owner! mutex (current-thread))
	    true)))))

(define (unlock-thread-mutex mutex)
  (guarantee-thread-mutex mutex unlock-thread-mutex)
  (without-interrupts
   (lambda ()
     (if (not (eq? (thread-mutex/owner mutex) (current-thread)))
	 (error "Don't own mutex:" mutex))
     (%unlock-thread-mutex mutex))))

(define-integrable (%unlock-thread-mutex mutex)
  (let ((thread (ring/dequeue (thread-mutex/waiting-threads mutex) false)))
    (set-thread-mutex/owner! mutex thread)
    (if thread
	(signal-thread-event thread false))))

(define (with-thread-mutex-locked mutex thunk)
  (guarantee-thread-mutex mutex lock-thread-mutex)
  (let ((thread (current-thread))
	(grabbed-lock?))
    (dynamic-wind
     (lambda ()
       (let ((owner (thread-mutex/owner mutex)))
	 (if (eq? owner thread)
	     (begin
	       (set! grabbed-lock? false)
	       unspecific)
	     (begin
	       (set! grabbed-lock? true)
	       (if owner
		   (%lock-thread-mutex mutex thread)
		   (set-thread-mutex/owner! mutex thread))))))
     thunk
     (lambda ()
       (if (and grabbed-lock? (eq? (thread-mutex/owner mutex) thread))
	   (%unlock-thread-mutex mutex))))))

;;;; Circular Rings

(define-structure (link (conc-name link/))
  prev
  next
  item)

(define (make-ring)
  (let ((link (make-link false false false)))
    (set-link/prev! link link)
    (set-link/next! link link)
    link))

(define-integrable (ring/empty? ring)
  (eq? (link/next ring) ring))

(define (ring/enqueue ring item)
  (let ((prev (link/prev ring)))
    (let ((link (make-link prev ring item)))
      (set-link/next! prev link)
      (set-link/prev! ring link))))

(define (ring/dequeue ring default)
  (let ((link (link/next ring)))
    (if (eq? link ring)
	default
	(begin
	  (let ((next (link/next link)))
	    (set-link/next! ring next)
	    (set-link/prev! next ring))
	  (link/item link)))))

(define (ring/discard-all ring)
  (set-link/prev! ring ring)
  (set-link/next! ring ring))

;;;; Error Conditions

(define condition-type:thread-control-error)
(define thread-control-error/thread)
(define condition-type:thread-deadlock)
(define signal-thread-deadlock)
(define thread-deadlock/description)
(define thread-deadlock/operator)
(define thread-deadlock/operand)
(define condition-type:thread-detached)
(define signal-thread-detached)
(define condition-type:thread-dead)
(define signal-thread-dead)
(define thread-dead/verb)

(define (initialize-error-conditions!)
  (set! condition-type:thread-control-error
	(make-condition-type 'THREAD-CONTROL-ERROR condition-type:control-error
	    '(THREAD)
	  (lambda (condition port)
	    (write-string "Anonymous error associated with " port)
	    (write (thread-control-error/thread condition) port)
	    (write-string "." port))))
  (set! thread-control-error/thread
	(condition-accessor condition-type:thread-control-error 'THREAD))

  (set! condition-type:thread-deadlock
	(make-condition-type 'THREAD-DEADLOCK
	    condition-type:thread-control-error
	    '(DESCRIPTION OPERATOR OPERAND)
	  (lambda (condition port)
	    (write-string "Deadlock detected while trying to " port)
	    (write-string (thread-deadlock/description condition) port)
	    (write-string ": " port)
	    (write (thread-deadlock/operand condition) port)
	    (write-string "." port))))
  (set! signal-thread-deadlock
	(condition-signaller condition-type:thread-deadlock
			     '(THREAD DESCRIPTION OPERATOR OPERAND)
			     standard-error-handler))
  (set! thread-deadlock/description
	(condition-accessor condition-type:thread-deadlock 'DESCRIPTION))
  (set! thread-deadlock/operator
	(condition-accessor condition-type:thread-deadlock 'OPERATOR))
  (set! thread-deadlock/operand
	(condition-accessor condition-type:thread-deadlock 'OPERAND))

  (set! condition-type:thread-detached
	(make-condition-type 'THREAD-DETACHED
	    condition-type:thread-control-error
	    '()
	  (lambda (condition port)
	    (write-string "Attempt to join detached thread: " port)
	    (write-string (thread-control-error/thread condition) port)
	    (write-string "." port))))
  (set! signal-thread-detached
	(condition-signaller condition-type:thread-detached
			     '(THREAD)
			     standard-error-handler))

  (set! condition-type:thread-dead
	(make-condition-type 'THREAD-DEAD condition-type:thread-control-error
	    '(VERB OPERATOR OPERANDS)
	  (lambda (condition port)
	    (write-string "Unable to " port)
	    (write-string (thread-dead/verb condition) port)
	    (write-string " thread " port)
	    (write-string (thread-control-error/thread condition) port)
	    (write-string "because it is dead." port))))
  (set! signal-thread-dead
	(let ((signaller
	       (condition-signaller condition-type:thread-dead
				    '(THREAD VERB OPERATOR OPERANDS)
				    standard-error-handler)))
	  (lambda (thread verb operator . operands)
	    (signaller thread verb operator operands))))
  (set! thread-dead/verb
	(condition-accessor condition-type:thread-dead 'VERB))
  unspecific)