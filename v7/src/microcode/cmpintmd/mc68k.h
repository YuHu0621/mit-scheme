/* -*-C-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/cmpintmd/mc68k.h,v 1.19 1991/03/22 04:36:00 jinx Exp $

Copyright (c) 1989-1991 Massachusetts Institute of Technology

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
MIT in each case. */

/*
 *
 * Compiled code interface macros.
 *
 * See cmpint.txt for a description of these fields.
 *
 * Specialized for the Motorola 68K family.
 */

#ifndef CMPINT2_H_INCLUDED
#define CMPINT2_H_INCLUDED

#define COMPILER_NONE_TYPE			0
#define COMPILER_MC68020_TYPE			1
#define COMPILER_VAX_TYPE			2
#define COMPILER_SPECTRUM_TYPE			3
#define COMPILER_MIPS_TYPE			4
#define COMPILER_MC68040_TYPE			5
#define COMPILER_SPARC_TYPE			6
#define COMPILER_RS6000_TYPE			7
#define COMPILER_MC88K_TYPE			8

/* Machine parameters to be set by the user. */

/* Processor type.  Choose a number from the above list, or allocate your own. */

#ifndef COMPILER_PROCESSOR_TYPE
#  define COMPILER_PROCESSOR_TYPE		COMPILER_MC68020_TYPE
#endif

/* Size (in long words) of the contents of a floating point register if
   different from a double.  For example, an MC68881 saves registers
   in 96 bit (3 longword) blocks.
*/
#define COMPILER_TEMP_SIZE			3

/* Descriptor size.
   This is the size of the offset field, and of the format field.
   This definition probably does not need to be changed.
 */

typedef unsigned short format_word;

/* PC alignment constraint.
   Change PC_ZERO_BITS to be how many low order bits of the pc are
   guaranteed to be 0 always because of PC alignment constraints.
*/

#define PC_ZERO_BITS                    1

/* Skip over this many BYTES to bypass the GC check code (ordinary
procedures and continuations differ from closures) */

#define ENTRY_SKIPPED_CHECK_OFFSET 	4
#define CLOSURE_SKIPPED_CHECK_OFFSET 	10

extern unsigned long hppa_extract_absolute_address ();
extern void hppa_store_absolute_address ();
 */

#ifdef _NEXTOS

   On the 68k, when closures are invoked, the closure corresponding
   to the first entry point is what's needed on the top of the stack.
   Note that it is needed for environment only, not for code.
   The closure code does an
   ADDI.L	&magic-constant,(SP)
   on entry, to bump the current entry point (after the JSR instruction)
   to the correct place.
   This code emulates that operation by extracting the magic constant
   from the closure code, and adjusting the address by 6 as if the
   JSR instruction had just been executed.
   It is used when interrupts are disabled, in order not to get into a loop.
   Note that if closure entry points were always longword-aligned, there
   would be no need for this nonsense.
extern void EXFUN (flush_i_cache, (void));
extdo {									\
  long magic_constant;							\
									\
  magic_constant = (* ((long *) (((char *) (entry_point)) + 2)));	\
  (location) = ((SCHEME_OBJECT)						\
		((((long) (OBJECT_ADDRESS (location))) + 6) +		\
		 magic_constant));					\
} while (0)

/* Manifest closure entry block size. 
   Size in bytes of a compiled closure's header excluding the
   TC_MANIFEST_CLOSURE header.

   On the 68k, this is the format word and gc offset word and 6 bytes
   more for the jsr instruction.  
*/

#  define COMPILED_CLOSURE_ENTRY_SIZE					\
  ((2 * (sizeof (format_word))) + 6)

/* Manifest closure entry destructuring.

   Given the entry point of a closure, extract the `real entry point'
   (the address of the real code of the procedure, ie. one indirection)
   from the closure.
   Note that on some machines this address may be "smeared out" over
   multiple instructions.
*/

#  define EXTRACT_CLOSURE_ENTRY_ADDRESS(real_entry_point, entry_point)	\
{									\
  (real_entry_point) =							\
    (* ((SCHEME_OBJECT *) (((char *) (entry_point)) + 2)));		\
}

/* This is the inverse of EXTRACT_CLOSURE_ENTRY_ADDRESS.
   Given a closure's entry point and a code entry point, store the
   code entry point in the closure.
 */

#  define STORE_CLOSURE_ENTRY_ADDRESS(real_entry_point, entry_point)	\
{									\
  (* ((SCHEME_OBJECT *) (((char *) (entry_point)) + 2))) =		\
    ((SCHEME_OBJECT) (real_entry_point));				\
}

#endif /* (COMPILER_PROCESSOR_TYPE == COMPILER_MC68020_TYPE) */

#if (COMPILER_PROCESSOR_TYPE == COMPILER_MC68040_TYPE)

/* On the MC68040, closure entry points are aligned, so this is a NOP. */

#  define ADJUST_CLOSURE_AT_CALL(entry_point, location) NOP()

/* Cache flushing. */

#  ifdef _NEXTOS

#    define SPLIT_CACHES
#    define FLUSH_I_CACHE()			asm ("trap #2")
#    define FLUSH_I_CACHE_REGION(addr,nwords)	FLUSH_I_CACHE()

#  endif /* _NEXTOS */

#  ifdef __hpux

/* The following is a test for HP-UX >= 7.05 */

#    include <sys/time.h>
#    include <sys/resource.h>
#    include <sys/proc.h>

#    ifdef S2DATA_WT

/* This only works in HP-UX >= 7.05 */

#      include <sys/cache.h>

extern void EXFUN (operate_on_cache_region,(int, char *, unsigned long));

#      define SPLIT_CACHES

#      define FLUSH_I_CACHE()						\
  (void) (cachectl (CC_IPURGE, 0, 0))

#      define FLUSH_I_CACHE_REGION(addr, nwords)			\
  (operate_on_cache_region (CC_IPURGE, ((char *) (addr)), (nwords)))

#      define PUSH_D_CACHE_REGION(addr, nwords)				\
  (operate_on_cache_region (CC_FLUSH, ((char *) (addr)), (nwords)))

#      ifdef IN_CMPINT_C

void 
DEFUN (operate_on_cache_region,
       (cachecmd, base, nwords),
       int cachecmd AND char * base AND unsigned long)
{
  char * end;
  unsigned long nbytes, quantum;

  if (nwords == 0)
    return;
  
  nbytes = (nwords * (sizeof (long)));
  end = (base + (nbytes - 1));
  quantum = ((nbytes <= 0x40) ? 0x10 : 0x1000);

  for (base = ((char *) (((unsigned long) base) & (~(quantum - 1))))
       end = ((char *) (((unsigned long) end) & (~(quantum - 1))));
       (base <= end);
       base += quantum)
    (void) (cachectl (cachecmd, base, quantum));
  return;
}

#      endif /* IN_CMPINT_C */
#    else  /* S2DATA_WT */
#      define FLUSH_I_CACHE() NOP()
#    endif /* S2DATA_WT */
#  endif /* hpux */

#    ifndef FLUSH_I_CACHE
#      error "Cache flushing code needed for MC68040s"
#    endif

/* Manifest closure entry block size. 
   Size in bytes of a compiled closure's header excluding the
   TC_MANIFEST_CLOSURE header.

   On the 68040, this is the format word and gc offset word a 4-byte-long
   jsr instruction, and 4 bytes for the target address.
*/

#  define COMPILED_CLOSURE_ENTRY_SIZE					\
  ((2 * (sizeof (format_word))) + 4 + 4)

/* Manifest closure entry destructuring.

   EXTRACT_CLOSURE_ENTRY_ADDRESS(real_entry_point, entry_point)
   Given the entry point of a closure, extract the `real entry point'
   (the address of the real code of the procedure, ie. one indirection)
   from the closure.
   Note that on some machines this address may be "smeared out" over
   multiple instructions.

   STORE_CLOSURE_ENTRY_ADDRESS(real_entry_point, entry_point)
   is the inverse of EXTRACT_CLOSURE_ENTRY_ADDRESS.
   Given a closure's entry point and a code entry point, store the
   code entry point in the closure.
*/

#  ifndef GC_ELIMINATES_CLOSURE_HOOK

#    define EXTRACT_CLOSURE_ENTRY_ADDRESS(real_ep, entry_point) do	\
{									\
  (real_ep) =								\
    (* ((SCHEME_OBJECT *) (((char *) (entry_point)) + 4)));		\
} while (0)

#    define STORE_CLOSURE_ENTRY_ADDRESS(real_ep, entry_point) do	\
{									\
  (* ((SCHEME_OBJECT *) (((char *) (entry_point)) + 4))) =		\
    ((SCHEME_OBJECT) (real_ep));					\
} while (0)


#  else /* GC_ELIMINATES_CLOSURE_HOOK */


#    define EXTRACT_CLOSURE_ENTRY_ADDRESS(real_ep, entry_point) do	\
{									\
  unsigned short *pc = ((unsigned short *) (entry_point));		\
									\
  (real_ep) =								\
    (((*pc) == 0x4eae)							\
     ? (* ((SCHEME_OBJECT *) (((char *) pc) + 4)))			\
     : (* ((SCHEME_OBJECT *) (((char *) pc) + 2))));			\
} while (0)

/* This version changes the instructions to a more efficient version.
   It is assumed that this is done only by the GC or other processes
   that flush the I-cache at the end.
 */

#    define STORE_CLOSURE_ENTRY_ADDRESS(real_ep, entry_point) do	\
{									\
  unsigned short *pc = ((unsigned short *) (entry_point));		\
									\
  *pc++ = 0x4eb9;			/* JSR absolute */		\
  (* ((SCHEME_OBJECT *) pc)) = ((SCHEME_OBJECT) (real_ep));		\
} while (0)

#  endif /* GC_ELIMINATES_CLOSURE_HOOK */


#endif /* (COMPILER_PROCESSOR_TYPE == COMPILER_MC68040_TYPE) */


#ifndef ADJUST_CLOSURE_AT_CALL

#  include "ERROR: COMPILER_PROCESSOR_TYPE unknown"

#endif /* ADJUST_CLOSURE_AT_CALL */

#  error "COMPILER_PROCESSOR_TYPE unknown"
   contains both the number of arguments provided by the caller and
   code to jump to the destination address.  Before linkage, the cache


#ifndef FLUSH_I_CACHE_REGION
#  define FLUSH_I_CACHE_REGION(addr, nwords) NOP()
#endif /* not FLUSH_I_CACHE_REGION */

#ifndef PUSH_D_CACHE_REGION
#  define PUSH_D_CACHE_REGION(addr, nwords) FLUSH_I_CACHE_REGION(addr, nwords)
#endif /* not PUSH_D_CACHE_REGION */
   contains the callee's name instead of the jump code.
 */

#define EXECUTE_CACHE_ENTRY_SIZE        2

/* Execute cache destructuring. */

/* Given a target location and the address of the first word of an
   execute cache entry, extract from the cache cell the number of
   arguments supplied by the caller and store it in target. */

/* For the 68K, addresses in bytes from start of cache:
   Before linking
     +0: TC_SYMBOL || symbol address
     +4: TC_FIXNUM || 0
     +6: number of supplied arguments, + 1
   After linking
     +0: jmp $xxx
     +2:  xxx
     +6: (unchanged)
*/

#define EXTRACT_EXECUTE_CACHE_ARITY(target, address) do			\
{									\
  (target) =								\
    ((long) (* ((unsigned short *) (((char *) (address)) + 6))));	\
} while (0)

#define EXTRACT_EXECUTE_CACHE_SYMBOL(target, address) do		\
{									\
  (target) = (* ((SCHEME_OBJECT *) (address)));				\
} while (0)

/* Extract the target address (not the code to get there) from an
   execute cache cell.
 */

#define EXTRACT_EXECUTE_CACHE_ADDRESS(target, address) do		\
{									\
  (target) = (* ((SCHEME_OBJECT *) (((char *) (address)) + 2)));	\
} while (0)

/* This is the inverse of EXTRACT_EXECUTE_CACHE_ADDRESS. */

#define STORE_EXECUTE_CACHE_ADDRESS(address, entry_address) do		\
{									\
  (* ((SCHEME_OBJECT *) (((char *) (address)) + 2))) =			\
    ((SCHEME_OBJECT) (entry_address));					\
} while (0)

/* This stores the fixed part of the instructions leaving the
   destination address and the number of arguments intact.  These are
   split apart so the GC can call EXTRACT/STORE...ADDRESS but it does
   NOT need to store the instructions back.  On some architectures the
   instructions may change due to GC and then STORE_EXECUTE_CACHE_CODE
   should become a no-op and all of the work is done by
   STORE_EXECUTE_CACHE_ADDRESS instead.
 */

#define STORE_EXECUTE_CACHE_CODE(address) do				\
{									\
  (* ((unsigned short *) (address))) = ((unsigned short) 0x4ef9);	\
} while (0)

/* This overrides the definition in cmpint.c because the code below
   depends on knowing it, and is inserted before the definition in
   cmpint.c
 */

#define COMPILER_REGBLOCK_N_FIXED	16

#define COMPILER_REGBLOCK_N_HOOKS	80
#define COMPILER_HOOK_SIZE		2	/* absolute jsr instruction */

#define COMPILER_REGBLOCK_EXTRA_SIZE					\
#define COMPILER_REGBLOCK_N_HOOKS	40

#define A6_TRAMPOLINE_TO_INTERFACE_OFFSET				\
  ((COMPILER_REGBLOCK_N_FIXED + (2 * COMPILER_HOOK_SIZE)) *		\
   (sizeof (SCHEME_OBJECT)))

#define A6_CLOSURE_HOOK_OFFSET						\
  ((COMPILER_REGBLOCK_N_FIXED + (37 * COMPILER_HOOK_SIZE)) *		\
   (sizeof (SCHEME_OBJECT)))

#ifdef IN_CMPINT_C

#define ASM_RESET_HOOK mc68k_reset_hook

#ifdef CAST_FUNCTION_TO_INT_BUG

#define SETUP_REGISTER(hook) do						\
{									\
  extern unsigned long hook;						\
  (* ((unsigned short *) (a6_value + offset))) = 0x4ef9;		\
  (* ((unsigned long *)							\
      (((unsigned short *) (a6_value + offset)) + 1))) =		\
    ((unsigned long) (&hook));						\
  offset += (COMPILER_HOOK_SIZE * (sizeof (SCHEME_OBJECT)));		\
} while (0)

#else /* not CAST_FUNCTION_TO_INT_BUG */

#define SETUP_REGISTER(hook) do						\
{									\
  extern void EXFUN (hook, (void));					\
  (* ((unsigned short *) (a6_value + offset))) = 0x4ef9;		\
  (* ((unsigned long *)							\
      (((unsigned short *) (a6_value + offset)) + 1))) =		\
	((unsigned long) hook);						\
  offset += (COMPILER_HOOK_SIZE * (sizeof (SCHEME_OBJECT)));		\
} while (0)

#endif

void
DEFUN_VOID (mc68k_reset_hook)
{
  extern void EXFUN (interface_initialize, (void));

  unsigned char * a6_value = ((unsigned char *) (&Registers[0]));
  int offset = (COMPILER_REGBLOCK_N_FIXED * (sizeof (SCHEME_OBJECT)));

  /* These must match machines/bobcat/lapgen.scm */

  SETUP_REGISTER (asm_scheme_to_interface);		/* 0 */
  SETUP_REGISTER (asm_scheme_to_interface_jsr);		/* 1 */

  if (offset != A6_TRAMPOLINE_TO_INTERFACE_OFFSET)
  {
    fprintf (stderr,
	     "\nmc68k_reset_hook: A6_TRAMPOLINE_TO_INTERFACE_OFFSET\n");
    Microcode_Termination (TERM_EXIT);
  }

  SETUP_REGISTER (asm_trampoline_to_interface);		/* 2 */
  SETUP_REGISTER (asm_shortcircuit_apply);		/* 3 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_1);	/* 4 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_2);	/* 5 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_3);	/* 6 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_4);	/* 7 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_5);	/* 8 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_6);	/* 9 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_7);	/* 10 */
  SETUP_REGISTER (asm_shortcircuit_apply_size_8);	/* 11 */
  SETUP_REGISTER (asm_primitive_apply);			/* 12 */
  SETUP_REGISTER (asm_primitive_lexpr_apply);		/* 13 */
  SETUP_REGISTER (asm_error);				/* 14 */
  SETUP_REGISTER (asm_link);				/* 15 */
  SETUP_REGISTER (asm_interrupt_closure);		/* 16 */
  SETUP_REGISTER (asm_interrupt_dlink);			/* 17 */
  SETUP_REGISTER (asm_interrupt_procedure);		/* 18 */
  SETUP_REGISTER (asm_interrupt_continuation);		/* 19 */
  SETUP_REGISTER (asm_assignment_trap);			/* 20 */
  SETUP_REGISTER (asm_reference_trap);			/* 21 */
  SETUP_REGISTER (asm_safe_reference_trap);		/* 22 */
  SETUP_REGISTER (asm_generic_add);			/* 23 */
  SETUP_REGISTER (asm_generic_subtract);		/* 24 */
  SETUP_REGISTER (asm_generic_multiply);		/* 25 */
  SETUP_REGISTER (asm_generic_divide);			/* 26 */
  SETUP_REGISTER (asm_generic_equal);			/* 27 */
  SETUP_REGISTER (asm_generic_less);			/* 28 */
  SETUP_REGISTER (asm_generic_greater);			/* 29 */
  SETUP_REGISTER (asm_generic_increment);		/* 30 */
  SETUP_REGISTER (asm_generic_decrement);		/* 31 */
  SETUP_REGISTER (asm_generic_zero);			/* 32 */
  SETUP_REGISTER (asm_generic_positive);		/* 33 */
  SETUP_REGISTER (asm_generic_negative);		/* 34 */
  SETUP_REGISTER (asm_primitive_error);			/* 35 */
  SETUP_REGISTER (asm_allocate_closure);		/* 36 */

  if (offset != A6_CLOSURE_HOOK_OFFSET)
  {
    fprintf (stderr, "\nmc68k_reset_hook: A6_CLOSURE_HOOK_OFFSET\n");
    Microcode_Termination (TERM_EXIT);
  }
  else
  {							/* 37 */
    unsigned short *pc;

    pc = ((unsigned short *) (a6_value + offset));
    *pc++ = 0x2057;		/* MOVEA.L	(%sp),%a0 */
    *pc++ = 0x2050;		/* MOVEA.L	(%a0),%a0 */
    *pc++ = 0x5497;		/* ADDQ.L	&2,(%sp) */
    *pc++ = 0x4ed0;		/* JMP		(%a0) */

    offset += (COMPILER_HOOK_SIZE * (sizeof (SCHEME_OBJECT)));
  }

  SETUP_REGISTER (asm_generic_quotient);		/* 38 */
  SETUP_REGISTER (asm_generic_remainder);		/* 39 */
#if 0
  interface_initialize ();
  return;
}

#define CLOSURE_ENTRY_WORDS						\
  (COMPILED_CLOSURE_ENTRY_SIZE / (sizeof (SCHEME_OBJECT)))

static long closure_chunk = (1024 * CLOSURE_ENTRY_WORDS);
static long last_chunk_size;

#define CLOSURE_CHUNK (1024 * CLOSURE_ENTRY_WORDS)
{
  long space;
DEFUN (allocate_closure,
       (nentries, size),
       long nentries AND long size)

  Microcode_Termination (TERM_COMPILER_DEATH);

#else /* (COMPILER_PROCESSOR_TYPE == COMPILER_MC68040_TYPE) */

  space = ((long) (Registers[REGBLOCK_CLOSURE_SPACE]));
  result = ((SCHEME_OBJECT *) (Registers[REGBLOCK_CLOSURE_FREE]));

  long compare, delta, space;
  SCHEME_OBJECT *result;

  compare = (size + ((nentries * CLOSURE_ENTRY_WORDS) - 1));
  delta = (CLOSURE_ENTRY_WORDS
	   * ((nentries + 1)
	      + ((size + 1) / CLOSURE_ENTRY_WORDS)));

  if (size > space)
  {
    SCHEME_OBJECT *start, *ptr, *eptr;
  if (compare < space)
    /* Clear remaining words from last chunk so that the heap can be scanned
    SCHEME_OBJECT *start, *ptr, *end;
       Do not clear if there was no last chunk (ie. CLOSURE_FREE was NULL).
    if ((compare <= (CLOSURE_CHUNK - 3)) && (!GC_Check (CLOSURE_CHUNK)))
    }
    else
      end = (start + CLOSURE_CHUNK);
      if (GC_Check (size))
      {
	if ((Heap_Top - Free) < size)
      if (GC_Check (compare + 3))
	  /* No way to back out -- die. */
	if ((Heap_Top - Free) < (compare + 3))
	  fprintf (stderr, "\nC_allocate_closure (%d): No space.\n", size);
	  Microcode_Termination (TERM_NO_SPACE);
	  fprintf (stderr, "\nC_allocate_closure (%d, %d): No space.\n",
		   nentries, size);
	Request_GC (0);
      }
      else if (size <= closure_chunk)
	start = Free;
	end = (start + (compare + 3));
      {
	Request_GC (0);
    result = start;
    space = (eptr - start);
    Free = end;
    result = (start + 3);
    space = (end - result);

    for (ptr = result; ptr < end; ptr += CLOSURE_ENTRY_WORDS)
      wptr = ((unsigned short *) ptr);
      *wptr++ = 0x4eae;			/* JSR n(a6) */
      *wptr = A6_CLOSURE_HOOK_OFFSET;	/* n */
    }

      *wptr++ = A6_CLOSURE_HOOK_OFFSET;	/* n */
  }

    PUSH_D_CACHE_REGION (result, space);
  Registers[REGBLOCK_CLOSURE_SPACE] = ((SCHEME_OBJECT) (space - size));
  return (result);
  Registers[REGBLOCK_CLOSURE_FREE] = ((SCHEME_OBJECT) (result - delta));
  Registers[REGBLOCK_CLOSURE_SPACE] = ((SCHEME_OBJECT) (space - delta));
}

#endif /* IN_CMPINT_C */

/* On the 68K, here's a  picture of a trampoline (offset in bytes from
   entry point)
     -12: MANIFEST vector header
     - 8: NON_MARKED header
     - 4: Format word
     - 2: 0xFFF4 (GC Offset to start of block from .+2)
       0: mov.w	#index,%d0
       4: jsr	A6_TRAMPOLINE_TO_INTERFACE_OFFSET(a6)
       8: trampoline dependent storage (0 - 3 longwords)

   TRAMPOLINE_ENTRY_SIZE is the size in longwords of the machine
   dependent portion of a trampoline, including the GC and format
   headers.  The code in the trampoline must store an index (used to
   determine which C SCHEME_UTILITY procedure to invoke) in a
   register, jump to "scheme_to_interface" and leave the address of
   the storage following the code in a standard location.

   TRAMPOLINE_BLOCK_TO_ENTRY is the number of longwords from the start
   of a trampoline to the first instruction.  Note that this aligns
   the first instruction to a longword boundary.

   WARNING: make_trampoline in cmpint.c will need to be changed if
   machine instructions must be aligned more strictly than just on
   longword boundaries (e.g. quad word alignment for instructions).

   TRAMPOLINE_STORAGE takes the address of the first instruction in a
   trampoline (not the start of the trampoline block) and returns the
   address of the first storage word in the trampoline.

   STORE_TRAMPOLINE_ENTRY gets the address of the first instruction in
   the trampoline and stores the instructions.  It also receives the
   index of the C SCHEME_UTILITY to be invoked.
*/

#define TRAMPOLINE_ENTRY_SIZE		3
#define TRAMPOLINE_BLOCK_TO_ENTRY	3
#define TRAMPOLINE_STORAGE(tramp)					\
((((SCHEME_OBJECT *) tramp) - TRAMPOLINE_BLOCK_TO_ENTRY) +		\
 (2 + TRAMPOLINE_ENTRY_SIZE)) 

#define STORE_TRAMPOLINE_ENTRY(entry_address, index) do			\
{									\
  unsigned short *start_address, *PC;					\
  /* D0 will get the index.  JSR will be used to call the assembly	\
     language to C SCHEME_UTILITY handler:				\
	mov.w	#index,%d0						\
	jsr	n(a6)							\
  */									\
  start_address = ((unsigned short *) (entry_address));			\
  PC = start_address;							\
  *PC++ = ((unsigned short) 0x303C);	/* mov.w #???,%d0 */		\
  *PC++ = ((unsigned short) index); 	/* ??? */			\
  *PC++ = ((unsigned short) 0x4EAE);	/* jsr n(a6) */			\
  *PC++ = ((unsigned short) A6_TRAMPOLINE_TO_INTERFACE_OFFSET);		\
  PUSH_D_CACHE_REGION (start_address, 2);				\
} while (0)

/* Derived parameters and macros.
   These macros expect the above definitions to be meaningful.
   If they are not, the macros below may have to be changed as well.
 */

#define COMPILED_ENTRY_OFFSET_WORD(entry)                               \
  (((format_word *) (entry))[-1])
#define COMPILED_ENTRY_FORMAT_WORD(entry)                               \
  (((format_word *) (entry))[-2])

/* The next one assumes 2's complement integers....*/
#define CLEAR_LOW_BIT(word)                     ((word) & ((unsigned long) -2))
#define OFFSET_WORD_CONTINUATION_P(word)        (((word) & 1) != 0)

#if (PC_ZERO_BITS == 0)
/* Instructions aligned on byte boundaries */
#define BYTE_OFFSET_TO_OFFSET_WORD(offset)      ((offset) << 1)
#define OFFSET_WORD_TO_BYTE_OFFSET(offset_word)                         \
  ((CLEAR_LOW_BIT(offset_word)) >> 1)
#endif

#if (PC_ZERO_BITS == 1)
/* Instructions aligned on word (16 bit) boundaries */
#define BYTE_OFFSET_TO_OFFSET_WORD(offset)      (offset)
#define OFFSET_WORD_TO_BYTE_OFFSET(offset_word)                         \
  (CLEAR_LOW_BIT(offset_word))
#endif

#if (PC_ZERO_BITS >= 2)
/* Should be OK for =2, but bets are off for >2 because of problems
   mentioned earlier!
*/
#define SHIFT_AMOUNT                            (PC_ZERO_BITS - 1)
#define BYTE_OFFSET_TO_OFFSET_WORD(offset)      ((offset) >> (SHIFT_AMOUNT))
#define OFFSET_WORD_TO_BYTE_OFFSET(offset_word)                         \
  ((CLEAR_LOW_BIT(offset_word)) << (SHIFT_AMOUNT))
#endif

#define MAKE_OFFSET_WORD(entry, block, continue)                        \
  ((BYTE_OFFSET_TO_OFFSET_WORD(((char *) (entry)) -                     \
                               ((char *) (block)))) |                   \
   ((continue) ? 1 : 0))

#if (EXECUTE_CACHE_ENTRY_SIZE == 2)
#define EXECUTE_CACHE_COUNT_TO_ENTRIES(count)                           \
  ((count) >> 1)
#define EXECUTE_CACHE_ENTRIES_TO_COUNT(entries)				\
  ((entries) << 1)
#endif

#if (EXECUTE_CACHE_ENTRY_SIZE == 4)
#define EXECUTE_CACHE_COUNT_TO_ENTRIES(count)                           \
  ((count) >> 2)
#define EXECUTE_CACHE_ENTRIES_TO_COUNT(entries)				\
  ((entries) << 2)
#endif

#if (!defined(EXECUTE_CACHE_COUNT_TO_ENTRIES))
#define EXECUTE_CACHE_COUNT_TO_ENTRIES(count)                           \
  ((count) / EXECUTE_CACHE_ENTRY_SIZE)
#define EXECUTE_CACHE_ENTRIES_TO_COUNT(entries)				\
  ((entries) * EXECUTE_CACHE_ENTRY_SIZE)
#endif

/* The first entry in a cc block is preceeded by 2 headers (block and nmv),
   a format word and a gc offset word.   See the early part of the
   TRAMPOLINE picture, above.
 */

#define CC_BLOCK_FIRST_ENTRY_OFFSET                                     \
  (2 * ((sizeof(SCHEME_OBJECT)) + (sizeof(format_word))))

/* Format words */

#define FORMAT_BYTE_EXPR                0xFF
#define FORMAT_BYTE_COMPLR              0xFE
#define FORMAT_BYTE_CMPINT              0xFD
#define FORMAT_BYTE_DLINK               0xFC
#define FORMAT_BYTE_RETURN              0xFB

#define FORMAT_WORD_EXPR        (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_EXPR))
#define FORMAT_WORD_CMPINT      (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_CMPINT))
#define FORMAT_WORD_RETURN      (MAKE_FORMAT_WORD(0xFF, FORMAT_BYTE_RETURN))

/* This assumes that a format word is at least 16 bits,
   and the low order field is always 8 bits.
 */

#define MAKE_FORMAT_WORD(field1, field2)                                \
  (((field1) << 8) | ((field2) & 0xff))

#define SIGN_EXTEND_FIELD(field, size)                                  \
  (((field) & ((1 << (size)) - 1)) |                                    \
   ((((field) & (1 << ((size) - 1))) == 0) ? 0 :                        \
    ((-1) << (size))))

#define FORMAT_WORD_LOW_BYTE(word)                                      \
  (SIGN_EXTEND_FIELD((((unsigned long) (word)) & 0xff), 8))

#define FORMAT_WORD_HIGH_BYTE(word)					\
  (SIGN_EXTEND_FIELD((((unsigned long) (word)) >> 8),			\
		     (((sizeof (format_word)) * CHAR_BIT) - 8)))

#define COMPILED_ENTRY_FORMAT_HIGH(addr)                                \
  (FORMAT_WORD_HIGH_BYTE(COMPILED_ENTRY_FORMAT_WORD(addr)))

#define COMPILED_ENTRY_FORMAT_LOW(addr)                                 \
  (FORMAT_WORD_LOW_BYTE(COMPILED_ENTRY_FORMAT_WORD(addr)))

#define FORMAT_BYTE_FRAMEMAX            0x7f

#define COMPILED_ENTRY_MAXIMUM_ARITY    COMPILED_ENTRY_FORMAT_LOW
#define COMPILED_ENTRY_MINIMUM_ARITY    COMPILED_ENTRY_FORMAT_HIGH

#endif /* CMPINT2_H_INCLUDED */
