;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil -*-
;;;
;;; --- OS interface.
;;;

(in-package :iolib.os)

;;;; Environment access

(defclass environment ()
  ((variables :initarg :variables
              :initform (make-hash-table :test #'equal)
              :accessor environment-variables)))

(defun %envar (env name)
  (gethash name (environment-variables env)))

(defun (setf %envar) (value env name)
  (setf (gethash name (environment-variables env))
        value))

(defun %remvar (env name)
  (remhash name (environment-variables env)))

(defun environment-variable (name &key env)
  "ENVIRONMENT-VARIABLE returns the environment variable
identified by NAME, or NIL if one does not exist.  NAME can
either be a symbol or a string.

SETF ENVIRONMENT-VARIABLE sets the environment variable
identified by NAME to VALUE.  Both NAME and VALUE can be either a
symbols or strings. Signals an error on failure."
  (let ((name (string name)))
    (cond
      (env
       (check-type env environment)
       (%envar env name))
      (t
       (isys:%sys-getenv name)))))

(defun (setf environment-variable) (value name &key env (overwrite t))
  (check-type value string)
  (let ((name (string name)))
    (cond
      (env
       (check-type env environment)
       (when (or overwrite
                 (null (nth-value 1 (%envar env name))))
         (setf (%envar env name) value)))
      (t
       (isys:%sys-setenv (string name) value overwrite))))
  value)

(defun makunbound-environment-variable (name &key env)
  "Removes the environment variable identified by NAME from the
current environment.  NAME can be either a string or a symbol.
Returns the string designated by NAME.  Signals an error on
failure."
  (let ((name (string name)))
    (cond
      (env
       (check-type env environment)
       (%remvar env name))
      (t
       (isys:%sys-unsetenv (string name)))))
  (values name))

(defun %environment ()
  (loop :with env := (make-instance 'environment)
        :for i :from 0 :by 1
        :for string := (mem-aref isys:*environ* :string i)
        :for split := (position #\= string)
        :while string :do
        (let ((var (subseq string 0 split))
              (val (subseq string (1+ split))))
          (setf (environment-variable var :env env) val))
        :finally (return env)))

(defun environment (&optional env)
  "If ENV is non-NIL, ENVIRONMENT copies ENV, otherwise returns the
current global environment.
SETF ENVIRONMENT replaces the contents of the global environment
with that of its argument.

Often it is preferable to use SETF ENVIRONMENT-VARIABLE and
MAKUNBOUND-ENVIRONMENT-VARIABLE to modify the environment instead
of SETF ENVIRONMENT."
  (cond
    (env
     (check-type env environment)
     (make-instance 'environment
                    :variables (copy-hash-table
                                (environment-variables env))))
    (t
     (%environment))))

(defun (setf environment) (newenv)
  (check-type newenv environment)
  (let ((oldenv (environment)))
    (maphash (lambda (k v)
               (setf (environment-variable k) v)
               (makunbound-environment-variable k :env oldenv))
             (environment-variables newenv))
    (maphash (lambda (k v) (declare (ignore v))
               (makunbound-environment-variable k))
             (environment-variables oldenv)))
  newenv)


;;;; Current directory

(defun current-directory ()
  "CURRENT-DIRECTORY returns the operating system's current
directory, which may or may not correspond to
*DEFAULT-FILE-PATH-DEFAULTS*.

SETF CURRENT-DIRECTORY changes the operating system's current
directory to the PATHSPEC.  An error is signalled if PATHSPEC
is not a directory."
  (let ((cwd (isys:%sys-getcwd)))
    (if cwd
        (parse-file-path cwd :expand-user nil)
        (isys:syscall-error "Could not get current directory."))))

(defun (setf current-directory) (pathspec)
  (let ((path (file-path pathspec)))
    (isys:%sys-chdir (file-path-namestring path))))

(defmacro with-current-directory (pathspec &body body)
  (with-gensyms (old)
    `(let ((,old (current-directory)))
       (unwind-protect
            (progn
              (setf (current-directory) (file-path ,pathspec))
              ,@body)
         (setf (current-directory) ,old)))))


;;;; File-path manipulations

(defun absolute-file-path (pathspec defaults)
  (let ((path (file-path pathspec)))
    (if (absolute-file-path-p path)
        path
        (let ((tmp (merge-file-paths path defaults)))
          (if (absolute-file-path-p tmp)
              tmp
              (merge-file-paths tmp (current-directory)))))))

(defun strip-dots (path)
  (multiple-value-bind (root nodes)
      (split-root/nodes (file-path-components path))
    (let (new-components)
      (dolist (n nodes)
        (cond
          ((string= n "."))
          ((string= n "..")
           (pop new-components))
          (t (push n new-components))))
      (make-file-path :components (if root
                                      (cons root (nreverse new-components))
                                      (nreverse new-components))
                      :defaults path))))

(defun resolve-symlinks (path)
  (let* ((namestring (file-path-namestring path))
         (realpath (isys:%sys-realpath namestring)))
    (parse-file-path realpath)))

(defun resolve-file-path (pathspec &key
                          (defaults *default-file-path-defaults*)
                          (canonicalize t))
  "Returns an absolute file-path corresponding to PATHSPEC by
merging it with DEFAULT, and (CURRENT-DIRECTORY) if necessary.
If CANONICALIZE is non-NIL, the path is canonicalised: if it is :STRIP-DOTS,
then just remove «.» and «..», otherwise symlinks are resolved too."
  (let ((absolute-file-path (absolute-file-path pathspec defaults)))
    (case canonicalize
      ((nil)       absolute-file-path)
      (:strip-dots (strip-dots absolute-file-path))
      (t           (resolve-symlinks absolute-file-path)))))


;;;; File kind

;;; FIXME: make sure that GET-FILE-KIND be able to signal
;;;        only conditions of type FILE-ERROR, either by
;;;        wrapping POSIX-ERRORs or making sure that some
;;;        POSIX-ERRORS subclass FILE-ERROR
(defun get-file-kind (file follow-p)
  (let ((namestring (file-path-namestring file)))
    (handler-case
        (let ((mode (isys:stat-mode
                     (if follow-p
                         (isys:%sys-stat namestring)
                         (isys:%sys-lstat namestring)))))
          (switch ((logand isys:s-ifmt mode) :test #'=)
            (isys:s-ifdir  :directory)
            (isys:s-ifchr  :character-device)
            (isys:s-ifblk  :block-device)
            (isys:s-ifreg  :regular-file)
            (isys:s-iflnk  :symbolic-link)
            (isys:s-ifsock :socket)
            (isys:s-ififo  :pipe)
            (t (bug "Unknown file mode: ~A." mode))))
      ((or enoent eloop) ()
        (cond
          ;; stat() returned ENOENT: either FILE does not exist
          ;; or it is a broken symlink
          (follow-p
           (handler-case
               (isys:%sys-lstat namestring)
             ((or enoent eloop) ())
             (:no-error (stat)
               (declare (ignore stat))
               (values :symbolic-link :broken))))
          ;; lstat() returned ENOENT: FILE does not exist
          (t nil))))))

(defun file-kind (pathspec &key follow-symlinks)
  "Returns a keyword indicating the kind of file designated by PATHSPEC,
or NIL if the file does not exist.  Does not follow symbolic
links by default.

Possible file-kinds in addition to NIL are: :REGULAR-FILE,
:SYMBOLIC-LINK, :DIRECTORY, :PIPE, :SOCKET, :CHARACTER-DEVICE, and
:BLOCK-DEVICE.
If FOLLOW-SYMLINKS is non-NIL and PATHSPEC designates a broken symlink
returns :BROKEN as second value."
  (get-file-kind (merge-file-paths pathspec) follow-symlinks))

(defun file-exists-p (pathspec &optional file-kind)
  "Checks whether the file named by the file-path designator
PATHSPEC exists, if this is the case and FILE-KIND is specified
it also checks the file kind. If the tests succeed, return two values:
truename and file kind of PATHSPEC, NIL otherwise.
Follows symbolic links."
  (let* ((path (file-path pathspec))
         (follow (unless (eq file-kind :symbolic-link) t))
         (actual-kind (file-kind path :follow-symlinks follow)))
    (when (and actual-kind
               (if file-kind (eql file-kind actual-kind) t))
      (values (resolve-file-path path)
              actual-kind))))

(defun regular-file-exists-p (pathspec)
  "Checks whether the file named by the file-path designator
PATHSPEC exists and is a regular file. Returns its truename
if this is the case, NIL otherwise. Follows symbolic links."
  (nth-value 0 (file-exists-p pathspec :regular-file)))

(defun directory-exists-p (pathspec)
  "Checks whether the file named by the file-path designator
PATHSPEC exists and is a directory.  Returns its truename
if this is the case, NIL otherwise.  Follows symbolic links."
  (nth-value 0 (file-exists-p pathspec :directory)))

(defun good-symlink-exists-p (pathspec)
  "Checks whether the file named by the file-path designator
PATHSPEC exists and is a symlink pointing to an existent file."
  (eq :broken (nth-value 1 (file-kind pathspec :follow-symlinks t))))


;;;; Temporary files

(defvar *temporary-directory*
  (let ((system-tmpdir (or (environment-variable "TMPDIR")
                           (environment-variable "TMP")
                           "/tmp")))
    (parse-file-path system-tmpdir :expand-user nil)))


;;;; Symbolic and hard links

(defun read-symlink (pathspec)
  "Returns the file-path pointed to by the symbolic link
designated by PATHSPEC.  If the link is relative, then the
returned file-path is relative to the link, not
*DEFAULT-FILE-PATH-DEFAULTS*.

Signals an error if PATHSPEC is not a symbolic link."
  ;; Note: the previous version tried much harder to provide a buffer
  ;; big enough to fit the link's name.  OTOH, %SYS-READLINK stack
  ;; allocates on most lisps.
  (file-path (isys:%sys-readlink
              (file-path-namestring
               (absolute-file-path pathspec *default-file-path-defaults*)))))

(defun make-symlink (link target)
  "Creates symbolic LINK that points to TARGET.
Returns the file-path of the link.

Relative targets are resolved against the link.  Relative links
are resolved against *DEFAULT-FILE-PATH-DEFAULTS*.

Signals an error if TARGET does not exist, or LINK exists already."
  (let ((link (file-path link))
        (target (file-path target)))
    (with-current-directory
        (absolute-file-path *default-file-path-defaults* nil)
      (isys:%sys-symlink (file-path-namestring target)
                         (file-path-namestring link))
      link)))

(defun make-hardlink (link target)
  "Creates hard LINK that points to TARGET.
Returns the file-path of the link.

Relative targets are resolved against the link.  Relative links
are resolved against *DEFAULT-FILE-PATH-DEFAULTS*.

Signals an error if TARGET does not exist, or LINK exists already."
  (let ((link (file-path link))
        (target (file-path target)))
    (with-current-directory
        (absolute-file-path *default-file-path-defaults* nil)
      (isys:%sys-link (file-path-namestring
                       (merge-file-paths target link))
                      link)
      link)))


;;;; File permissions

(defconstant (+permissions+ :test #'equal)
  `((:user-read    . ,isys:s-irusr)
    (:user-write   . ,isys:s-iwusr)
    (:user-exec    . ,isys:s-ixusr)
    (:group-read   . ,isys:s-irgrp)
    (:group-write  . ,isys:s-iwgrp)
    (:group-exec   . ,isys:s-ixgrp)
    (:other-read   . ,isys:s-iroth)
    (:other-write  . ,isys:s-iwoth)
    (:other-exec   . ,isys:s-ixoth)
    (:set-user-id  . ,isys:s-isuid)
    (:set-group-id . ,isys:s-isgid)
    (:sticky       . ,isys:s-isvtx)))

(defun file-permissions (pathspec)
  "FILE-PERMISSIONS returns a list of keywords identifying the
permissions of PATHSPEC.

SETF FILE-PERMISSIONS sets the permissions of PATHSPEC as
identified by the symbols in list.

If PATHSPEC designates a symbolic link, that link is implicitly
resolved.

Permission symbols consist of :USER-READ, :USER-WRITE, :USER-EXEC,
:GROUP-READ, :GROUP-WRITE, :GROUP-EXEC, :OTHER-READ, :OTHER-WRITE,
:OTHER-EXEC, :SET-USER-ID, :SET-GROUP-ID, and :STICKY.

Both signal an error if PATHSPEC doesn't designate an existing file."
  (let ((mode (isys:stat-mode
               (isys:%sys-stat (file-path-namestring pathspec)))))
    (loop :for (name . value) :in +permissions+
          :when (plusp (logand mode value))
          :collect name)))

(defun (setf file-permissions) (perms pathspec)
  (isys:%sys-chmod (file-path-namestring pathspec)
                   (reduce (lambda (a b)
                             (logior a (cdr (assoc b +permissions+))))
                           perms :initial-value 0)))


;;;; Directory access

(defmacro with-directory-iterator ((iterator pathspec) &body body)
  "PATHSPEC must be a valid directory designator:
*DEFAULT-FILE-PATH-DEFAULTS* is bound, and (CURRENT-DIRECTORY) is set
to the designated directory for the dynamic scope of the body.

Within the lexical scope of the body, ITERATOR is defined via
macrolet such that successive invocations of (ITERATOR) return
the directory entries, one by one.  Both files and directories
are returned, except '.' and '..'.  The order of entries is not
guaranteed.  The entries are returned as relative file-paths
against the designated directory.  Entries that are symbolic
links are not resolved, but links that point to directories are
interpreted as directory designators.  Once all entries have been
returned, further invocations of (ITERATOR) will all return NIL.

The value returned is the value of the last form evaluated in
body.  Signals an error if PATHSPEC is not a directory."
  (with-unique-names (one-iter)
    `(call-with-directory-iterator
      ,pathspec
      (lambda (,one-iter)
        (declare (type function ,one-iter))
        (macrolet ((,iterator ()
                     `(funcall ,',one-iter)))
          ,@body)))))

(defun call-with-directory-iterator (pathspec fn)
  (let* ((dir (resolve-file-path pathspec :canonicalize nil))
         (dp (isys:%sys-opendir (file-path-namestring dir))))
    (labels ((one-iter ()
               (let ((name (isys:%sys-readdir dp)))
                 (unless (null name)
                   (cond
                     ((member name '("." "..") :test #'string=)
                      (one-iter))
                     (t
                      (parse-file-path name)))))))
      (with-current-directory dir
        (unwind-protect
             (let ((*default-file-path-defaults* dir))
               (funcall fn #'one-iter))
          (isys:%sys-closedir dp))))))

(defun mapdir (function pathspec)
  "Applies function to each entry in directory designated by
PATHSPEC in turn and returns a list of the results.  Binds
*DEFAULT-FILE-PATH-DEFAULTS* to the directory designated by
pathspec round to function call.

If PATHSPEC designates a symbolic link, it is implicitly resolved.

Signals an error if PATHSPEC is not a directory."
  (with-directory-iterator (next pathspec)
    (loop :for entry := (next)
          :while entry
          :collect (funcall function entry))))

(defun list-directory (pathspec &key absolute-paths)
  "Returns a fresh list of file-paths corresponding to all files
within the directory named by PATHSPEC.
If ABSOLUTE-PATHS is not NIL the files' paths are merged with PATHSPEC."
  (with-directory-iterator (next pathspec)
    (loop :for entry := (next)
          :while entry :collect (if absolute-paths
                                    (merge-file-paths entry pathspec)
                                    entry))))

(defun walk-directory (directory fn &key (if-does-not-exist :error)
                       follow-symlinks (order :directory-first)
                       (mindepth 1) (maxdepth 65535)
                       (test (constantly t)) (key #'identity))
  "Recursively applies the function FN to all files within the
directory named by the FILE-PATH designator DIRNAME and all of
the files and directories contained within.  Returns T on success."
  (labels ((walk (name depth parent)
             (incf depth)
             (let* ((kind
                     (file-kind name :follow-symlinks follow-symlinks))
                    (path-components
                     (revappend parent (file-path-components name)))
                    (path (make-file-path :components path-components))
                    (name-key (funcall key path kind)))
               (case kind
                 (:directory
                  (when (and (funcall test name-key kind)
                             (< depth maxdepth))
                    (ecase order
                      (:directory-first
                       (when (<= mindepth depth)
                         (funcall fn name-key kind))
                       (walkdir name depth parent))
                      (:depth-first
                       (walkdir name depth parent)
                       (when (<= mindepth depth)
                         (funcall fn name-key kind))))))
                 (t (when (and (funcall test name-key kind)
                               (<= mindepth depth))
                      (funcall fn name-key kind)))))
             (decf depth))
           (walkdir (name depth parent)
             (mapdir (lambda (dir)
                       (walk dir (1+ depth)
                             (if (plusp depth)
                                 (cons (file-path-file name) parent)
                                 parent)))
                     name)))
    (handler-case
        (let* ((directory (file-path directory))
               (ns (file-path-namestring directory))
               (kind
                (file-kind directory :follow-symlinks t)))
          (unless (eql :directory kind)
            (isys:syscall-error "~S is not a directory" directory))
          (walk ns -1 ()) t)
      ;; FIXME: Handle all possible syscall errors
      (isys:enoent ()
        (ecase if-does-not-exist
          (:error (isys:syscall-error "Directory ~S does not exist" directory))
          ((nil)  nil)))
      (isys:eacces ()
        (isys:syscall-error "Search permission is denied for ~S" directory)))))


;;;; User information

(defun user-info (id)
  "USER-INFO returns the password entry for the given name or
numerical user ID, as an assoc-list."
  (multiple-value-bind (name password uid gid gecos home shell)
      (etypecase id
        (string  (isys:%sys-getpwnam id))
        (integer (isys:%sys-getpwuid id)))
    (declare (ignore password))
    (unless (null name)
      (list (cons :name name)
            (cons :user-id uid)
            (cons :group-id gid)
            (cons :gecos gecos)
            (cons :home home)
            (cons :shell shell)))))