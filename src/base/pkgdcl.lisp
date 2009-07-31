;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil -*-
;;;
;;; --- Package definition.
;;;

(in-package :common-lisp-user)

(defpackage :iolib.base
  (:use #:common-lisp :alexandria)
  (:shadow #:defun #:defmethod #:defmacro #:define-compiler-macro #:defconstant)
  (:export
   ;; Conditions
   #:bug #:iolib-bug
   #:subtype-error #:subtype-error-datum #:subtype-error-expected-supertype
   ;; Debugging
   #:*safety-checks*
   #:debug-only #:debug-only*
   #:production-only #:production-only*
   ;; Types
   #:function-designator
   #:character-designator
   #:string-designator
   ;; RETURN*
   #:return* #:lambda* #:defun #:defmethod
   #:defmacro #:define-compiler-macro
   ;; Definitions
   #:defconstant
   ;; DEFOBSOLETE
   #:defobsolete
   #:signal-obsolete
   #:deprecation-warning
   #:deprecation-warning-function-name
   #:deprecation-warning-type
   #:deprecation-warning-reason
   ;; Reader utils
   #:define-syntax
   #:enable-reader-macro #:enable-reader-macro*
   #:disable-reader-macro #:disable-reader-macro*
   #:define-literal-reader
   #:unknown-literal-syntax #:unknown-literal-syntax-name
   ;; SPLIT-SEQUENCE
   #:split-sequence #:split-sequence-if #:split-sequence-if-not
   ;; Misc
   #:function-name #:function-name-p
   #:check-bounds #:join #:join/ustring #:shrink-vector
   ;; Matching
   #:multiple-value-case #:flags-case
   ;; Time
   #:timeout-designator #:positive-timeout-designator
   #:decode-timeout #:normalize-timeout #:clamp-timeout
   ;; Uchars
   #:uchar-designator
   #:uchar-code-limit #:uchar
   #:code-uchar #:uchar-code
   #:char-to-uchar #:uchar-to-char
   #:name-uchar #:uchar-name
   #:digit-uchar
   #:ucharp #:unicode-uchar-p
   #:uchar= #:uchar/= #:uchar< #:uchar> #:uchar<= #:uchar>=
   #:uchar-equal #:uchar-not-equal #:uchar-lessp
   #:uchar-greaterp #:uchar-not-greaterp #:uchar-not-lessp
   #:alpha-uchar-p #:alphanumeric-uchar-p #:digit-uchar-p #:graphic-uchar-p
   #:upper-case-uchar-p #:lower-case-uchar-p #:both-case-uchar-p
   #:uchar-upcase #:uchar-downcase
   ;; Ustrings
   #:ustring-designator
   #:make-ustring #:string-to-ustring #:ustring #:ustringp
   #:ustring= #:ustring/= #:ustring< #:ustring> #:ustring<= #:ustring>=
   #:ustring-equal #:ustring-not-equal #:ustring-lessp
   #:ustring-greaterp #:ustring-not-greaterp #:ustring-not-lessp
   #:ustring-to-string #:ustring-to-string*
   #:ustring-upcase #:ustring-downcase #:ustring-capitalize
   #:nustring-upcase #:nustring-downcase #:nustring-capitalize
   #:ustring-trim #:ustring-left-trim #:ustring-right-trim
   ))

(flet ((gather-external-symbols (&rest packages)
         (let (symbols)
           (with-package-iterator (iterator packages :external)
             (loop (multiple-value-bind (morep symbol) (iterator)
                     (unless morep (return))
                     (pushnew (intern (string symbol) :iolib.base)
                              symbols))))
           symbols)))
  (export (gather-external-symbols :common-lisp :alexandria :iolib.base)
          :iolib.base))


;;;-------------------------------------------------------------------------
;;; GRAY stream symbols
;;;-------------------------------------------------------------------------

#+cmu
(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :gray-streams))

#+allegro
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (fboundp 'stream:stream-write-string)
    (require "streamc.fasl")))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *gray-stream-symbols*
    '(#:fundamental-stream #:fundamental-input-stream
      #:fundamental-output-stream #:fundamental-character-stream
      #:fundamental-binary-stream #:fundamental-character-input-stream
      #:fundamental-character-output-stream
      #:fundamental-binary-input-stream
      #:fundamental-binary-output-stream #:stream-read-char
      #:stream-unread-char #:stream-read-char-no-hang
      #:stream-peek-char #:stream-listen #:stream-read-line
      #:stream-clear-input #:stream-write-char #:stream-line-column
      #:stream-start-line-p #:stream-write-string #:stream-terpri
      #:stream-fresh-line #:stream-finish-output #:stream-force-output
      #:stream-clear-output #:stream-advance-to-column
      #:stream-read-byte #:stream-write-byte))

  (defparameter *gray-stream-package*
    #+allegro :excl
    #+(or cmu scl) :ext
    #+(or clisp ecl) :gray
    #+(or ccl openmcl) :ccl
    #+lispworks :stream
    #+sbcl :sb-gray
    #-(or allegro cmu scl clisp ecl ccl openmcl lispworks sbcl)
    (error "Your CL implementation isn't supported.")))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (import (mapcar #'(lambda (s) (intern (string s) *gray-stream-package*))
                  *gray-stream-symbols*)
          :iolib.base)
  (export (mapcar (lambda (s) (intern (string s) :iolib.base))
                  (list* '#:trivial-gray-stream-mixin
                         '#:stream-read-sequence
                         '#:stream-write-sequence
                         '#:stream-file-position
                         *gray-stream-symbols*))
          :iolib.base))
