extern int close(int fd);
int (*orig_close)(int fd) = 0;

int close(int fd)
{
	int old_errno=errno;
	int rc;

	if (!orig_close) orig_close = get_dl_symbol("close");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: going to run original close(%d) at %p (wrapper is at %p).\n",
		getpid(), fd, orig_close, close);
#  endif

	errno=old_errno;
	rc = orig_close(fd);
	old_errno=errno;

#  if FD_TRACKER == 1
	if (rc == 0 || errno == EBADF)
	{
		struct pid_reg *pidreg = *find_pid(getpid());
		if (pidreg)
		{
			struct fd_reg *fdreg = *find_fd(pidreg, fd);
			if (fdreg)
			{	
				handle_file_access_after("close", fdreg->filename, &fdreg->status);
				deregister_fd(fd);
			}
		}
	}
#  endif

	errno=old_errno;
	return rc;
}

extern int fclose(FILE* f);
int (*orig_fclose)(FILE* f) = 0;

int fclose(FILE* f)
{
	int old_errno=errno;
	int rc;
	int fd=fileno(f);

	if (!orig_fclose) orig_fclose = get_dl_symbol("fclose");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: going to run original fclose(%d) at %p (wrapper is at %p).\n",
		getpid(), fd, orig_fclose, fclose);
#  endif

	errno=old_errno;
	rc = orig_fclose(f);
	old_errno=errno;

#  if FD_TRACKER == 1
	if (rc == 0)
	{
		struct pid_reg *pidreg = *find_pid(getpid());
		if (pidreg)
		{
			struct fd_reg *fdreg = *find_fd(pidreg, fd);
			if (fdreg)
			{	
				handle_file_access_after("fclose", fdreg->filename, &fdreg->status);
				deregister_fd(fd);
			}
		}
	}
#  endif

	errno=old_errno;
	return rc;
}

/*
extern int fcloseall();
int (*orig_fcloseall)() = 0;

int fcloseall()
{
	int old_errno=errno;
	int rc;

	if (!orig_fcloseall) orig_fcloseall = get_dl_symbol("fcloseall");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: going to run original fcloseall() at %p (wrapper is at %p).\n",
		getpid(), orig_fcloseall, fcloseall);
#  endif

	errno=old_errno;
	rc = orig_fcloseall();

	return rc;
}
*/

extern int fork();
int (*orig_fork)() = 0;

int fork()
{
	int old_errno = errno;
	int rc;
#  if FD_TRACKER == 1
	int caller_pid = getpid();
#  endif

	if (!orig_fork) orig_fork = get_dl_symbol("fork");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: going to run original fork() at %p (wrapper is at %p).\n",
		getpid(), orig_fork, fork);
#  endif

	errno = old_errno;
	rc = orig_fork();
	old_errno = errno;

#  if FD_TRACKER == 1
	if ( rc == 0) copy_fds(caller_pid, getpid());
#  endif

#  if FD_TRACKER == 1
#    if DEBUG == 1
	struct pid_reg *pid = pid_head;
	while (pid)
	{
		struct fd_reg *fd = pid->fd_head;
		if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: fork: found PID %d.\n",
			getpid(), pid->id);
		while (fd)
		{
			if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: fork: found fd %d (%s).\n",
				getpid(), fd->fd, fd->filename);
			fd = fd->next;
		}
		pid = pid->next;
	}
#    endif
#  endif
	errno=old_errno;
	return rc;
}

extern void exit(int status) __attribute__ ((noreturn));
void (*orig_exit)(int status) __attribute__ ((noreturn)) = 0;

void exit(int status)
{
	int old_errno = errno;

	if (!orig_exit) orig_exit = get_dl_symbol("exit");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: going to run original exit(%d) at %p (wrapper is at %p).\n",
		getpid(), status, orig_exit, exit);
#  endif

#  if FD_TRACKER == 1
	struct pid_reg *pid = *find_pid(getpid());
	if (pid)
	{
		struct fd_reg *fd_iter = pid->fd_head;
		while (fd_iter)
		{
			struct fd_reg *new_fd_iter=fd_iter->next;
			handle_file_access_after("exit", fd_iter->filename, &fd_iter->status);
			deregister_fd(fd_iter->fd);
			fd_iter=new_fd_iter;
		}
	}
#  endif

	errno=old_errno;
	orig_exit(status);
}

extern void _exit(int status) __attribute__ ((noreturn));
void (*orig__exit)(int status) __attribute__ ((noreturn)) = 0;

void _exit(int status)
{
	int old_errno = errno;

	if (!orig__exit) orig__exit = get_dl_symbol("_exit");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: going to run original _exit(%d) at %p (wrapper is at %p).\n",
		getpid(), status, orig__exit, _exit);
#  endif

#  if FD_TRACKER == 1
	struct pid_reg *pid = *find_pid(getpid());
	if (pid)
	{
		struct fd_reg *fd_iter = pid->fd_head;
		while (fd_iter)
		{
			struct fd_reg *new_fd_iter=fd_iter->next;
			handle_file_access_after("_exit", fd_iter->filename, &fd_iter->status);
			deregister_fd(fd_iter->fd);
			fd_iter=new_fd_iter;
		}
	}
#  endif

	errno=old_errno;
	orig__exit(status);
}

extern void _Exit(int status) __attribute__ ((noreturn));
void (*orig__Exit)(int status) __attribute__ ((noreturn)) = 0;

void _Exit(int status)
{
	int old_errno = errno;

	if (!orig__Exit) orig__Exit = get_dl_symbol("_Exit");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: going to run original _Exit(%d) at %p (wrapper is at %p).\n",
		getpid(), status, orig__Exit, _Exit);
#  endif

#  if FD_TRACKER == 1
	struct pid_reg *pid = *find_pid(getpid());
	if (pid)
	{
		struct fd_reg *fd_iter = pid->fd_head;
		while (fd_iter)
		{
			struct fd_reg *new_fd_iter=fd_iter->next;
			handle_file_access_after("_Exit", fd_iter->filename, &fd_iter->status);
			deregister_fd(fd_iter->fd);
			fd_iter=new_fd_iter;
		}
	}
#  endif

	errno=old_errno;
	orig__Exit(status);
}
