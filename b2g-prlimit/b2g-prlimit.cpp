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

#include <asm/unistd.h>   // for __NR_prlimit64
#include <sys/resource.h> // for RLIMIT_*
#include <sys/syscall.h>  // for syscall
#include <string.h>       // for strcmp
#include <stdlib.h>       // for atoi
#include <stdio.h>        // for printf
#include <errno.h>        // for errno
#include <dirent.h>       // for opendir, readdir, etc
#include <unistd.h>       // for syscall

struct b2g_rlimit64 {
  uint64_t rlim_cur;
  uint64_t rlim_max;
};

static void
b2g_prlimit64(pid_t pid, int code, const struct b2g_rlimit64* wval, struct b2g_rlimit64* rval)
{
#ifdef __NR_prlimit64
  if (syscall(__NR_prlimit64, pid, code, wval, rval) < 0) {
    printf("b2g-prlimit: failed to set %d for pid %d: %s (%d)\n", code, pid, strerror(errno), errno);
  }
#else
  printf("b2g-prlimit: failed to set %d for pid %d: no kernel support\n", code, pid);
#endif
}

static void
usage()
{
  printf("usage: b2g-prlimit <pid> <resource> <soft> <hard>\n"
         "  accepted resources: core\n");
}

int
main(int argc, char** argv)
{
  if (argc < 2) {
    usage();
    return 0;
  }

  /* all rlimits need the same parameters */
  if (argc != 5) {
    usage();
    return -1;
  }

  int code;
  if (strcmp(argv[2], "core") == 0) {
    code = RLIMIT_CORE;
  } else {
    usage();
    return -2;
  }

  struct b2g_rlimit64 lim;
  pid_t pid;

  memset(&lim, 0, sizeof(lim));
  lim.rlim_cur = (rlim_t)atoi(argv[3]);
  lim.rlim_max = (rlim_t)atoi(argv[4]);
  pid = (pid_t)atoi(argv[1]);
  if (pid) {
    b2g_prlimit64(pid, code, &lim, NULL);
  } else {
    /* if pid is 0, we should apply this to all processes */
    DIR* fd;
    struct dirent* child;

    fd = opendir("/proc");
    if (!fd) {
      printf("b2g-prlimit: failed to open /proc: %s (%d)\n", strerror(errno), errno);
      return -3;
    }

    while ((child = readdir(fd)) != NULL) {
      int n = atoi(child->d_name);
      if (n > 0) {
        b2g_prlimit64((pid_t)n, code, &lim, NULL);
      }
    }
    closedir(fd);
  }
  return 0;
}

