cdef extern from "<fcntl.h>":
    int open(const char *pathname, int flags)
    int close(int fd)
    enum:
        O_RDONLY
        O_WRONLY
        O_RDWR

cdef extern from "<unistd.h>":
    int dup(int oldfd)
    int dup2(int oldfd, int newfd)

