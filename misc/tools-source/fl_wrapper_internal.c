/* Internal Functions */

static void * get_dl_symbol(char * symname)
{
	void * rc;
#if DLOPEN_LIBC
	static void * libc_handle = 0;

	if (!libc_handle) libc_handle=dlopen("libc.so.6", RTLD_LAZY);
	if (!libc_handle) {
		printf("fl_wrapper.so: Can't dlopen libc: %s\n", dlerror());
		abort();
	}

        rc = dlsym(libc_handle, symname);
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: Symbol '%s' in libc (%p) has been resolved to %p.\n",
		getpid(), symname, libc_handle, rc);
#  endif
#else
        rc = dlsym(RTLD_NEXT, symname);
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: Symbol '%s' (RTLD_NEXT) has been resolved to %p.\n",
		getpid(), symname, rc);
#  endif
#endif
	if (!rc) {
		printf("fl_wrapper.so: Can't resolve %s: %s\n",
		       symname, dlerror());
		abort();
	}

        return rc;
}

extern int open(const char* f, int a, ...);

static int pid2ppid(int pid)
{
	char buffer[100];
	int fd, rc, ppid = 0;

	if (!orig_open) orig_open = get_dl_symbol("open");
	if (!orig_close) orig_close = get_dl_symbol("close");

	sprintf(buffer, "/proc/%d/stat", pid);
	if ( (fd = orig_open(buffer, O_RDONLY, 0)) < 0 ) return 0;
	if ( (rc = read(fd, buffer, 99)) > 0) {
		buffer[rc] = 0;
		/* format: 27910 (bash) S 27315 ... */
		sscanf(buffer, "%*[^ ] %*[^ ] %*[^ ] %d", &ppid);
	}
	orig_close(fd);

	return ppid;
}

/* this is only called from fl_wrapper_init(). so it doesn't need to be
 * reentrant. */
static char *getpname(int pid)
{
	static char p[512];
	char buffer[513]="";
	char *arg=0, *b;
	int i, fd, rc;

	sprintf(buffer, "/proc/%d/cmdline", pid);
	if ( (fd = orig_open(buffer, O_RDONLY, 0)) < 0 ) return "unkown";
	if ( (rc = read(fd, buffer, 512)) > 0) {
		buffer[rc--] = 0;
		for (i=0; i<rc; i++)
			if (buffer[i] == 0 && buffer[i+1] != '-')
				{ arg = buffer+i+1; break; }
	}
	orig_close(fd);

	b = basename(buffer);
	snprintf(p, 512, "%s", b);

	if ( !strcmp(b, "bash") || !strcmp(b, "sh") ||
	     !strcmp(b, "perl") || !strcmp(b, "python") )
		if ( arg && *arg &&
		     strlen(arg) < 100 && !strchr(arg, '\n') &&
		     !strchr(arg, ' ') && !strchr(arg, ';') )
			snprintf(p, 512, "%s(%s)", b, basename(arg));

	return p;
}

/* invert the order by recursion. there will be only one recursion tree
 * so we can use a static var for managing the last ent */
static void addptree(int *txtpos, char *cmdtxt, int pid, int basepid)
{
	static char l[512] = "";
	char *p;

	if (!pid || pid == basepid) return;

	addptree(txtpos, cmdtxt, pid2ppid(pid), basepid);

	p = getpname(pid);

	if (*txtpos < 4000)
	{
		if ( strcmp(l, p) )
			*txtpos += snprintf(cmdtxt+*txtpos, 4096-*txtpos, "%s%s",
					*txtpos ? "." : "", getpname(pid));
		else
			*txtpos += snprintf(cmdtxt+*txtpos, 4096-*txtpos, "*");
	}

	strcpy(l, p);
}

void __attribute__ ((constructor)) fl_wrapper_init()
{
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: fl_wrapper_init()\n", getpid());
#  endif

	char cmdtxt[4096] = "";
	char *basepid_txt = getenv("FLWRAPPER_BASEPID");
	int basepid = 0, txtpos=0;

	if (basepid_txt)
		basepid = atoi(basepid_txt);

	addptree(&txtpos, cmdtxt, getpid(), basepid);
	cmdname = strdup(cmdtxt);

	wlog = getenv("FLWRAPPER_WLOG");
	rlog = getenv("FLWRAPPER_RLOG");
#  if DEBUG == 1
	char *debugwrapper = getenv("FLWRAPPER_DEBUG");
	if (debugwrapper) debug = atoi(debugwrapper);
#  endif
}

/*
	Clean up file descriptors still registered for this pid, if any.
*/
void __attribute__ ((destructor)) fl_wrapper_finish()
{
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: fl_wrapper_finish()\n", getpid());
#  endif
#  if FD_TRACKER == 1
	struct pid_reg **pid = find_pid(getpid());
	if (*pid)
	{
#    if DEBUG == 1
		if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: PID still registered!\n", getpid());
#    endif
		struct fd_reg **fd = &(*pid)->fd_head;
		while (*fd)
		{
			handle_file_access_after("fl_wrapper_finish", (*fd)->filename, &(*fd)->status);
			remove_fd(fd);
		}
		remove_pid(pid);
	}
#  endif
}

static void handle_file_access_before(const char * func, const char * file,
                               struct status_t * status)
{
	struct stat st;
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: begin of handle_file_access_before(\"%s\", \"%s\", xxx)\n",
		getpid(), func, file);
#  endif
	if ( lstat(file,&st) ) {
		status->inode=0;  status->size=0;
		status->mtime=0;  status->ctime=0;
	} else {
		status->inode=st.st_ino;    status->size=st.st_size;
		status->mtime=st.st_mtime;  status->ctime=st.st_ctime;
	}
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: end   of handle_file_access_before(\"%s\", \"%s\", xxx)\n",
		getpid(), func, file);
#  endif
}

/*
	Declared in fl_wrapper_open.c and fl_wrapper_close.c,
	reused here since logging access to the log files eventually
	overwrites close'd but not yet deregistered file descriptors.

int (*orig_open)(const char* f, int a, ...) = 0;
int (*orig_open64)(const char* f, int a, ...) = 0;
int (*orig_close)(int fd) = 0;
*/

static void handle_file_access_after(const char * func, const char * file,
                              struct status_t * status)
{
	char buf[512], *buf2, *logfile;
	int fd; struct stat st;

#ifdef __USE_LARGEFILE
	if (!orig_open64) orig_open64 = get_dl_symbol("open64");
#else
	if (!orig_open) orig_open = get_dl_symbol("open");
#endif
	if (!orig_close) orig_close = get_dl_symbol("close");
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: begin of handle_file_access_after(\"%s\", \"%s\", xxx), %d, %s, %s\n",
		getpid(), func, file, status != 0, wlog, rlog);
#  endif

	if ( lstat(file, &st) )
	{
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: lstat(%s, ...) failed\n",
		getpid(), file);
#  endif
	 return;
	}

	if ( (status != 0) && (status->inode != st.st_ino ||
	     status->size  != st.st_size || status->mtime != st.st_mtime ||
	     status->ctime != st.st_ctime) ) { logfile = wlog; }
	else { logfile = rlog; }

	if ( logfile == 0 ) 
	{
#  if DEBUG == 1
		if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: no log file\n",
			getpid());
#  endif
		return;
	}

#ifdef __USE_LARGEFILE
	fd=orig_open64(logfile,O_APPEND|O_WRONLY|O_LARGEFILE,0);
#else
#warning "The wrapper library will not work properly for large logs!"
	fd=orig_open(logfile,O_APPEND|O_WRONLY,0);
#endif

	if (fd == -1)
	{
#  if DEBUG == 1
		if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: log open failed (%s)\n",
			getpid(), strerror(errno));
#  endif
		return;
	}

	if (file[0] == '/') {
		sprintf(buf,"%s.%s:\t%s\n",
		        cmdname, func, file);
	} else {
		buf2=get_current_dir_name();
		sprintf(buf,"%s.%s:\t%s%s%s\n",
			cmdname, func, buf2,
			strcmp(buf2,"/") ? "/" : "", file);
		free(buf2);
	}
	write(fd,buf,strlen(buf));
	orig_close(fd);
#  if DEBUG == 1
	if (debug) fprintf(stderr, "fl_wrapper.so debug [%d]: end   of handle_file_access_after(\"%s\", \"%s\", xxx)\n",
		getpid(), func, file);
#  endif
}
