/*
 * Copyright (C) 2014 Mozilla Foundation
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

#include <sys/resource.h> // for prlimit
#include <string.h> // for strcmp
#include <stdlib.h> // for atoi
#include <stdio.h> // for printf
#include <errno.h> // for errno
#include <dirent.h> // for opendir, readdir, etc

struct b2g_rlimit64 {
  uint64_t rlim_cur;
  uint64_t rlim_max;
};

int b2g_prlimit64(pid_t, int, const struct b2g_rlimit64*, struct b2g_rlimit64*) __asm__("b2g_prlimit64");

extern "C" int __set_errno(int n)
{
  errno = n;
  return -1;
}

static void b2g_prlimit_helper(pid_t pid, int code, const struct b2g_rlimit64* wval, struct b2g_rlimit64* rval)
{
  if (b2g_prlimit64(pid, RLIMIT_CORE, wval, rval) < 0) {
    printf("b2g-prlimit: failed to set %d for pid %d: %s (%d)\n", code, pid, strerror(errno), errno);
  }
}

int main(int argc, char **argv)
{
  if (argc == 5) {
    if (strcmp(argv[2], "core") == 0) {
      struct b2g_rlimit64 lim;
      pid_t pid;
      memset(&lim, 0, sizeof(lim));
      lim.rlim_cur = (rlim_t)atoi(argv[3]);
      lim.rlim_max = (rlim_t)atoi(argv[4]);
      pid = (pid_t)atoi(argv[1]);
      if (pid) {
        b2g_prlimit_helper(pid, RLIMIT_CORE, &lim, NULL);
      } else {
        /* if pid is 0, we should apply this to all processes */
        DIR *fd = opendir("/proc");
        if (fd) {
          struct dirent *child;
          while (child = readdir(fd)) {
            int n = atoi(child->d_name);
            if (n > 0) {
              b2g_prlimit_helper((pid_t)n, RLIMIT_CORE, &lim, NULL);
            }
          }
          closedir(fd);
        }
      }
    } else {
      printf("b2g-prlimit: %s resource unsupported; try core\n", argv[1]);
    }
  } else {
    printf("usage: b2g-prlimit <pid> <resource> <soft> <hard>\n");
  }
  return 0;
}

