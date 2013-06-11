/*
 * Copyright (C) 2013 Mozilla Foundation
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
 * b2g-info prints information about B2G processes on a phone to stdout.
 *
 * To build this file without rebuilding your whole tree, run
 *
 *   ./build.sh b2g-info
 *
 * Then push the executable from out/target/product/<NAME>/system/bin/b2g-info
 * into /system/bin.
 */

// Enable assertions.
#ifdef NDEBUG
#undef NDEBUG
#endif

#include "table.h"
#include "process.h"
#include "processlist.h"
#include "utils.h"

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <string>
#include <sstream>

using namespace std;

/**
 * The name of the file being executed; i.e., argv[0].
 */
static const char* cmd_name;

/**
 * Prints the pids of B2G processes.
 */
void
print_b2g_pids(bool main_process_only, bool child_processes_only)
{
  assert(!(main_process_only && child_processes_only));

  if (!child_processes_only) {
    printf("%d ", ProcessList::singleton().main_process()->pid());
  }

  if (!main_process_only) {
    for (vector<Process*>::const_iterator it =
           ProcessList::singleton().child_processes().begin();
         it != ProcessList::singleton().child_processes().end(); ++it) {
      printf("%d ", (*it)->pid());
    }
  }

  putchar('\n');
}

string
read_whole_file(const char* filename)
{
  char buf[1024];
  int fd = TEMP_FAILURE_RETRY(open(filename, O_RDONLY));
  if (fd == -1) {
    return "";
  }

  ssize_t total_read = 0;
  ssize_t num_remaining = sizeof(buf) - 1;
  while (true) {
    // No more room in the buffer; we're done.
    if (num_remaining <= 0) {
      break;
    }

    ssize_t nread = TEMP_FAILURE_RETRY(read(fd, buf + total_read, num_remaining));
    if (nread == 0 || nread == -1) {
      break;
    }

    num_remaining -= nread;
    total_read += nread;
  }

  buf[total_read] = '\0';
  return buf;
}

void print_system_meminfo()
{
  // We can't use sysinfo() here because iit doesn't tell us how much cached
  // memory we're using.  (On B2G, this is often upwards of 30mb.)
  //
  // Instead, we have to parse /proc/meminfo.

  FILE* meminfo = fopen("/proc/meminfo", "r");
  if (!meminfo) {
    perror("Couldn't open /proc/meminfo");
    return;
  }

  // These are all in kb.
  int total = -1;
  int free = -1;
  int buffers = -1;
  int cached = -1;

  char line[256];
  while(fgets(line, sizeof(line), meminfo)) {
    if (sscanf(line, "MemTotal: %d kB", &total) == 0 &&
        sscanf(line, "MemFree: %d kB", &free) == 0 &&
        sscanf(line, "Buffers: %d kB", &buffers) == 0 &&
        sscanf(line, "Cached: %d kB", &cached)) {
      // These four values should appear first in meminfo, so if this line
      // doesn't match any of them, we're done parsing.
      break;
    }
  }

  fclose(meminfo);

  if (total == -1 || free == -1 || buffers == -1 || cached == -1) {
    fprintf(stderr, "Unable to parse /proc/meminfo.\n");
    return;
  }

  int actually_used = total - free - buffers - cached;

  puts("System memory info:\n");

  Table t;

  t.start_row();
  t.add("Total");
  t.add_fmt("%0.1f MB", kb_to_mb(total));

  t.start_row();
  t.add("Used - cache");
  t.add_fmt("%0.1f MB", kb_to_mb(total - free - buffers - cached));

  t.start_row();
  t.add("B2G procs (PSS)");

  int b2g_mem_kb = 0;
  for (vector<Process*>::const_iterator it = ProcessList::singleton().b2g_processes().begin();
       it != ProcessList::singleton().b2g_processes().end(); ++it) {
    b2g_mem_kb += (*it)->pss_kb();
  }
  t.add_fmt("%0.1f MB", b2g_mem_kb / 1024.0);

  t.start_row();
  t.add("Non-B2G procs");
  t.add_fmt("%0.1f MB", kb_to_mb(total - free - buffers - cached - b2g_mem_kb));

  t.start_row();
  t.add("Free + cache");
  t.add_fmt("%0.1f MB", kb_to_mb(free + buffers + cached));

  t.start_row();
  t.add("Free");
  t.add_fmt("%0.1f MB", kb_to_mb(free));

  t.start_row();
  t.add("Cache");
  t.add_fmt("%0.1f MB", kb_to_mb(buffers + cached));

  t.print_with_indent(2);
}

void print_lmk_params()
{
#define LMK_DIR "/sys/module/lowmemorykiller/parameters/"

  puts("Low-memory killer parameters:\n");

  int notify_pages = str_to_int(read_whole_file(LMK_DIR "notify_trigger"), -1);
  printf("  notify_trigger %d KB\n", pages_to_kb(notify_pages));
  putchar('\n');

  vector<int> oom_adjs;
  {
    stringstream ss(read_whole_file(LMK_DIR "adj"));
    string item;
    while (getline(ss, item, ',')) {
      oom_adjs.push_back(str_to_int(item, -1));
    }
  }

  vector<int> minfrees;
  {
    stringstream ss(read_whole_file(LMK_DIR "minfree"));
    string item;
    while (getline(ss, item, ',')) {
      minfrees.push_back(pages_to_kb(str_to_int(item, -1)));
    }
  }

  Table t;
  t.start_row();
  t.add("oom_adj");
  t.add("min_free", Table::ALIGN_LEFT);

  for (size_t i = 0; i < max(oom_adjs.size(), minfrees.size()); i++) {
    t.start_row();
    if (i < oom_adjs.size()) {
      t.add(oom_adjs[i]);
    } else {
      t.add("");
    }

    if (i < minfrees.size()) {
      t.add_fmt("%d KB", minfrees[i]);
    } else {
      t.add("");
    }
  }

  t.print_with_indent(2);

#undef LMK_DIR
}

void
b2g_ps_add_table_headers(Table& t, bool show_threads)
{
  t.start_row();
  t.add("NAME");
  t.add(show_threads ? "TID" : "PID");
  t.add("NICE");
  t.add("USS");
  t.add("PSS");
  t.add("RSS");
  t.add("VSIZE");
  t.add("OOM_ADJ");
  t.add("USER", Table::ALIGN_LEFT);
}

int
print_b2g_info(bool show_threads)
{
  // TODO: switch between kb and mb for RSS etc.
  // TODO: Sort processes?

  Table t;

  // This sits atop USS/PSS/RSS/VSIZE.
  t.multi_col_header("megabytes", 3, 7);

  if (!show_threads) {
    b2g_ps_add_table_headers(t, /* show_threads */ false);
  }

  for (vector<Process*>::const_iterator it =
         ProcessList::singleton().b2g_processes().begin();
       it != ProcessList::singleton().b2g_processes().end(); ++it) {

    if (show_threads) {
      b2g_ps_add_table_headers(t, /* show_threads */ true);
    }

    Process* p = *it;
    t.start_row();
    t.add(p->name());
    t.add(p->pid());
    t.add(p->nice());
    t.add_fmt("%0.1f", p->uss_mb());
    t.add_fmt("%0.1f", p->pss_mb());
    t.add_fmt("%0.1f", p->rss_mb());
    t.add_fmt("%0.1f", p->vsize_mb());
    t.add(p->oom_adj());
    t.add(p->user(), Table::ALIGN_LEFT);

    if (show_threads) {
      for (vector<Thread*>::const_iterator thread_it =
             p->threads().begin();
           thread_it != p->threads().end(); ++thread_it) {
        t.start_row();

        Thread* thread = *thread_it;
        t.add(thread->name());
        t.add(thread->tid());
        t.add(thread->nice());
      }

      if (it + 1 != ProcessList::singleton().b2g_processes().end()) {
        t.add_delimiter();
      }
    }
  }

  t.print();
  putchar('\n');

  print_system_meminfo();
  putchar('\n');

  print_lmk_params();

  return 0;
}

void usage()
{
  printf("usage: %s [args]\n", cmd_name);
  printf("\n");
  printf("Options:\n");
  printf("  -t, --threads      Display information about threads.\n");
  printf("  -p, --pids         Print a list of all B2G PIDs.\n");
  printf("  -m, --main-pid     Print only the main B2G process's PID.\n");
  printf("  -c, --child-pids   Print only the child B2G processes' PIDs.\n");
  printf("  -h, --help         Display this message.\n");
  printf("\n");
  printf("Note that all of these options are mutually-exclusive.\n");
}

int main(int argc, const char** argv)
{
  cmd_name = argv[0];

  // We could use an option-parsing library, but this is easier for now.
  if (argc > 2) {
    fputs("Too many arguments.\n", stderr);
    usage();
    return 1;
  }

  bool threads = false;
  bool pids_only = false;
  bool main_pid_only = false;
  bool child_pids_only = false;

  if (argc > 1) {
    if (!strcmp(argv[1], "--help") || !strcmp(argv[1], "-h") || !strcmp(argv[1], "help")) {
      usage();
      return 0;
    }

    if (!(threads = !strcmp(argv[1], "-t") || !strcmp(argv[1], "--threads")) &&
        !(pids_only = !strcmp(argv[1], "-p") || !strcmp(argv[1], "--pids")) &&
        !(main_pid_only = !strcmp(argv[1], "-m") || !strcmp(argv[1], "--main-pid")) &&
        !(child_pids_only = !strcmp(argv[1], "-c") || !strcmp(argv[1], "--child-pids"))) {

      fprintf(stderr, "Unknown argument %s.\n", argv[1]);
      usage();
      return 1;
    }
  }

  if (pids_only || main_pid_only || child_pids_only) {
    print_b2g_pids(main_pid_only, child_pids_only);
    return 0;
  }

  return print_b2g_info(threads);
}
