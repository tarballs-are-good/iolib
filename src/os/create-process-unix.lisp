;;;; -*- Mode: Lisp; indent-tabs-mode: nil -*-
;;;
;;; --- Wrapper over lfp_spawn(3)
;;;

(in-package :iolib.os)

(defun tty-read-fn (fd buf nbytes)
  (handler-case
      (isys:read fd buf nbytes)
    (isys:eio () 0)))

(defun tty-write-fn (fd buf nbytes)
  (handler-case
      (isys:write fd buf nbytes)
    (isys:eio ()
      (error 'isys:epipe
             :handle fd
             :syscall "write"))))

(defclass tty-stream (iolib.streams:dual-channel-gray-stream)
  ()
  (:default-initargs :read-fn  #'tty-read-fn
                     :write-fn #'tty-write-fn))

(defclass process ()
  ((pid    :initarg :pid :reader process-pid)
   (status :initform :running)
   (closed :initform nil)
   (stdin  :reader process-stdin)
   (stdout :reader process-stdout)
   (stderr :reader process-stderr)))

(defmethod initialize-instance :after ((process process) &key
                                       stdin stdout stderr external-format)
  (with-slots ((in stdin) (out stdout) (err stderr))
      process
    (when stdin
      (setf in  (make-instance 'tty-stream :fd stdin
                               :external-format external-format)))
    (when stdout
      (setf out (make-instance 'tty-stream :fd stdout
                               :external-format external-format)))
    (when stderr
      (setf err (make-instance 'tty-stream :fd stderr
                               :external-format external-format)))))

(defmethod close ((process process) &key abort)
  (if (slot-value process 'closed)
      nil
      (macrolet ((close-process-stream (slot)
                   `(when (slot-boundp process ',slot)
                      (close (slot-value process ',slot) :abort abort)
                      (slot-makunbound process ',slot))))
        (close-process-stream stdin)
        (close-process-stream stdout)
        (close-process-stream stderr)
        (process-status process :wait (not abort))
        (setf (slot-value process 'closed) t)
        t)))

(defmethod print-object ((o process) s)
  (print-unreadable-object (o s :type t :identity t)
    (format s "~S ~S ~S ~S"
            :pid (process-pid o)
            :status (process-status o))))

(defun exit-status (status)
  (cond
    ((isys:wifexited status)
     (isys:wexitstatus status))
    ((isys:wifsignaled status)
     (values (isys:wtermsig* status)
             (isys:wcoredump status)))))

(defmethod process-status ((process process) &key wait)
  (if (integerp (slot-value process 'status))
      (exit-status (slot-value process 'status))
      (multiple-value-bind (pid status)
          (isys:waitpid (process-pid process)
                        (if wait 0 isys:wnohang))
        (cond
          ((zerop pid)
           :running)
          (t
           (setf (slot-value process 'status) status)
           (exit-status status))))))

(defmethod process-activep ((process process))
  (eql :running (process-status process)))

(defmethod process-kill ((process process) &optional (signum :sigterm))
  (isys:kill (process-pid process) signum)
  process)


(defmacro with-lfp-spawn-arguments ((attributes file-actions pid) &body body)
  (with-gensyms (spawnattr-initialized-p file-actions-initialized-p)
    `(with-foreign-objects ((,attributes 'lfp-spawnattr-t)
                            (,file-actions 'lfp-spawn-file-actions-t)
                            (,pid 'pid-t))
       (let ((,spawnattr-initialized-p nil)
             (,file-actions-initialized-p nil))
         (unwind-protect
              (progn
                (setf ,spawnattr-initialized-p
                      (lfp-spawnattr-init ,attributes))
                (setf ,file-actions-initialized-p
                      (lfp-spawn-file-actions-init ,file-actions))
                ,@body)
           (when ,spawnattr-initialized-p
             (lfp-spawnattr-destroy ,attributes))
           (when ,file-actions-initialized-p
             (lfp-spawn-file-actions-destroy ,file-actions)))))))

(defun allocate-argv (argv program arglist)
  ;; copy program name
  (setf (mem-aref argv :pointer 0)
        (foreign-string-alloc program))
  ;; copy program arguments
  (loop :for i :from 1
        :for arg :in arglist :do
        (setf (mem-aref argv :pointer i)
              (foreign-string-alloc arg))))

(defun find-program (program)
  (cond
    ((eql :shell program)
     "/bin/sh")
    (t
     (file-path-namestring program))))

(defmacro with-argv (((arg0 argv) program arguments) &body body)
  (with-gensyms (argc)
    `(let ((,program (find-program ,program))
           (,argc (+ 2 (length ,arguments))))
       (with-foreign-object (,argv :pointer ,argc)
         (isys:bzero ,argv (* ,argc (isys:sizeof :pointer)))
         (unwind-protect
              (progn
                (allocate-argv ,argv ,program ,arguments)
                (let ((,arg0 (mem-ref ,argv :pointer)))
                  ,@body))
           (deallocate-null-ended-list ,argv))))))

(defun redirect-one-stream (file-actions fd stream &optional flags (mode #o644) close-old-fd)
  (flet ((dup-from-path (path)
           (lfp-spawn-file-actions-addopen file-actions fd path flags mode))
         (dup-from-fd (oldfd)
           (lfp-spawn-file-actions-adddup2 file-actions oldfd fd)
           (when close-old-fd
             (lfp-spawn-file-actions-addclose file-actions oldfd))))
    (etypecase stream
      ((eql t) nil)
      ((or string file-path pathname)
       (dup-from-path (file-path-namestring stream)))
      ((eql :null)
       (dup-from-path "/dev/null"))
      (unsigned-byte
       (dup-from-fd stream))
      (iolib.streams:dual-channel-fd-mixin
       (dup-from-fd (iolib.streams:fd-of stream)))
      (null
       (lfp-spawn-file-actions-addclose file-actions fd)))))

(defun redirect-to-pipes (file-actions fd keep-write-fd)
  (multiple-value-bind (pipe-parent pipe-child)
      (isys:pipe)
    (when keep-write-fd (rotatef pipe-parent pipe-child))
    (lfp-spawn-file-actions-adddup2 file-actions pipe-child fd)
    (lfp-spawn-file-actions-addclose file-actions pipe-parent)
    (lfp-spawn-file-actions-addclose file-actions pipe-child)
    (values pipe-parent pipe-child)))

(defun setup-redirections (file-actions stdin stdout stderr ptmfd pts)
  (let (infd infd-child outfd outfd-child errfd errfd-child)
    ;; Standard input
    (case stdin
      (:pipe
       (setf (values infd infd-child)
             (redirect-to-pipes file-actions +stdin+ t)))
      (:pty
       (setf infd (isys:dup ptmfd))
       (redirect-one-stream file-actions +stdin+ pts isys:o-rdonly))
      (t (redirect-one-stream file-actions +stdin+ stdin isys:o-rdonly)))
    ;; Standard output
    (case stdout
      (:pipe
       (setf (values outfd outfd-child)
             (redirect-to-pipes file-actions +stdout+ nil)))
      (:pty
       (setf outfd (isys:dup ptmfd))
       (redirect-one-stream file-actions +stdout+ pts (logior isys:o-wronly
                                                              isys:o-creat)))
      (t (redirect-one-stream file-actions +stdout+ stdout (logior isys:o-wronly
                                                                   isys:o-creat))))
    ;; Standard error
    (case stderr
      (:pipe
       (setf (values errfd errfd-child)
             (redirect-to-pipes file-actions +stderr+ nil)))
      (:pty
       (setf errfd (isys:dup ptmfd))
       (redirect-one-stream file-actions +stderr+ pts (logior isys:o-wronly
                                                              isys:o-creat)))
      (t (redirect-one-stream file-actions +stderr+ stderr (logior isys:o-wronly
                                                                   isys:o-creat))))
    (values infd infd-child outfd outfd-child errfd errfd-child)))

(defun close-fds (&rest fds)
  (dolist (fd fds)
    (when fd (isys:close fd))))

(defun setup-slave-pty ()
  (let ((ptmfd (isys:openpt (logior isys:o-rdwr isys:o-noctty isys:o-cloexec))))
    (isys:grantpt ptmfd)
    (isys:unlockpt ptmfd)
    (values ptmfd (isys:ptsname ptmfd))))

(defmacro with-pty ((ptmfd pts) &body body)
  `(multiple-value-bind (,ptmfd ,pts)
       (setup-slave-pty)
     (unwind-protect
          (locally ,@body)
       (close-fds ,ptmfd))))

(defmacro with-redirections (((infd outfd errfd)
                              (file-actions stdin stdout stderr))
                             &body body)
  (with-gensyms (infd-child outfd-child errfd-child ptmfd pts)
    `(with-pty (,ptmfd ,pts)
       (multiple-value-bind (,infd ,infd-child ,outfd ,outfd-child ,errfd ,errfd-child)
           (setup-redirections ,file-actions ,stdin ,stdout ,stderr ,ptmfd ,pts)
         (unwind-protect-case ()
             (locally ,@body)
           (:always
            (close-fds ,infd-child ,outfd-child ,errfd-child))
           (:abort
            (close-fds ,infd ,outfd ,errfd)))))))

(defun process-other-spawn-args (attributes new-session current-directory
                                 uid gid resetids)
  (when new-session
    (lfp-spawnattr-setsid attributes))
  (when current-directory
    (lfp-spawnattr-setcwd attributes current-directory))
  (when uid
    (lfp-spawnattr-setuid attributes uid))
  (when gid
    (lfp-spawnattr-setgid attributes gid))
  (when resetids
    (lfp-spawnattr-setflags attributes lfp-spawn-resetids)))

;; program: :shell - the system shell
;;          file-path designator - a path
;; arguments: list
;; environment: t - inherit environment
;;              nil - NULL environment
;;              alist - the environment to use
;; stdin, stdout, stderr:
;;         file-path designator - open file, redirect to it
;;         :null - redirect to /dev/null - useful because /dev/null doesn't exist on Windows
;;         file-descriptor designator(integer or stream) - file descriptor, redirecto to it
;;         :pipe - create pipe, redirect the child descriptor to one end and wrap the other end
;;                 into a stream which goes into PROCESS slot
;;         t - inherit
;;         nil - close
;; new-session: boolean - create a new session using setsid()
;; current-directory: path - a directory to switch to before executing
;; uid: user id - unsigned-byte or string
;; gid: group id - unsigned-byte or string
;; resetids: boolean - reset effective UID and GID to saved IDs

(defun create-process (program-and-args &key (environment t)
                       (stdin :pipe) (stdout :pipe) (stderr :pipe)
                       new-session current-directory uid gid resetids
                       (external-format :utf-8))
  (flet ((new-ctty-p (stdin stdout stderr)
           (or (eql :pty stdin)
               (eql :pty stdout)
               (eql :pty stderr))))
    (destructuring-bind (program &rest arguments)
        (ensure-list program-and-args)
      (when (new-ctty-p stdin stdout stderr)
        (setf new-session t))
      (with-argv ((arg0 argv) program arguments)
        (with-c-environment (envp environment)
          (with-lfp-spawn-arguments (attributes file-actions pid)
            (with-redirections ((infd outfd errfd)
                                (file-actions stdin stdout stderr))
              (process-other-spawn-args attributes new-session current-directory
                                        uid gid resetids)
              (lfp-spawnp pid arg0 argv envp file-actions attributes)
              (make-instance 'process :pid (mem-ref pid 'pid-t)
                             :stdin infd :stdout outfd :stderr errfd
                             :external-format external-format))))))))

(defun run-program (program-and-args &key (environment t) (stderr :pipe)
                    (external-format :utf-8))
  (flet ((slurp (stream)
           (with-output-to-string (s)
             (loop :for c := (read-char stream nil nil)
                   :while c :do (write-char c s)))))
    (let ((process (create-process program-and-args
                                   :environment environment
                                   :stdin nil
                                   :stdout :pipe
                                   :stderr stderr
                                   :external-format external-format)))
      (unwind-protect
           (values (process-status process :wait t)
                   (slurp (process-stdout process))
                   (if (eql :pipe stderr)
                       (slurp (process-stderr process))
                       (make-string 0)))
        (close process)))))
