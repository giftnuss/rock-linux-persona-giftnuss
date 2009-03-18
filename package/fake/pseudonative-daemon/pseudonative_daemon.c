#include <stdint.h>
#include <errno.h>
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <string.h>
#include <fcntl.h>

#define TCPPORT 28336

#define CMD_EXEC        1
#define CMD_ADDARG      2
#define CMD_ADDENV      3
#define CMD_CHDIR       4
#define CMD_CHROOT      5
#define CMD_EXIT        6
#define CMD_BUILDID     7
#define CMD_WRITE0   1000
#define CMD_CLOSE0   2000
#define CMD_ENABLE0  3000

struct pn_pkg {
        uint32_t len;
        uint32_t type;
        char data[];
};

struct sbuf;
struct sbuf {
	struct sbuf *next;
	int len, c;
	struct pn_pkg *p;
	char *d;
};

struct sbuf *recv4p = 0;
struct sbuf *send2p = 0;
int sbuf_c = 0;

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
                        fprintf(stderr, "network write error: %s\n", strerror(errno));
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
                        fprintf(stderr, "network read error: %s\n", strerror(errno));
                        exit(-1);
                }
		if ( rc == 0 ) {
                        fprintf(stderr, "connection closed by peer\n");
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

struct pn_pkg *conn_recv(int conn, int nonblock)
{
        struct pn_pkg *p = malloc( sizeof(struct pn_pkg) );

	if ( conn_read(conn, (char*)p, 8, nonblock) ) {
		free(p);
		return 0;
	}

        p->len = ntohl(p->len);
        p->type = ntohl(p->type);

	p = realloc(p, sizeof(struct pn_pkg) + p->len);
	conn_read(conn, p->data, p->len, 0);

	return p;
}

void do_chroot(char *d, char *b)
{
	char buf[1024];
	char *e = malloc(strlen(d)+strlen(b)+2);
	int i;
	
	sprintf(e, "%s:%s", d, b);
	for (i=0; e[i]; i++) if ( e[i] == '/' ) e[i] = '_';
	snprintf(buf, 1024, "%s/pseudonative_handler", e);

	if ( access(buf, F_OK) ) {
		mkdir(e, 0700);
		snprintf(buf, 1024, "mount -t nfs -o noac %s/build/%s %s", d, b, e);
		system(buf);
		snprintf(buf, 1024, "mount -t nfs -o noac %s %s/ROCK/loop", d, e);
		system(buf);
		snprintf(buf, 1024, "mount -t nfs -o noac %s/config %s/ROCK/config", d, e);
		system(buf);
		snprintf(buf, 1024, "mount -t nfs -o noac %s/download %s/ROCK/download", d, e);
		system(buf);
		snprintf(buf, 1024, "mount -t proc proc %s/proc", e);
		system(buf);
	}

	chdir(e);
	chroot(".");

	free(e);
}

void do_session(int conn)
{
	char *argv[1024], *bid="", *exe = "/bin/true";
	int f0[2], f1[2], f2[2], m, f, argc = 0;
	int open_0 = 1, open_1 = 1, open_2 = 1;
	int schedule_close_0 = 0, enable_0 = 0;
	unsigned char retval;
	struct timeval tv;
	fd_set rfds, wfds;
	struct pn_pkg *p;

	clearenv();
	signal(SIGCHLD, SIG_DFL);
	signal(SIGPIPE, SIG_IGN);

	while (1) {
		if ( (p = conn_recv(conn, 0)) == 0 ) {
                        fprintf(stderr, "\nnetwork read error: EOF\n");
                        exit(-1);
		}

		switch (p->type) {
		case CMD_EXEC:
			printf("\nEXE: %s", p->data);
			exe = strdup(p->data);
			break;
		case CMD_ADDARG:
			printf(m == p->type ? " %s" : "\nARG: %s", p->data);
			argv[argc++] = strdup(p->data);
			break;
		case CMD_ADDENV:
			printf(m == p->type ? "." : "\nENV: .");
			putenv(strdup(p->data));
			break;
		case CMD_CHDIR:
			printf("\nCHD: %s", p->data);
			chdir(p->data);
			break;
		case CMD_BUILDID:
			bid = strdup(p->data);
			break;
		case CMD_CHROOT:
			printf("\nMNT: %s %s", p->data, bid);
			do_chroot(p->data, bid);
			break;
		}

		if ((m=p->type) == CMD_EXEC) {
			free(p);
			break;
		}

		free(p);
	}

	pipe(f0);
	pipe(f1);
	pipe(f2);

	printf("\n");
	fflush(stderr);
	fflush(stdout);

	if (!fork()) {
		dup2(f0[0], 0); close(f0[0]); close(f0[1]);
		dup2(f1[1], 1); close(f1[0]); close(f1[1]);
		dup2(f2[1], 2); close(f2[0]); close(f2[1]);
		signal(SIGPIPE, SIG_DFL);

		argv[argc] = 0;
		execv(exe, argv);
		fprintf(stderr, "Can't execute %s: %s\n", exe, strerror(errno));
		exit(-1);
	}

	close(f0[0]);
	close(f1[1]);
	close(f2[1]);

	/* This is usefull for reading strace dumps, etc. */
#if 0
	printf("FDS: fd0=%d, fd1=%d, fd2=%d, conn=%d\n",
		f0[1], f1[0], f2[0], conn);
#endif

	f = fcntl(f0[1], F_GETFL, 0);
	fcntl(f0[1], F_SETFL, f | O_NONBLOCK);

	f = fcntl(f1[0], F_GETFL, 0);
	fcntl(f1[0], F_SETFL, f | O_NONBLOCK);

	f = fcntl(f2[0], F_GETFL, 0);
	fcntl(f2[0], F_SETFL, f | O_NONBLOCK);

	while (open_1 || open_2) 
	{
		char buf[512];
		int rc;

		FD_ZERO(&rfds);
		FD_ZERO(&wfds);

		m = f0[1];
		if ( conn  > m ) m = conn; FD_SET(conn,  &rfds);
		if ( open_1 ) { if ( f1[0] > m ) m = f1[0]; FD_SET(f1[0], &rfds); }
		if ( open_2 ) { if ( f2[0] > m ) m = f2[0]; FD_SET(f2[0], &rfds); }

		write(1, "?", 1);

		tv.tv_sec = 1;
		tv.tv_usec = 0;

		if ( schedule_close_0 < 2 && (send2p || !enable_0) ){
			FD_SET(f0[1], &wfds);
			rc = select(m+1, &rfds, &wfds, 0, &tv);
		} else
			rc = select(m+1, &rfds, 0, 0, &tv);

		if ( rc < 0 && errno != EINTR ) {
                        fprintf(stderr, "select error: %s\n", strerror(errno));
                        exit(-1);
		}

		/* FIXME: This should only be triggered if the proc is actually
		 * sleeping (read(), poll(), select(), etc) on input */
		if ( !enable_0 && FD_ISSET(f0[1], &wfds) ) {
			write(1, "E", 1);
			conn_send(conn, 0, CMD_ENABLE0, 0);
			enable_0 = 1;
		}

nextread:
		if ( schedule_close_0 == 2 )
			goto skip_send2p;

		while ( send2p )
		{
			struct sbuf *t;

			while ( send2p->len > 0 ) {
				rc = write(f0[1], send2p->d, send2p->len);
				if ( rc <= 0 ) {
					if ( errno == EAGAIN ) goto skip_send2p;
					if ( errno == EPIPE ) {
						write(1, "[P]", 3);
						conn_send(conn, 0, CMD_CLOSE0, 0);
						schedule_close_0 = 2;
						goto skip_send2p;
					}
					fprintf(stderr, "write error (%d): %s\n", f0[1], strerror(errno));
					exit(-1);
				}
				send2p->len -= rc;
				send2p->d += rc;
				fflush(stdout);
			}

			write(1, "X", 1);

			send2p = (t = send2p)->next;
			free(t->p); free(t);
		}
		if ( !send2p ) {
			recv4p = 0;
			if ( schedule_close_0 ) {
				schedule_close_0 = 2;
				write(1, "[X]", 3);
				close(f0[1]);
			}
		}
skip_send2p:;

		if ( (p = conn_recv(conn, 1)) ) {
			if ( p->type == CMD_WRITE0 && open_0 ) {
				struct sbuf *t = malloc(sizeof(struct sbuf));

				t->next = 0;
				t->p = p;
				t->len = p->len;
				t->d = p->data;
				t->c = sbuf_c++;

				if ( recv4p )
					recv4p->next = t;
				else
					send2p = t;
				recv4p = t;

				write(1, "0", 1);

				goto nextread;
			}
			if ( p->type == CMD_CLOSE0 ) {
				write(1, "[0]", 3);
				if ( !schedule_close_0 )
					schedule_close_0 = 1;
				open_0 = 0;
			}
			if ( p->type == CMD_CLOSE0+1 ) {
				write(1, "[P1]", 4);
				close(f1[0]);
				open_1 = 0;
			}
			if ( p->type == CMD_CLOSE0+2 ) {
				write(1, "[P2]", 4);
				close(f2[0]);
				open_2 = 0;
			}
			free(p);
			goto nextread;
		}

		if( open_1 )
		{
			rc = read(f1[0], buf, 512);
			if ( rc > 0 ) {
				write(1, "1", 1);
				conn_send(conn, rc, CMD_WRITE0+1, buf);
				goto nextread;
			} else if (rc == 0) {
				write(1, "[1]", 3);
				conn_send(conn, 0, CMD_CLOSE0+1, 0);
				open_1 = 0;
			} else if ( errno != EAGAIN ) {
				perror("Error on read from f1:");
			}
		} 

		if( open_2 )
		{
			rc = read(f2[0], buf, 512);
			if ( rc > 0 ) {
				write(1, "2", 1);
				conn_send(conn, rc, CMD_WRITE0+2, buf);
				goto nextread;
			} else if (rc == 0) {
				write(1, "[2]", 3);
				conn_send(conn, 0, CMD_CLOSE0+2, 0);
				open_2 = 0;
			} else if ( errno != EAGAIN ) {
				perror("Error on read from f2:");
			}
		} 
	}

	write(1, "\n", 1);

	wait(&m);
	retval = WEXITSTATUS(m);
	conn_send(conn, 1, CMD_EXIT, &retval);
	printf("RET: %d\n", retval);
}

int main(int argc, char **argv)
{
        struct sockaddr_in addr;
        int listenfd, fd;

	printf("\n");
	printf("**********************************************************************\n");
	printf("*                                                                    *\n");
	printf("*   ROCK Linux Pseudo-Native Daemon               by Clifford Wolf   *\n");
	printf("*                                                                    *\n");
	printf("*  This daemon will create subdirectories in the current working     *\n");
	printf("*  directory and mount NFS shares there. There is no authentication  *\n");
	printf("*  implemented - so everyone who can reach the TCP port can also     *\n");
	printf("*  execute commands. So secure the port using iptables!              *\n");
	printf("*                                                                    *\n");
	printf("**********************************************************************\n");
	printf("\n");

        signal(SIGCHLD, SIG_IGN);

        if ( (listenfd=socket(AF_INET, SOCK_STREAM, 0)) == -1 ) {
		fprintf(stderr, "socket: %s\n", strerror(errno));
		return 1;
	}

        bzero(&addr,sizeof(addr));
        addr.sin_family=AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(TCPPORT);

        if ( bind(listenfd, (struct sockaddr *)&addr, sizeof(addr)) == -1 ) {
		fprintf(stderr, "bind: %s\n", strerror(errno));
		return 1;
	}

        if ( listen(listenfd, 5) == -1 ) {
		fprintf(stderr, "listen: %s\n", strerror(errno));
		return 1;
	}

	printf("Listening on TCP port %d ...\n", TCPPORT);
        while (1) {
                if ( (fd=accept(listenfd, NULL, NULL)) == -1 ) {
			fprintf(stderr, "accept: %s\n", strerror(errno));
			return 1;
		}
                if ( !fork() ) {
                        fprintf(stderr, "\nconnection %d opened.", (int)getpid());
                        do_session(fd);
                        return 0;
                } else close(fd);
        }

        return 0;
}

