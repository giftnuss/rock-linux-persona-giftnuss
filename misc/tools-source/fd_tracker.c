
/*
	maybe TODO:
	wrape clone(); catch termination of child process created with clone()
*/

#  if FD_TRACKER == 1

/*
	
	Whenever a new file descriptor is opened, it will/should be added to the
	fl_wrapper-internal register, together with its current file status.
	Accordingly, when a file descriptor is closed, it will be removed from this
	register, and handle_file_access_after() will be called with the stored
	filename and status.
*/

struct pid_reg
{
	pid_t id;
	int executed;
	struct fd_reg *fd_head;
	struct pid_reg *next;
};

struct pid_reg *pid_head = 0;

struct fd_reg
{
	int fd;
	int closed;
	struct status_t status;
	char *filename;
	struct fd_reg *next;
};

void add_pid(pid_t pid)
{
	struct pid_reg *newpid = malloc(sizeof(struct pid_reg));

	newpid->id = pid;
	newpid->fd_head = 0;
	newpid->executed = 0;

	newpid->next = pid_head;
	pid_head = newpid;

#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: PID %d added.\n",
		getpid(), pid);
#  endif
}

void add_fd(struct pid_reg *pid, int fd, const char *filename, struct status_t *status)
{
	struct fd_reg *newfd = malloc(sizeof(struct fd_reg));

	newfd->fd = fd;
	newfd->closed = 0;
	newfd->status = *status;
	newfd->filename = strdup(filename);

	newfd->next = pid->fd_head;
	pid->fd_head = newfd;

#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: fd %d (%s) added.\n",
		getpid(), fd, filename);
#  endif
}

void remove_fd(struct fd_reg **fd);

void remove_pid(struct pid_reg **pid)
{
	struct pid_reg *tmp = *pid;
	struct fd_reg **fd_iter = &(*pid)->fd_head; 

#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: PID %d removed.\n",
		getpid(), (*pid)->id);
#  endif

	while (*fd_iter) remove_fd(fd_iter);
	*pid = (*pid)->next;
	free(tmp);
}

void remove_fd(struct fd_reg **fd)
{
	struct fd_reg *tmp = *fd;

#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: fd %d (%s) removed.\n",
		getpid(), (*fd)->fd, (*fd)->filename);
#  endif

	free((*fd)->filename);
	*fd = (*fd)->next;
	free(tmp);
}

void deregister_fd(int fd);

struct pid_reg **find_pid(pid_t pid)
{
	struct pid_reg **pid_iter = &pid_head;

	while (*pid_iter)
	{
		if ((*pid_iter)->executed)
		{
			struct fd_reg **fd_iter = &(*pid_iter)->fd_head;
			while (*fd_iter)
			{
				if ((*fd_iter)->closed)
				{
					handle_file_access_after("exec*", (*fd_iter)->filename, &(*fd_iter)->status);
					deregister_fd((*fd_iter)->fd);

				}
				else fd_iter = &(*fd_iter)->next;
			}
		}

		if ((*pid_iter)->fd_head == 0) remove_pid(pid_iter);
		else pid_iter = &(*pid_iter)->next;
	}

	pid_iter = &pid_head;
	while (*pid_iter)
	{
		if ((*pid_iter)->id == pid) break;
		pid_iter = &(*pid_iter)->next;
	}

	return pid_iter;
}

struct fd_reg **find_fd(struct pid_reg *pid, int fd)
{
	struct fd_reg **fd_iter = &pid->fd_head;
	while (*fd_iter)
	{
		if ((*fd_iter)->fd == fd) break;
		fd_iter = &(*fd_iter)->next;
	}

	return fd_iter;
}

void register_fd(int fd, const char *filename, struct status_t *status)
{
	struct pid_reg *pid_iter = *find_pid(getpid());
	if (pid_iter == 0)
	{
		add_pid(getpid());
		pid_iter = pid_head;
	}

	struct fd_reg *fd_iter = *find_fd(pid_iter, fd);
	if (fd_iter == 0)
	{
		add_fd(pid_iter, fd, filename, status);
	} else {
#  if DEBUG == 1
		if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: fd %d already registered (is %s, was %s).\n",
			getpid(), fd, filename, fd_iter->filename);
#  endif
		free(fd_iter->filename);
		fd_iter->filename = strdup(filename);
		fd_iter->status = *status;
	}
}

/* removes fd from register, returning its filename and status via filename
   and status arguments.
*/
void deregister_fd(int fd)
{
	struct pid_reg **pid_iter = find_pid(getpid());
	if (*pid_iter)
	{
		struct fd_reg **fd_iter = find_fd(*pid_iter, fd);
		if (*fd_iter)
		{
			remove_fd(fd_iter);
			if ((*pid_iter)->fd_head == 0) remove_pid(pid_iter);
		}
	}
}

void copy_fds(pid_t parent, pid_t child)
{
	struct pid_reg *pid_iter = *find_pid(parent);
	if (pid_iter)
	{
		struct fd_reg *fd_iter = pid_iter->fd_head;

		add_pid(child);
		struct fd_reg **nextfd = &pid_head->fd_head;

		while (fd_iter)
		{
			*nextfd = malloc(sizeof(struct fd_reg));
			**nextfd = *fd_iter;
			nextfd = &(*nextfd)->next;
			fd_iter = fd_iter->next;
		}
	}
}

#  endif
