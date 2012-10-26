/*
 * Copyright (C) 2012 Mozilla Foundation
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

/*
 * This program is like kill(1), in that you use it to send signals to other
 * processes.  The main difference is that, unlike the kill(1) implementation
 * on our devices, this program will happily send signals greater than 32.
 *
 * This program has been restricted to only being able to send signals
 * SIGRT0, SIGRT1, and SIGRT2 (32, 33, and 34) and furthermore it can only
 * send them to processes launched from /system/b2g/b2g or
 * /system/b2g/plugin-container. These restrictions were added to allow
 * this program to be setuid(root) which would be required on a production
 * phone which uses the shell user for the adb shell command (non-production
 * phones use the root user for adb shell).
 *
 * Example usages:
 *
 *     # Send signal 32 to processes 123, 456, and 789.
 *     $ killer 32 123 456 789
 *
 *     # Send SIGRTMIN + 2 to process 123.  (We don't parse any of the
 *     # friendly signal names other than "SIGRT".)
 *     $ killer SIGRT2 123
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <signal.h>
#include <malloc.h>
#include <unistd.h>

using namespace std;

// Since we run as setuid root, we restrict which signals can be
// sent and to whom we can send them.
static const int  sAllowedSignals[] = {SIGRTMIN + 0, SIGRTMIN + 1, SIGRTMIN + 2 };

static const char *sAllowedExes[] = {
  "/system/b2g/b2g",
  "/system/b2g/plugin-container"
};

#define ARRAY_LENGTH(x) (sizeof(x)/sizeof(x[0]))

void usage(int argc, char** argv)
{
  assert(argc >= 1);
  fprintf(stderr, "Usage: %s SIGNUM PID [PID ...]\n", argv[0]);
  fprintf(stderr, "Usage: %s SIGRT<N> PID [PID...]\n", argv[0]);
  fprintf(stderr, "\n");
  fprintf(stderr, "For example,\n\n");
  fprintf(stderr, "  %s SIGRT2 123\n\n", argv[0]);
  fprintf(stderr, "will send signal SIGRTMIN + 2 to process 123.\n\n");
  fprintf(stderr, "(We don't parse parse any friendly signal names other than ");
  fprintf(stderr, "\"SIGRT\" at the moment.)\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "This program can only send SIGRT0, SIGRT1, and SIGRT2 to\n");
  fprintf(stderr, "the /system/b2g/b2g and /system/b2g/plugin-container programs.\n");
}

int main(int argc, char** argv)
{
  if (argc < 3) {
    fprintf(stderr, "Error: Not enough arguments.\n");
    usage(argc, argv);
    exit(1);
  }

  /*
   * Parse the signal number/name.  It must either be a non-negative integger
   * or be of the form "SIGRTn" for some non-negative integer n.
   */
  const char* sigstr = argv[1];
  int signum = -1;
  if (!strncasecmp(sigstr, "SIGRT", strlen("SIGRT"))) {
    char* endptr = NULL;
    int sigrtOffset = strtol(sigstr + strlen("SIGRT"), &endptr, /* base */ 10);
    if (!*endptr || sigrtOffset < 0) {
      signum = SIGRTMIN + sigrtOffset;
    } else {
      // An error occurred.
      signum = -1;
    }
  } else {
    char* endptr = NULL;
    signum = strtol(argv[1], &endptr, /* base */ 10);
    if (*endptr) {
      // An error occurred.
      signum = -1;
    }
  }

  if (signum < 0) {
    fprintf(stderr, "Error: Invalid signal %s\n", sigstr);
    usage(argc, argv);
    exit(1);
  }
  bool foundAllowedSignal = false;
  for (int i = 0; i < ARRAY_LENGTH(sAllowedSignals); i++) {
    if (signum == sAllowedSignals[i]) {
      foundAllowedSignal = true;
      break;
    }
  }
  if (!foundAllowedSignal) {
    fprintf(stderr, "Error: Signal %s isn't allowed.\n", sigstr);
    exit(1);
  }

  /*
   * For some reason <vector> isn't in our include path.  Rather than figure
   * this out, we can just use malloc.
   */

  int* pids = new int[argc];
  int numPids = 0;
  for (int i = 2; i < argc; i++) {
    char* endptr = NULL;
    int pid = strtol(argv[i], &endptr, /* base */ 10);
    if (*endptr || pid < 0) {
      fprintf(stderr, "Error: Invalid pid %s\n", argv[i]);
      usage(argc, argv);
      exit(1);
    }
    // We could use MAX_PATH_LEN, but this is 4K, and we know our strings
    // can't possibly be that long, so we save some memory.
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/exe", pid);
    char exe[64];
    int linklen = readlink(path, exe, sizeof(exe));
    if (linklen < 0) {
      fprintf(stderr, "Error: No such process %s", argv[i]);
      exit(1);
    }
    if (linklen > (sizeof(exe) - 1)) {
      linklen = sizeof(exe) - 1;
    }
    exe[linklen] = '\0';
    bool foundAllowedExe = false;
    for (int i = 0; i < ARRAY_LENGTH(sAllowedExes); i++) {
      if (strcmp(exe, sAllowedExes[i]) == 0) {
        foundAllowedExe = true;
        break;
      }
    }
    if (!foundAllowedExe) {
      fprintf(stderr, "Error: Process %s isn't allowed.\n", exe);
      exit(1);
    }

    pids[numPids] = pid;
    numPids++;
  }

  for (int i = 0; i < numPids; i++) {
    if (kill(pids[i], signum)) {
      fprintf(stderr, "Failed to send signal %d to process %d", signum, pids[i]);
      perror("");
    }
  }
  return 0;
}
