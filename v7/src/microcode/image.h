/* -*-C-*-

Copyright (c) 1987, 1988 Massachusetts Institute of Technology

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

/* $Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/Attic/image.h,v 9.22 1988/08/15 20:49:39 cph Rel $ */

extern Image_Fast_Transpose();     /* REAL *Array; long nrows; OPTIMIZATION for square images */
extern Image_Transpose();     /* REAL *Array, *New_Array; long nrows, ncols; */
extern Image_Rotate_90clw();     /* REAL *Array, *Rotated_Array; long nrows, ncols; */
extern Image_Rotate_90cclw();     /* REAL *Array, *Rotated_Array; long nrows, ncols; */
extern Image_Mirror();            /* REAL *Array; long nrows, ncols; */

extern Image_Mirror_Upside_Down();     /* Array,nrows,ncols,Temp_Array;
					  REAL *Array,*Temp_Row; long nrows, ncols; */
extern Image_Read_From_CTSCAN_File();  /* FILE *fp; REAL *Array; long nrows, ncols */

extern Image_Rotate_90clw_Mirror();     /* REAL *Array, *Rotated_Array; long nrows, ncols; */

extern Image_Draw_Magnify_N_Times_With_Offset_Scale();
extern Image_Draw_Magnify_N_Times_With_Offset_Scale_Only();
