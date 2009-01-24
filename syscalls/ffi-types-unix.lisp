;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil -*-
;;;
;;; --- Grovel definitions for *NIX systems.
;;;

#+linux
(define "_GNU_SOURCE")

;;; largefile support on linux
;;; TODO: check if these flags are required on solaris too
#+linux
(progn
  (define "_LARGEFILE_SOURCE")
  (define "_LARGEFILE64_SOURCE")
  (define "_FILE_OFFSET_BITS" 64))

(include "stdlib.h" "errno.h" "sys/types.h" "sys/stat.h" "sys/mman.h"
         "fcntl.h" "signal.h" "unistd.h" "limits.h" "time.h" "sys/select.h"
         "sys/poll.h" "sys/ioctl.h" "sys/resource.h" "pwd.h" "grp.h"
         "dirent.h" "sys/utsname.h")

#+linux
(include "sys/epoll.h" "sys/ioctl.h")

#+bsd
(include "sys/event.h" "sys/time.h")    ; for kqueue


(in-package :iolib.syscalls)

(ctype size-t "size_t")
(ctype ssize-t "ssize_t")
(ctype pid-t "pid_t")
(ctype uid-t "uid_t")
(ctype gid-t "gid_t")
(ctype off-t "off_t")
(ctype mode-t "mode_t")

(constantenum (errno-values :define-constants t)
  ((:eperm "EPERM"))
  ((:enoent "ENOENT"))
  ((:esrch "ESRCH"))
  ((:eintr "EINTR"))
  ((:eio "EIO"))
  ((:enxio "ENXIO"))
  ((:e2big "E2BIG"))
  ((:enoexec "ENOEXEC"))
  ((:ebadf "EBADF"))
  ((:echild "ECHILD"))
  ((:eagain "EAGAIN"))
  ((:enomem "ENOMEM"))
  ((:eacces "EACCES"))
  ((:efault "EFAULT"))
  ((:ebusy "EBUSY"))
  ((:eexist "EEXIST"))
  ((:exdev "EXDEV"))
  ((:enodev "ENODEV"))
  ((:enotdir "ENOTDIR"))
  ((:eisdir "EISDIR"))
  ((:einval "EINVAL"))
  ((:enfile "ENFILE"))
  ((:emfile "EMFILE"))
  ((:enotty "ENOTTY"))
  ((:efbig "EFBIG"))
  ((:enospc "ENOSPC"))
  ((:espipe "ESPIPE"))
  ((:erofs "EROFS"))
  ((:emlink "EMLINK"))
  ((:epipe "EPIPE"))
  ((:edom "EDOM"))
  ((:erange "ERANGE"))
  ((:edeadlk "EDEADLK"))
  ((:enametoolong "ENAMETOOLONG"))
  ((:enolck "ENOLCK"))
  ((:enosys "ENOSYS"))
  ((:enotempty "ENOTEMPTY"))
  ((:echrng "ECHRNG") :optional t)
  ((:el2nsync "EL2NSYNC") :optional t)
  ((:el3hlt "EL3HLT") :optional t)
  ((:el3rst "EL3RST") :optional t)
  ((:elnrng "ELNRNG") :optional t)
  ((:eunatch "EUNATCH") :optional t)
  ((:enocsi "ENOCSI") :optional t)
  ((:el2hlt "EL2HLT") :optional t)
  ((:ebade "EBADE") :optional t)
  ((:ebadr "EBADR") :optional t)
  ((:exfull "EXFULL") :optional t)
  ((:enoano "ENOANO") :optional t)
  ((:ebadrqc "EBADRQC") :optional t)
  ((:ebadslt "EBADSLT") :optional t)
  ((:edeadlock "EDEADLOCK") :optional t)
  ((:ebfont "EBFONT") :optional t)
  ((:enostr "ENOSTR") :optional t)
  ((:enodata "ENODATA") :optional t)
  ((:etime "ETIME") :optional t)
  ((:enosr "ENOSR") :optional t)
  ((:enopkg "ENOPKG") :optional t)
  ((:eadv "EADV") :optional t)
  ((:esrmnt "ESRMNT") :optional t)
  ((:ecomm "ECOMM") :optional t)
  ((:edotdot "EDOTDOT") :optional t)
  ((:enotuniq "ENOTUNIQ") :optional t)
  ((:ebadfd "EBADFD") :optional t)
  ((:eremchg "EREMCHG") :optional t)
  ((:elibacc "ELIBACC") :optional t)
  ((:elibbad "ELIBBAD") :optional t)
  ((:elibscn "ELIBSCN") :optional t)
  ((:elibmax "ELIBMAX") :optional t)
  ((:elibexec "ELIBEXEC") :optional t)
  ((:eilseq "EILSEQ"))
  ((:erestart "ERESTART") :optional t)
  ((:estrpipe "ESTRPIPE") :optional t)
  ((:euclean "EUCLEAN") :optional t)
  ((:enotnam "ENOTNAM") :optional t)
  ((:enavail "ENAVAIL") :optional t)
  ((:eremoteio "EREMOTEIO") :optional t)
  ((:enomedium "ENOMEDIUM") :optional t)
  ((:emediumtype "EMEDIUMTYPE") :optional t)
  ((:estale "ESTALE"))
  ((:enotblk "ENOTBLK"))
  ((:etxtbsy "ETXTBSY"))
  ((:eusers "EUSERS"))
  ((:eloop "ELOOP"))
  ((:ewouldblock "EWOULDBLOCK"))
  ((:enomsg "ENOMSG"))
  ((:eidrm "EIDRM"))
  ((:eproto "EPROTO"))
  ((:emultihop "EMULTIHOP"))
  ((:ebadmsg "EBADMSG"))
  ((:eoverflow "EOVERFLOW"))
  ((:edquot "EDQUOT"))
  ((:einprogress "EINPROGRESS"))
  ((:ealready "EALREADY"))
  ;; TODO: These errors are related to sockets.  However they
  ;; might not be unique to them.  Remove those that are unique
  ;; and keep those that might be set elsewhere.
  ((:eprotonosupport "EPROTONOSUPPORT"))
  ((:esocktnosupport "ESOCKTNOSUPPORT"))
  ((:enotsock "ENOTSOCK"))
  ((:edestaddrreq "EDESTADDRREQ"))
  ((:emsgsize "EMSGSIZE"))
  ((:eprototype "EPROTOTYPE"))
  ((:enoprotoopt "ENOPROTOOPT"))
  ((:eremote "EREMOTE"))
  ((:enolink "ENOLINK"))
  ((:epfnosupport "EPFNOSUPPORT"))
  ((:eafnosupport "EAFNOSUPPORT"))
  ((:eaddrinuse "EADDRINUSE"))
  ((:eaddrnotavail "EADDRNOTAVAIL"))
  ((:enetdown "ENETDOWN"))
  ((:enetunreach "ENETUNREACH"))
  ((:enetreset "ENETRESET"))
  ((:econnaborted "ECONNABORTED"))
  ((:econnreset "ECONNRESET"))
  ((:eisconn "EISCONN"))
  ((:enotconn "ENOTCONN"))
  ((:eshutdown "ESHUTDOWN"))
  ((:etoomanyrefs "ETOOMANYREFS"))
  ((:etimedout "ETIMEDOUT"))
  ((:econnrefused "ECONNREFUSED"))
  ((:ehostdown "EHOSTDOWN"))
  ((:ehostunreach "EHOSTUNREACH"))
  ((:enonet "ENONET") :optional t)
  ((:enobufs "ENOBUFS"))
  ((:eopnotsupp "EOPNOTSUPP")))


;;; open()

(constant (o-rdonly "O_RDONLY"))
(constant (o-wronly "O_WRONLY"))
(constant (o-rdwr "O_RDWR"))
(constant (o-creat "O_CREAT"))
(constant (o-excl "O_EXCL"))
(constant (o-trunc "O_TRUNC"))
(constant (o-append "O_APPEND"))

(constant (o-noctty "O_NOCTTY"))
(constant (o-nonblock "O_NONBLOCK"))
(constant (o-ndelay "O_NDELAY"))
(constant (o-sync "O_SYNC"))
(constant (o-nofollow "O_NOFOLLOW"))
(constant (o-async "O_ASYNC"))


;;; lseek()

(constant (seek-set "SEEK_SET"))
(constant (seek-cur "SEEK_CUR"))
(constant (seek-end "SEEK_END"))


;;; access()

(constant (r-ok "R_OK"))
(constant (w-ok "W_OK"))
(constant (x-ok "X_OK"))
(constant (f-ok "F_OK"))


;;;; stat()

(constant (s-irwxu "S_IRWXU")
	  :documentation "read, write, execute/search by owner")
(constant (s-irusr "S_IRUSR") :documentation "read permission, owner")
(constant (s-iwusr "S_IWUSR") :documentation "write permission, owner")
(constant (s-ixusr "S_IXUSR") :documentation "execute/search permission, owner")
(constant (s-ifmt "S_IFMT")   :documentation "bitmask for type of entry")
(constant (s-ififo "S_IFIFO") :documentation "named pipe, aka fifo")
(constant (s-ifchr "S_IFCHR") :documentation "special character-device")
(constant (s-ifdir "S_IFDIR") :documentation "directory")
(constant (s-ifblk "S_IFBLK") :documentation "special block-device")
(constant (s-ifreg "S_IFREG") :documentation "regular file")
(constant (s-ifwht "S_IFWHT") :documentation "whiteout" :optional t)
(constant (s-iread "S_IREAD"))
(constant (s-iwrite "S_IWRITE"))
(constant (s-iexec "S_IEXEC"))

(constant (s-irwxg "S_IRWXG")
          :documentation "read, write, execute/search by group")
(constant (s-irgrp "S_IRGRP") :documentation "read permission, group")
(constant (s-iwgrp "S_IWGRP") :documentation "write permission, group")
(constant (s-ixgrp "S_IXGRP")
          :documentation "execute/search permission, group")
(constant (s-irwxo "S_IRWXO")
          :documentation "read, write, execute/search by others")
(constant (s-iroth "S_IROTH") :documentation "read permission, others")
(constant (s-iwoth "S_IWOTH") :documentation "write permission, others")
(constant (s-ixoth "S_IXOTH")
          :documentation "execute/search permission, others")
(constant (s-isuid "S_ISUID") :documentation "set-user-ID on execution")
(constant (s-isgid "S_ISGID") :documentation "set-group-ID on execution")
(constant (s-isvtx "S_ISVTX")
          :documentation "'sticky' bit, many meanings, nonportable")
(constant (s-iflnk "S_IFLNK") :documentation "symbolic link")
(constant (s-ifsock "S_IFSOCK") :documentation "socket")

(constant (path-max "PATH_MAX" "MAXPATHLEN"))


;;; from unistd.h

(ctype useconds-t "useconds_t")


;;; from time.h

(ctype time-t "time_t")
(ctype suseconds-t "suseconds_t")

#-darwin
(progn
  (ctype clockid-t "clockid_t")
  (constant (clock-monotonic "CLOCK_MONOTONIC"))
  (constant (clock-realtime "CLOCK_REALTIME")))

(cstruct timespec "struct timespec"
  "UNIX time specification in seconds and nanoseconds."
  (sec  "tv_sec"  :type time-t)
  (nsec "tv_nsec" :type :long))


;;; from sys/select.h

(cstruct timeval "struct timeval"
  "UNIX time specification in seconds and microseconds."
  (sec  "tv_sec"  :type time-t)
  (usec "tv_usec" :type suseconds-t))

(constant (fd-setsize "FD_SETSIZE"))

(cstruct fd-set "fd_set"
  (bits "fds_bits" :type :uint8 :count :auto))


;;; from sys/stat.h

(ctype dev-t "dev_t")
(ctype ino-t "ino_t")

(ctype nlink-t "nlink_t")
(ctype blksize-t "blksize_t")
(ctype blkcnt-t "blkcnt_t")

(cstruct stat "struct stat"
  (dev     "st_dev"     :type #-mips dev-t #+mips :unsigned-long)
  (ino     "st_ino"     :type ino-t)
  (mode    "st_mode"    :type mode-t)
  (nlink   "st_nlink"   :type nlink-t)
  (uid     "st_uid"     :type uid-t)
  (gid     "st_gid"     :type gid-t)
  (rdev    "st_rdev"    :type #-mips dev-t #+mips :unsigned-long)
  (size    "st_size"    :type off-t)
  (blksize "st_blksize" :type blkcnt-t)
  (blocks  "st_blocks"  :type blksize-t)
  (atime   "st_atime"   :type time-t)
  (mtime   "st_mtime"   :type time-t)
  (ctime   "st_ctime"   :type time-t))


;;; mmap()

(constant (prot-none   "PROT_NONE")   :documentation "mmap: no protection")
(constant (prot-read   "PROT_READ")   :documentation "mmap: read protection")
(constant (prot-write  "PROT_WRITE")  :documentation "mmap: write protection")
(constant (prot-exec   "PROT_EXEC")   :documentation "mmap: execute protection")
(constant (map-shared  "MAP_SHARED")  :documentation "mmap: shared memory")
(constant (map-private "MAP_PRIVATE") :documentation "mmap: private mapping")
(constant (map-fixed   "MAP_FIXED")   :documentation "mmap: map at location")
(constant (map-failed  "MAP_FAILED")  :documentation "mmap: failure")


;;; from sys/poll.h

(ctype nfds-t "nfds_t")

(cstruct pollfd "struct pollfd"
  "Poll file descriptor activity specification structure."
  (fd      "fd"      :type :int)
  (events  "events"  :type :short)
  (revents "revents" :type :short))

(constant (pollin "POLLIN"))
(constant (pollrdnorm "POLLRDNORM"))
(constant (pollrdband "POLLRDBAND"))
(constant (pollpri "POLLPRI"))
(constant (pollout "POLLOUT"))
(constant (pollwrnorm "POLLWRNORM"))
(constant (pollwrband "POLLWRBAND"))
(constant (pollerr "POLLERR"))
#+linux (constant (pollrdhup "POLLRDHUP"))
(constant (pollhup "POLLHUP"))
(constant (pollnval "POLLNVAL"))

;;;; from sys/epoll.h

#+linux
(progn
  (cunion epoll-data "epoll_data_t"
    (ptr "ptr" :type :pointer)
    (fd  "fd"  :type :int)
    (u32 "u32" :type :uint32)
    (u64 "u64" :type :uint64))

  (cstruct epoll-event "struct epoll_event"
    (events "events" :type :uint32)
    (data   "data"   :type epoll-data))

  (constant (epoll-ctl-add "EPOLL_CTL_ADD"))
  (constant (epoll-ctl-del "EPOLL_CTL_DEL"))
  (constant (epoll-ctl-mod "EPOLL_CTL_MOD"))

  (constant (epollin "EPOLLIN"))
  (constant (epollrdnorm "EPOLLRDNORM"))
  (constant (epollrdband "EPOLLRDBAND"))
  (constant (epollpri "EPOLLPRI"))
  (constant (epollout "EPOLLOUT"))
  (constant (epollwrnorm "EPOLLWRNORM"))
  (constant (epollwrband "EPOLLWRBAND"))
  (constant (epollerr "EPOLLERR"))
  (constant (epollhup "EPOLLHUP"))
  (constant (epollmsg "EPOLLMSG"))
  (constant (epolloneshot "EPOLLONESHOT"))
  (constant (epollet "EPOLLET")))

;;;; from sys/event.h

#+bsd
(progn
  (ctype intptr-t "intptr_t")
  (ctype uintptr-t "uintptr_t")

  (cstruct kevent "struct kevent"
    (ident  "ident"  :type uintptr-t)
    (filter "filter" :type :short)
    (flags  "flags"  :type :unsigned-short)
    (fflags "fflags" :type :unsigned-int)
    (data   "data"   :type intptr-t)
    (udata  "udata"  :type :pointer))

  ;; kevent() flags
  (constant (ev-add "EV_ADD"))
  (constant (ev-enable "EV_ENABLE"))
  (constant (ev-disable "EV_DISABLE"))
  (constant (ev-delete "EV_DELETE"))
  (constant (ev-oneshot "EV_ONESHOT"))
  (constant (ev-clear "EV_CLEAR"))
  (constant (ev-eof "EV_EOF"))
  (constant (ev-error "EV_ERROR"))

  ;; kevent() filter flags
  (constant (evfilt-read "EVFILT_READ"))
  (constant (evfilt-write "EVFILT_WRITE"))
  (constant (evfilt-aio "EVFILT_AIO"))
  (constant (evfilt-vnode "EVFILT_VNODE"))
  (constant (evfilt-proc "EVFILT_PROC"))
  (constant (evfilt-signal "EVFILT_SIGNAL"))
  (constant (evfilt-timer "EVFILT_TIMER"))
  #-darwin (constant (evfilt-netdev "EVFILT_NETDEV"))

  ;; EVFILT_VNODE options
  (constant (note-delete "NOTE_DELETE"))
  (constant (note-write "NOTE_WRITE"))
  (constant (note-extend "NOTE_EXTEND"))
  (constant (note-attrib "NOTE_ATTRIB"))
  (constant (note-link "NOTE_LINK"))
  (constant (note-rename "NOTE_RENAME"))
  (constant (note-revoke "NOTE_REVOKE"))

  ;; EVFILT_PROC options
  (constant (note-exit "NOTE_EXIT"))
  (constant (note-fork "NOTE_FORK"))
  (constant (note-exec "NOTE_EXEC"))
  (constant (note-track "NOTE_TRACK"))
  (constant (note-trackerr "NOTE_TRACKERR"))

  ;; EVFILT_NETDEV options
  #-darwin
  (progn
    (constant (note-linkup "NOTE_LINKUP"))
    (constant (note-linkdown "NOTE_LINKDOWN"))
    (constant (note-linkinv "NOTE_LINKINV"))))


;;; from dirent.h

;; Apparently POSIX 1003.1-2001 (according to linux manpages) only
;; requires d_name.  Sigh.  I guess we should assemble some decent
;; wrapper functions.  No, struct members can't be optional at this
;; point.
(cstruct dirent "struct dirent"
  ;; POSIX actually requires this to be d_ino
  (fileno "d_fileno" :type #-freebsd ino-t #+freebsd :uint32)
  (type   "d_type"   :type :uint8)
  (name   "d_name"   :type :uint8 :count :auto))

;;; filetypes set in d_type slot of struct dirent
(constant (dt-unknown "DT_UNKNOWN"))
(constant (dt-fifo "DT_FIFO"))
(constant (dt-chr "DT_CHR"))
(constant (dt-dir "DT_DIR"))
(constant (dt-blk "DT_BLK"))
(constant (dt-reg "DT_REG"))
(constant (dt-lnk "DT_LNK"))
(constant (dt-sock "DT_SOCK"))
(constant (dt-wht "DT_WHT"))


;;; ioctl()

(constant (fionbio "FIONBIO"))
(constant (fionread "FIONREAD"))


;;; from sys/resource.h

(ctype rlim-t "rlim_t")
(ctype id-t "id_t")

(cstruct rlimit "struct rlimit"
  (cur "rlim_cur" :type rlim-t)
  (max "rlim_max" :type rlim-t))

(cstruct rusage "struct rusage"
  (utime    "ru_utime"    :type timeval)
  (stime    "ru_stime"    :type timeval)
  (maxrss   "ru_maxrss"   :type :long)
  (ixrss    "ru_ixrss"    :type :long)
  (idrss    "ru_idrss"    :type :long)
  (isrss    "ru_isrss"    :type :long)
  (minflt   "ru_minflt"   :type :long)
  (majflt   "ru_majflt"   :type :long)
  (nswap    "ru_nswap"    :type :long)
  (inblock  "ru_inblock"  :type :long)
  (oublock  "ru_oublock"  :type :long)
  (msgsnd   "ru_msgsnd"   :type :long)
  (msgrcv   "ru_msgrcv"   :type :long)
  (nsignals "ru_nsignals" :type :long)
  (nvcsw    "ru_nvcsw"    :type :long)
  (nivcsw   "ru_nivcsw"   :type :long))

(constant (prio-process "PRIO_PROCESS"))
(constant (prio-pgrp "PRIO_PGRP"))
(constant (prio-user "PRIO_USER"))
(constant (rlim-infinity "RLIM_INFINITY"))
(constant (rusage-self "RUSAGE_SELF"))
(constant (rusage-children "RUSAGE_CHILDREN"))
(constant (rlimit-as "RLIMIT_AS"))
(constant (rlimit-core "RLIMIT_CORE"))
(constant (rlimit-cpu "RLIMIT_CPU"))
(constant (rlimit-data "RLIMIT_DATA"))
(constant (rlimit-fsize "RLIMIT_FSIZE"))
(constant (rlimit-memlock "RLIMIT_MEMLOCK"))
(constant (rlimit-nofile "RLIMIT_NOFILE"))
(constant (rlimit-nproc "RLIMIT_NPROC"))
(constant (rlimit-rss "RLIMIT_RSS"))
(constant (rlimit-stack "RLIMIT_STACK"))

#+linux
(progn
  (constant (rlim-saved-max "RLIM_SAVED_MAX"))
  (constant (rlim-saved-cur "RLIM_SAVED_CUR"))
  (constant (rlimit-locks "RLIMIT_LOCKS"))
  (constant (rlimit-msgqueue "RLIMIT_MSGQUEUE"))
  (constant (rlimit-nlimits "RLIMIT_NLIMITS"))
  (constant (rlimit-nice "RLIMIT_NICE"))
  (constant (rlimit-rtprio "RLIMIT_RTPRIO"))
  (constant (rlimit-sigpending "RLIMIT_SIGPENDING")))

#+freebsd
(constant (rlimit-sbsize "RLIMIT_SBSIZE"))


;;;; from sys/utsname.h

(cstruct utsname "struct utsname"
  (sysname  "sysname"  :type :char)
  (nodename "nodename" :type :char)
  (release  "release"  :type :char)
  (version  "version"  :type :char)
  (machine  "machine"  :type :char))


;;; from pwd.h

(cstruct passwd-entry "struct passwd"
  (name   "pw_name"   :type :string)
  (passwd "pw_passwd" :type :string)
  (uid    "pw_uid"    :type uid-t)
  (gid    "pw_gid"    :type gid-t)
  (gecos  "pw_gecos"  :type :string)
  (dir    "pw_dir"    :type :string)
  (shell  "pw_shell"  :type :string))


;;; from grp.h

(cstruct group-entry "struct group"
  (name   "gr_name"   :type :string)
  (passwd "gr_passwd" :type :string)
  (gid    "gr_gid"    :type gid-t)
  (mem    "gr_mem"    :type :pointer))
