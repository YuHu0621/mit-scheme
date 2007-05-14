#| -*-Scheme-*-

$Id: utilities.scm,v 1.1 2007/05/14 16:50:50 cph Exp $

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007 Massachusetts Institute of Technology

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

;;;; Configuration and setup utilities

(declare (usual-integrations))

(load-option (quote CREF))

(define (generate-c-bundles bundles)
  (for-each
   (lambda (bundle)
     (with-notification (lambda (port)
			  (write-string "Generating bundle rule for " port)
			  (write-string bundle port))
       (lambda ()
	 (let ((names (bundle-files bundle)))
	   (call-with-output-file (string-append bundle "/Makefile-bundle")
	     (lambda (port)
	       (newline port)
	       (let ((init-root (string-append bundle "-init")))
		 (write-rule port "liarc-bundle" (string-append bundle ".so"))
		 (newline port)
		 (write-rule port ".PHONY" "liarc-bundle")
		 (newline port)
		 (write-rule port
			     (string-append bundle ".so")
			     (string-append init-root ".o")
			     (files+suffix names ".o"))
		 (write-command port
				"@$(top_builddir)/microcode/liarc-ld"
				"$@"
				"$^")
		 (newline port)
		 (write-rule port
			     (string-append init-root ".c")
			     (files+suffix names ".c"))
		 (write-command port
				"$(top_srcdir)/etc/c-bundle.sh"
				"library"
				init-root
				"$^")
		 )))))))
   (map write-to-string bundles)))

(define (bundle-files bundle)
  (let ((pkg-name (if (string=? bundle "star-parser") "parser" bundle)))
    (cons (string-append pkg-name "-unx")
	  (sort (let ((names
		       (map ->namestring
			    (cref/package-files
			     (string-append bundle
					    "/"
					    pkg-name
					    ".pkg")
			     'unix))))
		  (cond ((or (string=? bundle "6001")
			     (string=? bundle "cref")
			     (string=? bundle "runtime")
			     (string=? bundle "sf"))
			 (cons "make" names))
			((string=? bundle "compiler")
			 (cons* "machines/C/make"
				"base/make"
				names))
			((string=? bundle "edwin")
			 (cons* "edwin"
				"rename"
				names))
			(else names)))
		string<?))))

(define (write-header output)
  (write-string "# This file automatically generated at " output)
  (write-string (universal-time->local-iso8601-string (get-universal-time))
		output)
  (write-string "." output)
  (newline output)
  (newline output))

(define (write-rule port lhs . rhs)
  (write-string lhs port)
  (write-string ":" port)
  (write-items (flatten-items rhs) port)
  (newline port))

(define (write-macro port lhs . rhs)
  (write-string lhs port)
  (write-string " =" port)
  (write-items (flatten-items rhs) port)
  (newline port))

(define (write-command port program . args)
  (write-char #\tab port)
  (write-string program port)
  (write-items (flatten-items args) port)
  (newline port))

(define (flatten-items items)
  (append-map (lambda (item)
		(if (list? item)
		    (flatten-items item)
		    (list item)))
	      items))

(define (write-items items port)
  (for-each (lambda (item)
	      (write-string " " port)
	      (write-item item port))
	    items))

(define (write-item item port)
  (if (>= (+ (output-port/column port)
	     (string-length item))
	  78)
      (begin
	(write-char #\\ port)
	(newline port)
	(write-char #\tab port)
	(write-string "  " port)))
  (write-string item port))

(define (files+suffix files suffix)
  (map (lambda (file)
	 (string-append file suffix))
       files))