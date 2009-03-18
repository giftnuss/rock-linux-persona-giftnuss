#include <stdio.h>
#include <libgen.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <glob.h>
#include <signal.h>

extern char **environ;

#define LIBDIR "/ROCK/tools.cross/pseudonative.lib"

#define BINDIR_1 "/ROCK/tools.cross/pseudonative.bin"
#define BINDIR_2 "/ROCK/tools.cross/bin"
#define BINDIR_SIZE 100

#define TCPPORT 28336

#define CMD_EXEC	1
#define CMD_ADDARG	2
#define CMD_ADDENV	3
#define CMD_CHDIR	4
#define CMD_CHROOT	5
#define CMD_EXIT	6
#define CMD_BUILDID	7
#define CMD_WRITE0   1000
#define CMD_CLOSE0   2000
#define CMD_ENABLE0  3000

int config_debug = 0;
int config_remote = 0;

struct pn_pkg {
	uint32_t len;
	uint32_t type;
	char data[];
};

int conn_open(const char *peer)
{
	struct sockaddr_in sin;
	int conn;

	sin.sin_family = PF_INET;
	sin.sin_port = htons(TCPPORT);

	if ( !inet_aton(peer, &sin.sin_addr) ) {
		fprintf(stderr, "pseudonative_handler: can't parse address '%s'\n", peer);
		exit(-1);
	}

	conn = socket(PF_INET, SOCK_STREAM, 0);
	if (conn < 0) {
		fprintf(stderr, "pseudonative_handler: can't create socket: %s\n", strerror(errno));
		exit(-1);
	}

	if (connect(conn, (struct sockaddr *)&sin, sizeof (sin)) < 0) {
		fprintf(stderr, "pseudonative_handler: can't connect to remote host: %s\n", strerror(errno));
		exit(-1);
	}

	return conn;
}

void conn_send(int conn, int len, int type, char *data)
{
	struct pn_pkg *p = malloc( sizeof(struct pn_pkg) + len );
	int i, rc;

	p->len = htonl(len);
	p->type = htonl(type);

	memcpy(p->data, data, len);

	len += sizeof(struct pn_pkg);
	for (i = 0; i < len; i += rc) {
		rc = write(conn, (char*)p + i, len - i);
		if ( rc <= 0 ) {
			if ( errno == ECONNRESET && type == CMD_CLOSE0 ) break;
			fprintf(stderr, "pseudonative_handler: network write error: %s\n", strerror(errno));
			exit(-1);
		}
	}

	free(p);
}

int conn_read(int conn, char *buf, int len, int nonblock)
{
	int f = -1;

	if ( nonblock ) {
		f = fcntl(conn, F_GETFL, 0);
		fcntl(conn, F_SETFL, f | O_NONBLOCK);
	}

        while (len) {
                int rc = read(conn, buf, len);
                if ( rc < 0 ) {
			if ( errno == EAGAIN ) break;
                        fprintf(stderr, "pseudonative_handler: network read error: %s\n", strerror(errno));
                        exit(-1);
                }
                if ( rc == 0 ) {
                        fprintf(stderr, "pseudonative_handler: connection closed by peer\n");
                        exit(-1);
		}
		if ( f != -1 )
			fcntl(conn, F_SETFL, f);
                len -= rc; buf += rc; f = -1;
        }

	if ( f != -1 )
		fcntl(conn, F_SETFL, f);
        return len;
}

struct pn_pkg *conn_recv(int conn)
{
        struct pn_pkg *p = malloc( sizeof(struct pn_pkg) );

        if ( conn_read(conn, (char*)p, 8, 1) ) {
                free(p);
                return 0;
        }

        p->len = ntohl(p->len);
        p->type = ntohl(p->type);

        p = realloc(p, sizeof(struct pn_pkg) + p->len);
        conn_read(conn, p->data, p->len, 0);

        return p;
}

int exec_remote(char ** argv)
{
	char buf[1024], *txt;
	int ret = -1, open_0 = 1;
	int enable_0 = 0;
	int f, i, conn, rc;
	struct timeval tv;
	struct pn_pkg *p;
	fd_set rfds;

	/* connect */
	txt = getenv("ROCKCFG_PSEUDONATIVE_NATIVEHOST");
	if ( txt && *txt ) {
		conn = conn_open(txt);
	} else {
		fprintf(stderr, "pseudonative_handler: no native host configured\n");
		exit(-1);
	}

	/* send build id */
	txt = getenv("ROCKCFG_ID");
	if ( txt && *txt )
		conn_send(conn, strlen(txt)+1, CMD_BUILDID, txt);

	/* mount and chroot */
	txt = getenv("ROCKCFG_PSEUDONATIVE_NFSROOT");
	if ( txt && *txt )
		conn_send(conn, strlen(txt)+1, CMD_CHROOT, txt);

	/* current directory */
	if ( getcwd(buf, 1024) )
		conn_send(conn, strlen(buf)+1, CMD_CHDIR, buf);

	/* send environment */
	for (i=0; environ[i]; i++)
		conn_send(conn, strlen(environ[i])+1, CMD_ADDENV, environ[i]);

	/* send arguments */
	for (i=0; argv[i]; i++)
		conn_send(conn, strlen(argv[i])+1, CMD_ADDARG, argv[i]);

	/* execute command */
	conn_send(conn, strlen(argv[0])+1, CMD_EXEC, argv[0]);

	/* we pass sigpipe's to peer */
	signal(SIGPIPE, SIG_IGN);

	while (1)
	{
		FD_ZERO(&rfds);
		if ( open_0 && enable_0 ) FD_SET(0, &rfds);
		FD_SET(conn, &rfds);

nextselect:
		tv.tv_sec = 1;
		tv.tv_usec = 0;
		rc = select(conn+1, &rfds, 0, 0, &tv);

		if ( rc < 0 ) {
			if ( errno == EINTR ) goto nextselect;
			fprintf(stderr, "pseudonative_handler: select error: %s\n", strerror(errno));
			exit(-1);
		}

nextread:
		if ( (p = conn_recv(conn)) != 0 ) {
			char *d = p->data;

			switch (p->type) {
			case CMD_WRITE0+1:
				while ( p->len ) {
					rc = write(1, d, p->len);
					if ( rc <= 0 ) {
						if ( errno == EPIPE ) {
							conn_send(conn, 0, CMD_CLOSE0+1, 0);
							break;
						}
						fprintf(stderr, "pseudonative_handler: write error on fd1: %s\n", strerror(errno));
						exit(-1);
					}
					d += rc; p->len -= rc;
				}
				break;
			case CMD_WRITE0+2:
				while ( p->len ) {
					rc = write(2, d, p->len);
					if ( rc <= 0 ) {
						if ( errno == EPIPE ) {
							conn_send(conn, 0, CMD_CLOSE0+2, 0);
							break;
						}
						fprintf(stderr, "pseudonative_handler: write error on fd2: %s\n", strerror(errno));
						exit(-1);
					}
					d += rc; p->len -= rc;
				}
				break;
			case CMD_CLOSE0:
				close(0);
				open_0 = 0;
				break;
			case CMD_CLOSE0+1:
				close(1);
				break;
			case CMD_CLOSE0+2:
				close(2);
				break;
			case CMD_ENABLE0:
				enable_0 = 1;
				break;
			case CMD_EXIT:
				ret = (unsigned char)p->data[0];
				free(p);
				goto finish;
			}
			free(p);
			goto nextread;
                }

                if( open_0 && enable_0 )
                {
			f = fcntl(0, F_GETFL, 0);
			fcntl(0, F_SETFL, f | O_NONBLOCK);

                        rc = read(0, buf, 512);

			fcntl(0, F_SETFL, f);

                        if ( rc > 0 ) {
                                conn_send(conn, rc, CMD_WRITE0, buf);
                                goto nextread;
                        } else if (rc == 0) {
                                conn_send(conn, 0, CMD_CLOSE0, 0);
				open_0 = 0;
                        } else if ( errno != EAGAIN ) {
                                perror("Error on read from f2:");
                        }
		}
	}

finish:
	close(conn);

	if (ret == -1)
		fprintf(stderr, "pseudonative_handler: sometimes everything goes wrong\n");

	return ret;
}

void set_ld_lib_path()
{
	FILE *f = fopen("/etc/ld.so.conf", "r");
	char ld_lib_path[1024] = "/lib";
	int written = 4, len, i;
	char line[1024], *l;
	glob_t globbuf;

	l = getenv("LD_LIBRARY_PATH_PSEUDONATIVE_BACKUP");
	if (l) {
		l = strdup(l);
		l = strtok(l, ":");
		while ( l ) {
			if ( strcmp(l, LIBDIR) && written < 1024)
				written += snprintf(ld_lib_path+written, 1024-written, ":%s", l);
			l = strtok(0, ":");
		}
		unsetenv("LD_LIBRARY_PATH_PSEUDONATIVE_BACKUP");
	}

	if (f) {
		while ( (l=fgets(line, 1024, f)) ) {
			while ( *l == ' ' || *l == '\t' || *l == '\n' ) l++;
			if ( *l == '#' || !*l ) continue;

			len = strcspn(l, "\t\n ");
			if (len) {
				l[len] = 0;
				glob(l, GLOB_ONLYDIR, 0, &globbuf);
				for (i=0; i<globbuf.gl_pathc && written < 1024; i++)
					written += snprintf(ld_lib_path+written, 1024-written, ":%s", globbuf.gl_pathv[i]);
				globfree (&globbuf);
			}
		}
		fclose(f);
	}

	if (config_debug)
		fprintf(stderr, "pseudonative_handler: setting LD_LIBRARY_PATH: %s\n", ld_lib_path);

	setenv("LD_LIBRARY_PATH", ld_lib_path, 1);
}

void write_log(char *type, char **argv)
{
	int written = 0;
	char line[120] = "";
	FILE *f;

	if ( (f = fopen("/var/adm/rock-debug/pseudonative.log", "a")) ) {
		written += snprintf(line+written, 1024-written, "%s: %s=%s",
				type, getenv("ROCK_PKG"), getenv("ROCK_XPKG"));
		while (*argv && written < 120)
			written += snprintf(line+written, 120-written, " %s", *(argv++));
		strcpy(line+100, " ..");
		fprintf(f, "%s\n", line);
		fclose(f);
	}
}

int main(int argc, char **argv)
{
	char *cmd, *mycmd, *t;

	while ( *argv[1] == '-' && argc > 1 ) {
		if ( !strcmp(argv[1], "-d") ) config_debug = 1;
		else if ( !strcmp(argv[1], "-r") ) config_remote = 1;
		else {
			fprintf(stderr, "pseudonative_handler: unknown option %s.\n", argv[1]);
			return -1;
		}
		argv++; argc--;
	}

	if (argc < 2) {
		fprintf(stderr, "pseudonative_handler: arguments missing.\n");
		return -1;
	}

	cmd = basename(argv[1]);
	mycmd = malloc(BINDIR_SIZE+strlen(cmd)+10);

	t = getenv("LD_LIBRARY_PATH");
	if ( t && strcmp(t, LIBDIR) )
		setenv("LD_LIBRARY_PATH_PSEUDONATIVE_BACKUP", t, 1);
	setenv("LD_LIBRARY_PATH", LIBDIR, 1);

	/* The target ld.so.cache would confuse bins for the build host. So
	 * we unlink it here and generate a LD_LIBRARY_PATH from ld.so.conf
	 * for bins executed on the remote machine. */
	unlink("/etc/ld.so.cache");

	sprintf(mycmd, "%s/%s", BINDIR_1, cmd);
	if ( !access(mycmd, X_OK) && !config_remote ) {
		if (config_debug)
			fprintf(stderr, "pseudonative_handler: local: %s\n", mycmd);
		argv[1] = mycmd;
		write_log("local", argv+1);
		execv(mycmd, argv+1);
		goto goterror;
	}

	sprintf(mycmd, "%s/%s", BINDIR_2, cmd);
	if ( !access(mycmd, X_OK) && !config_remote ) {
		if (config_debug)
			fprintf(stderr, "pseudonative_handler: local: %s\n", mycmd);
		argv[1] = mycmd;
		write_log("local", argv+1);
		execv(mycmd, argv+1);
		goto goterror;
	}

	/* FIXME: CMD_ENABLE0 doesn't work correctly yet (see pseudonative_daemon.c).
	 * So we close fd0 explicitely for some programs here. */
#if 0
	if ( !strcmp(cmd, "tput") ) { close(0); open("/dev/null", O_RDONLY); }
#endif

	set_ld_lib_path();
	if (config_debug)
		fprintf(stderr, "pseudonative_handler: remote: %s\n", argv[1]);
	write_log("remote", argv+1);
	return exec_remote(argv+1);

goterror:
	fprintf(stderr, "pseudonative_handler: error calling '%s': %s\n", mycmd, strerror(errno));
	return -1;
}

