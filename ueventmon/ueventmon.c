/*
 * Copyright (C) 2010, 2011 Alexey Roslyakov
 *
 * Author: Alexey Roslyakov <alexey.roslyakov@newsycat.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <errno.h>

#include <sys/socket.h>
#include <sys/un.h>
#include <linux/netlink.h>

#include <cutils/log.h>

#define UEVENT_BUFFER_SIZE 2048

/* Returns -1 on failure, and socket fd on success */
static int open_uevent()
{
	struct sockaddr_nl addr;
	int sz = UEVENT_BUFFER_SIZE;
	int s;

	memset(&addr, 0, sizeof(addr));
	addr.nl_family = AF_NETLINK;
	addr.nl_groups = 0xffffffff;

	/*
	*	netlink(7) on nl_pid:
 	*	If the application sets it to 0, the kernel takes care of assigning it.
	*	The  kernel assigns the process ID to the first netlink socket the process
	*	opens and assigns a unique nl_pid to every netlink socket that the
	*	process subsequently creates.
	*/
	addr.nl_pid = getpid();

	s = socket(PF_NETLINK, SOCK_DGRAM, NETLINK_KOBJECT_UEVENT);
	if(s < 0) {
		LOGE("%s socket failed: %s", __func__, strerror(errno));
		return -1;
	}

	setsockopt(s, SOL_SOCKET, SO_RCVBUFFORCE, &sz, sizeof(sz));

	if(bind(s, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
		LOGE("%s bind failed: %s", __func__, strerror(errno));
		close(s);
		return -1;
	}


	return s;
}

int uevent_next_event(int fd, char* buffer, int buffer_length)
{
	while (1) {
		struct pollfd fds;
		int nr;

		fds.fd = fd;
		fds.events = POLLIN;
		fds.revents = 0;
		nr = poll(&fds, 1, -1);
     
		if (nr > 0 && fds.revents == POLLIN) {
			int count = recv(fd, buffer, buffer_length, 0);
			if (count > 0) {
				return count;
			}
			LOGE("%s recv failed: %s", __func__, strerror(errno));
		}
	}
    
	// won't get here
	return 0;
}

int main(void)
{
	int fd = open_uevent();
	if (fd < 0)
		return -1;

	printf("Socket opened\n");

	static char buf[UEVENT_BUFFER_SIZE];
	char *s;

	while(1) {
		int count = uevent_next_event(fd, buf, sizeof(buf));
		if (!count)
			return -1;
		s = buf;
		printf( "%s\n", s);
		s += strlen(s) + 1;
		while (s < &buf[count]) {
			printf("  %s\n", s);
			s += strlen(s) + 1;
		}
	}

	return 0;
}

