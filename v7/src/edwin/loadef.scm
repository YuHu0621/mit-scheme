;;; -*-Scheme-*-
;;;
;;; $Id: loadef.scm,v 1.36 1999/01/14 21:37:46 cph Exp $
;;;
;;; Copyright (c) 1986, 1989-1999 Massachusetts Institute of Technology
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2 of the
;;; License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;;; Autoload Definitions

(declare (usual-integrations))

;;;; Major Mode Libraries
(define-library 'TECHINFO-MODE
  '("techinfo" (EDWIN)))

(define-autoload-major-mode 'techinfo 'fundamental "TechInfo" 'TECHINFO-MODE
  "Mode for accessing the TechInfo database.")

(define-autoload-command 'techinfo 'TECHINFO-MODE
  "Enter TechInfo mode.")

(define-library 'TELNET-MODE
  '("telnet" (EDWIN)))

(define-autoload-major-mode 'telnet 'comint "Telnet" 'TELNET-MODE
  "Major mode for interacting with the Telnet program.")

(define-autoload-command 'telnet 'TELNET-MODE
  "Telnet to remote host.")

(define-variable telnet-mode-hook
  "An event distributor that is invoked when entering Telnet mode."
  (make-event-distributor))

(define-library 'MIDAS-MODE
  '("midas" (EDWIN)))

(define-autoload-major-mode 'midas 'fundamental "Midas" 'MIDAS-MODE
  "Major mode for editing assembly code.")

(define-autoload-command 'midas-mode 'MIDAS-MODE
  "Enter Midas mode.")

(define-variable midas-mode-hook
  "An event distributor that is invoked when entering Midas mode."
  (make-event-distributor))

(define-library 'PASCAL-MODE
  '("pasmod" (EDWIN)))

(define-autoload-major-mode 'pascal 'fundamental "Pascal" 'PASCAL-MODE
  "Major mode specialized for editing Pascal code.")

(define-autoload-command 'pascal-mode 'PASCAL-MODE
  "Enter Pascal mode.")

(define-variable pascal-mode-hook
  "An event distributor that is invoked when entering Pascal mode."
  (make-event-distributor))

(define-variable pascal-shift-increment
  "Indentation increment for Pascal Shift commands."
  2)

(define-variable pascal-indentation-keywords
  "These keywords cause the lines below them to be indented to the right.
This must be a regular expression, or #F to disable the option."
  false)

(define-library 'TEXINFO-MODE
  '("tximod" (EDWIN)))

(define-autoload-major-mode 'texinfo 'text "Texinfo" 'TEXINFO-MODE
  "Major mode for editing Texinfo files.

  These are files that are used as input for TeX to make printed manuals
and also to be turned into Info files by \\[texinfo-format-buffer] or
`makeinfo'.  These files must be written in a very restricted and
modified version of TeX input format.

  Editing commands are like text-mode except that the syntax table is
set up so expression commands skip Texinfo bracket groups.

  In addition, Texinfo mode provides commands that insert various
frequently used @-sign commands into the buffer.  You can use these
commands to save keystrokes.")

(define-autoload-command 'texinfo-mode 'TEXINFO-MODE
  "Make the current mode be Texinfo mode.")

(define-variable texinfo-mode-hook
  "An event distributor that is invoked when entering Texinfo mode."
  (make-event-distributor))

;;;; Other Libraries

(define-library 'manual
  '("manual" (EDWIN)))

(define-autoload-command 'manual-entry 'MANUAL
  "Display UNIX man page.")

(define-autoload-command 'clean-manual-entry 'MANUAL
  "Clean the unix manual entry in the current buffer.
The current buffer should contain a formatted manual entry.")

(define-variable manual-entry-reuse-buffer?
  "If true, MANUAL-ENTRY uses buffer *Manual-Entry* for all entries.
Otherwise, a new buffer is created for each topic."
  false
  boolean?)

(define-variable manual-command
  "A string containing the manual page formatting command.  
Section (if any) and topic strings are appended (with space separators)
and the resulting string is provided to a shell running in a subprocess."
  false
  string-or-false?)

(define-library 'print
  '("print" (EDWIN)))

(define-variable lpr-procedure
  "Procedure that spools some text to the printer, or #F for the default.
Procedure is called with four arguments: a region to be printed, a flag
indicating that the text should be printed with page headers, a title string
to appear in the header lines and on the title page, and the buffer in which
the text was originally stored (for editor variable references).  If this
variable's value is #F, the text is printed using LPR-COMMAND."
  false
  (lambda (object) (or (not object) (procedure? object))))

(define-variable lpr-command
  "Shell command for printing a file"
  "lpr"
  string?)

(define-variable lpr-switches
  "List of strings to pass as extra switch args to lpr when it is invoked."
  '()
  list-of-strings?)

(define lpr-prompt-for-name?
  ;; If true, lpr commands prompt for a name to appear on the title page.
  false)

(define lpr-print-not-special?
  ;; If true, the print-* commands are just like the lpr-* commands.
  false)

(define-autoload-command 'lpr-buffer 'PRINT
  "Print buffer contents with Unix command `lpr'.")

(define-autoload-command 'print-buffer 'PRINT
  "Print buffer contents as with Unix command `lpr -p'.")

(define-autoload-command 'lpr-region 'PRINT
  "Print region contents as with Unix command `lpr'.")

(define-autoload-command 'print-region 'PRINT
  "Print region contents as with Unix command `lpr -p'.")

(define-library 'SORT
  '("sort" (EDWIN)))

(define-autoload-command 'sort-lines 'SORT
  "Sort lines by their text.")

(define-autoload-command 'sort-pages 'SORT
  "Sort pages by their text.")

(define-autoload-command 'sort-paragraphs 'SORT
  "Sort paragraphs by their text.")

(define-autoload-command 'sort-fields 'SORT
  "Sort lines by the text of a field.")

(define-autoload-command 'sort-numeric-fields 'SORT
  "Sort lines by the numeric value of a field.")

(define-autoload-command 'sort-columns 'SORT
  "Sort lines by the text in a range of columns.")

(define-library 'STEPPER
  '("eystep" (EDWIN STEPPER)))

(define-autoload-command 'step-expression 'STEPPER
  "Single-step an expression.")

(define-autoload-command 'step-last-sexp 'STEPPER
  "Single-step the expression preceding point.")

(define-autoload-command 'step-defun 'STEPPER
  "Single-step the definition that the point is in or before.")

(define-library 'NEWS-READER
  '("nntp" (EDWIN NNTP))
  '("snr" (EDWIN NEWS-READER)))

(define-autoload-command 'rnews 'NEWS-READER
  "Start a News reader.
Normally uses the server specified by the variable news-server,
but with a prefix arg prompts for the server name.
Only one News reader may be open per server; if a previous News reader
is open the that server, its buffer is selected.")

(define-library 'VERILOG-MODE
  '("verilog" (EDWIN VERILOG)))

(define-autoload-major-mode 'verilog 'fundamental "Verilog" 'VERILOG-MODE
  "Major mode specialized for editing Verilog code.")

(define-autoload-command 'verilog-mode 'VERILOG-MODE
  "Enter Verilog mode.")

(define-variable verilog-mode-hook
  "An event distributor that is invoked when entering Verilog mode."
  (make-event-distributor))

(define-variable verilog-continued-statement-offset
  "Extra indent for lines not starting new statements."
  2
  exact-nonnegative-integer?)

(define-variable verilog-continued-header-offset
  "Extra indent for continuation lines of structure headers."
  4
  exact-nonnegative-integer?)

(define-library 'VHDL-MODE
  '("vhdl" (EDWIN VHDL)))

(define-autoload-major-mode 'vhdl 'fundamental "VHDL" 'VHDL-MODE
  "Major mode specialized for editing VHDL code.")

(define-autoload-command 'vhdl-mode 'VHDL-MODE
  "Enter VHDL mode.")

(define-variable vhdl-mode-hook
  "An event distributor that is invoked when entering VHDL mode."
  (make-event-distributor))

(define-variable vhdl-continued-header-offset
  "Extra indent for continuation lines of structure headers."
  4
  exact-nonnegative-integer?)

(define-variable vhdl-continued-statement-offset
  "Extra indent for lines not starting new statements."
  2
  exact-nonnegative-integer?)

;;;; Webster

(define-library 'WEBSTER
  '("webster" (EDWIN)))

(define-autoload-major-mode 'webster 'read-only "Webster" 'WEBSTER
  "Major mode for interacting with webster server.
Commands:

\\[webster-define]	look up the definition of a word
\\[webster-spellings]	look up possible correct spellings for a word
\\[webster-define]	look up possible endings for a word
\\[webster-quit]	close connection to the Webster server

Use webster-mode-hook for customization.")

(define-autoload-command 'webster 'WEBSTER
  "Look up a word in Webster's dictionary.")

(define-autoload-command 'webster-define 'WEBSTER
  "Look up a word in Webster's dictionary.")

(define-autoload-command 'webster-endings 'WEBSTER
  "Look up possible endings for a word in Webster's dictionary.")

(define-autoload-command 'webster-spellings 'WEBSTER
  "Look up possible correct spellings for a word in Webster's dictionary.")

(define-variable webster-server
  "Host name of a webster server, specified as a string."
  #f
  string-or-false?)

(define-variable webster-port
  "TCP port of webster server on webster-server, specified as an integer.
This is usually 103 or 2627."
  103
  exact-nonnegative-integer?)

(define-variable webster-mode-hook
  "Hook to be run by webster-mode, after everything else."
  (make-event-distributor))

(define-variable webster-buffer-name
  "The name to use for webster interaction buffer."
  "*webster*"
  string?)

;;;; Password Editor

(define-library 'PASSWORD-EDIT
  '("pwedit" (EDWIN PASSWORD-EDIT))
  '("pwparse" (EDWIN PASSWORD-EDIT)))

(define-autoload-command 'view-password-file 'PASSWORD-EDIT
  "Read in a password file and show it in password-view mode.")

(define-autoload-major-mode 'password-view 'read-only "Password-View"
  'PASSWORD-EDIT
  "Major mode specialized for viewing password files.")

(define-autoload-command toggle-pw-form 'PASSWORD-EDIT
  "Toggle the body of the password form under point.")

(define-autoload-command mouse-toggle-pw-form 'PASSWORD-EDIT
  "Toggle the body of the password form under mouse.")

;;;; DOS-specific commands

(if (memq microcode-id/operating-system '(DOS))
    (begin
      (define-library 'DOSCOM
	'("doscom" (EDWIN DOSJOB)))
      (define-autoload-command 'shell-command 'DOSCOM
	"Execute string COMMAND in inferior shell; display output, if any.")
      (define-autoload-command 'shell-command-on-region 'DOSCOM
	"Execute string COMMAND in inferior shell with region as input.")
      (define-autoload-procedure 'shell-command '(EDWIN DOSJOB)
	'DOSCOM)

      (define-library 'DOSSHELL
	'("dosshell" (EDWIN DOSJOB)))
      (define-autoload-major-mode 'pseudo-shell 'fundamental "Pseudo Shell"
	'DOSSHELL
	"Major mode for executing DOS commands.")
      (define-autoload-command 'shell 'DOSSHELL
	"Run an inferior pseudo shell, with I/O through buffer *shell*.")))