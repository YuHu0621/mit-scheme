/* -*-C-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/flonum.c,v 9.30 1989/09/25 16:51:17 cph Exp $

Copyright (c) 1987, 1988, 1989 Massachusetts Institute of Technology

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

/* Floating Point Arithmetic */

#include "scheme.h"
#include "prims.h"
#include "zones.h"

double
arg_flonum (arg_number)
     int arg_number;
{
  SCHEME_OBJECT argument = (ARG_REF (arg_number));
  if (! (FLONUM_P (argument)))
    error_wrong_type_arg (arg_number);
  return (FLONUM_TO_DOUBLE (argument));
}

#define FLONUM_RESULT(x) PRIMITIVE_RETURN (double_to_flonum (x))
#define BOOLEAN_RESULT(x) PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT (x))

#define FLONUM_SIZE ((BYTES_TO_WORDS (sizeof (double))) + 1)

SCHEME_OBJECT
double_to_flonum (value)
     double value;
{
  ALIGN_FLOAT (Free);
  Primitive_GC_If_Needed (FLONUM_SIZE);
  (*Free++) = (MAKE_OBJECT (TC_MANIFEST_NM_VECTOR, (FLONUM_SIZE - 1)));
  (*((double *) Free)++) = value;
  return (MAKE_POINTER_OBJECT (TC_BIG_FLONUM, (Free - FLONUM_SIZE)));
}

#define FLONUM_BINARY_OPERATION(operator)				\
{									\
  PRIMITIVE_HEADER (2);							\
  Set_Time_Zone (Zone_Math);						\
  FLONUM_RESULT ((arg_flonum (1)) operator (arg_flonum (2)));		\
}

DEFINE_PRIMITIVE ("FLONUM-ADD", Prim_flonum_add, 2, 2, 0)
     FLONUM_BINARY_OPERATION (+)
DEFINE_PRIMITIVE ("FLONUM-SUBTRACT", Prim_flonum_subtract, 2, 2, 0)
     FLONUM_BINARY_OPERATION (-)
DEFINE_PRIMITIVE ("FLONUM-MULTIPLY", Prim_flonum_multiply, 2, 2, 0)
     FLONUM_BINARY_OPERATION (*)

DEFINE_PRIMITIVE ("FLONUM-DIVIDE", Prim_flonum_divide, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  Set_Time_Zone (Zone_Math);
  {
    fast double denominator = (arg_flonum (2));
    if (denominator == 0)
      error_bad_range_arg (2);
    FLONUM_RESULT ((arg_flonum (1)) / denominator);
  }
}

DEFINE_PRIMITIVE ("FLONUM-NEGATE", Prim_flonum_negate, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  Set_Time_Zone (Zone_Math);
  FLONUM_RESULT (- (arg_flonum (1)));
}

DEFINE_PRIMITIVE ("FLONUM-ABS", Prim_flonum_abs, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  Set_Time_Zone (Zone_Math);
  {
    fast double x = (arg_flonum (1));
    FLONUM_RESULT ((x < 0) ? (-x) : x);
  }
}

#define FLONUM_BINARY_PREDICATE(operator)				\
{									\
  PRIMITIVE_HEADER (2);							\
  Set_Time_Zone (Zone_Math);						\
  BOOLEAN_RESULT ((arg_flonum (1)) operator (arg_flonum (2)));		\
}

DEFINE_PRIMITIVE ("FLONUM-EQUAL?", Prim_flonum_equal_p, 2, 2, 0)
     FLONUM_BINARY_PREDICATE (==)
DEFINE_PRIMITIVE ("FLONUM-LESS?", Prim_flonum_less_p, 2, 2, 0)
     FLONUM_BINARY_PREDICATE (<)
DEFINE_PRIMITIVE ("FLONUM-GREATER?", Prim_flonum_greater_p, 2, 2, 0)
     FLONUM_BINARY_PREDICATE (>)

#define FLONUM_UNARY_PREDICATE(operator)				\
{									\
  PRIMITIVE_HEADER (1);							\
  Set_Time_Zone (Zone_Math);						\
  BOOLEAN_RESULT ((arg_flonum (1)) operator 0);				\
}

DEFINE_PRIMITIVE ("FLONUM-ZERO?", Prim_flonum_zero_p, 1, 1, 0)
     FLONUM_UNARY_PREDICATE (==)
DEFINE_PRIMITIVE ("FLONUM-POSITIVE?", Prim_flonum_positive_p, 1, 1, 0)
     FLONUM_UNARY_PREDICATE (>)
DEFINE_PRIMITIVE ("FLONUM-NEGATIVE?", Prim_flonum_negative_p, 1, 1, 0)
     FLONUM_UNARY_PREDICATE (<)

#define SIMPLE_TRANSCENDENTAL_FUNCTION(function)			\
{									\
  extern double function ();						\
  PRIMITIVE_HEADER (1);							\
  Set_Time_Zone (Zone_Math);						\
  FLONUM_RESULT (function (arg_flonum (1)));				\
}

#define RESTRICTED_TRANSCENDENTAL_FUNCTION(function, restriction)	\
{									\
  extern double function ();						\
  PRIMITIVE_HEADER (1);							\
  Set_Time_Zone (Zone_Math);						\
  {									\
    fast double x = (arg_flonum (1));					\
    if (! (restriction))						\
      error_bad_range_arg (1);						\
    FLONUM_RESULT (function (x));					\
  }									\
}

DEFINE_PRIMITIVE ("FLONUM-EXP", Prim_flonum_exp, 1, 1, 0)
     SIMPLE_TRANSCENDENTAL_FUNCTION (exp)
DEFINE_PRIMITIVE ("FLONUM-LOG", Prim_flonum_log, 1, 1, 0)
     RESTRICTED_TRANSCENDENTAL_FUNCTION (log, (x > 0))
DEFINE_PRIMITIVE ("FLONUM-SIN", Prim_flonum_sin, 1, 1, 0)
     SIMPLE_TRANSCENDENTAL_FUNCTION (sin)
DEFINE_PRIMITIVE ("FLONUM-COS", Prim_flonum_cos, 1, 1, 0)
     SIMPLE_TRANSCENDENTAL_FUNCTION (cos)
DEFINE_PRIMITIVE ("FLONUM-TAN", Prim_flonum_tan, 1, 1, 0)
     SIMPLE_TRANSCENDENTAL_FUNCTION (tan)
DEFINE_PRIMITIVE ("FLONUM-ASIN", Prim_flonum_asin, 1, 1, 0)
     RESTRICTED_TRANSCENDENTAL_FUNCTION (asin, ((x >= -1) && (x <= 1)))
DEFINE_PRIMITIVE ("FLONUM-ACOS", Prim_flonum_acos, 1, 1, 0)
     RESTRICTED_TRANSCENDENTAL_FUNCTION (acos, ((x >= -1) && (x <= 1)))
DEFINE_PRIMITIVE ("FLONUM-ATAN", Prim_flonum_atan, 1, 1, 0)
     SIMPLE_TRANSCENDENTAL_FUNCTION (atan)

DEFINE_PRIMITIVE ("FLONUM-ATAN2", Prim_flonum_atan2, 2, 2, 0)
{
  extern double atan2 ();
  PRIMITIVE_HEADER (2);
  {
    fast double y = (arg_flonum (1));
    fast double x = (arg_flonum (2));
    if ((x == 0) && (y == 0))
      error_bad_range_arg (2);
    FLONUM_RESULT (atan2 (y, x));
  }
}

DEFINE_PRIMITIVE ("FLONUM-SQRT", Prim_flonum_sqrt, 1, 1, 0)
     RESTRICTED_TRANSCENDENTAL_FUNCTION (sqrt, (x >= 0))

DEFINE_PRIMITIVE ("FLONUM-EXPT", Prim_flonum_expt, 2, 2, 0)
{
  extern double pow ();
  PRIMITIVE_HEADER (2);
  {
    fast double x = (arg_flonum (1));
    fast double y = (arg_flonum (2));
    if (x <= 0)
      error_bad_range_arg (1);
    FLONUM_RESULT (pow (x, y));
  }
}

DEFINE_PRIMITIVE ("FLONUM?", Prim_flonum_p, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT (FLONUM_P (ARG_REF (1))));
}

DEFINE_PRIMITIVE ("FLONUM-INTEGER?", Prim_flonum_integer_p, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  CHECK_ARG (1, FLONUM_P);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT (flonum_integer_p (ARG_REF (1))));
}

#define FLONUM_CONVERSION(converter)					\
{									\
  PRIMITIVE_HEADER (1);							\
  Set_Time_Zone (Zone_Math);						\
  CHECK_ARG (1, FLONUM_P);						\
  PRIMITIVE_RETURN (converter (ARG_REF (1)));				\
}

DEFINE_PRIMITIVE ("FLONUM-FLOOR", Prim_flonum_floor, 1, 1, 0)
     FLONUM_CONVERSION (flonum_floor)
DEFINE_PRIMITIVE ("FLONUM-CEILING", Prim_flonum_ceiling, 1, 1, 0)
     FLONUM_CONVERSION (flonum_ceiling)
DEFINE_PRIMITIVE ("FLONUM-TRUNCATE", Prim_flonum_truncate, 1, 1, 0)
     FLONUM_CONVERSION (FLONUM_TRUNCATE)
DEFINE_PRIMITIVE ("FLONUM-ROUND", Prim_flonum_round, 1, 1, 0)
     FLONUM_CONVERSION (flonum_round)

DEFINE_PRIMITIVE ("FLONUM-TRUNCATE->EXACT", Prim_flonum_truncate_to_exact, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  Set_Time_Zone (Zone_Math);
  CHECK_ARG (1, FLONUM_P);
  PRIMITIVE_RETURN (FLONUM_TO_INTEGER (ARG_REF (1))); 
}

#define FLONUM_EXACT_CONVERSION(converter)				\
{									\
  PRIMITIVE_HEADER (1);							\
  Set_Time_Zone (Zone_Math);						\
  CHECK_ARG (1, FLONUM_P);						\
  PRIMITIVE_RETURN (FLONUM_TO_INTEGER (converter (ARG_REF (1))));	\
}
DEFINE_PRIMITIVE ("FLONUM-FLOOR->EXACT", Prim_flonum_floor_to_exact, 1, 1, 0)
     FLONUM_EXACT_CONVERSION (flonum_floor)
DEFINE_PRIMITIVE ("FLONUM-CEILING->EXACT", Prim_flonum_ceiling_to_exact, 1, 1, 0)
     FLONUM_EXACT_CONVERSION (flonum_ceiling)
DEFINE_PRIMITIVE ("FLONUM-ROUND->EXACT", Prim_flonum_round_to_exact, 1, 1, 0)
     FLONUM_EXACT_CONVERSION (flonum_round)

DEFINE_PRIMITIVE ("FLONUM-NORMALIZE", Prim_flonum_normalize, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  Set_Time_Zone (Zone_Math);
  CHECK_ARG (1, FLONUM_P);
  PRIMITIVE_RETURN (flonum_normalize (ARG_REF (1)));
}

DEFINE_PRIMITIVE ("FLONUM-DENORMALIZE", Prim_flonum_denormalize, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  Set_Time_Zone (Zone_Math);
  CHECK_ARG (1, FLONUM_P);
  CHECK_ARG (1, INTEGER_P);
  PRIMITIVE_RETURN (flonum_denormalize ((ARG_REF (1)), (ARG_REF (2))));
}
