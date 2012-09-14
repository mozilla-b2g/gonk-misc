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
 * Example usages:
 *
 *     # Send signal 42 to processes 123, 456, and 789.
 *     $ killer 42 123 456 789
 *
 *     # Send SIGRTMIN + 10 to process 123.  (We don't parse any of the
 *     # friendly signal names other than "SIGRT".)
 *     $ killer SIGRT10 123
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <signal.h>
#include <malloc.h>

using namespace std;

void usage(int argc, char** argv)
{
  assert(argc >= 1);
  fprintf(stderr, "Usage: %s SIGNUM PID [PID ...]\n", argv[0]);
  fprintf(stderr, "Usage: %s SIGRT<N> PID [PID...]\n", argv[0]);
  fprintf(stderr, "\n");
  fprintf(stderr, "For example,\n\n");
  fprintf(stderr, "  %s SIGRT8 123\n\n", argv[0]);
  fprintf(stderr, "will send signal SIGRTMIN + 8 to process 123.\n\n");
  fprintf(stderr, "(We don't parse parse any friendly signal names other than ");
  fprintf(stderr, "\"SIGRT\" at the moment.)\n");
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
