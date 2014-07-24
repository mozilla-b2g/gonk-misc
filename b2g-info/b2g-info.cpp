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
#include "json.h"

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <getopt.h>
#include <string>
#include <sstream>
#include <iostream>

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
    Process::const_iterator itr = ProcessList::singleton().child_processes().begin();
    Process::const_iterator end = ProcessList::singleton().child_processes().end();
    for ( ; itr != end; ++itr ) {
      printf("%d ", (*itr)->pid());
    }
  }

  putchar('\n');
}

/**
 * Builds JSON object of B2G processes.
 */
void
print_b2g_pids_json(bool main_process_only, bool child_processes_only)
{
  assert(!(main_process_only && child_processes_only));

  JSON::Object pids;

  if (!child_processes_only) {
    pids.add("main", ProcessList::singleton().main_process()->pid());
  }

  if (!main_process_only) {
    JSON::Array children;
    Process::const_iterator bgn = ProcessList::singleton().child_processes().begin();
    Process::const_iterator end = ProcessList::singleton().child_processes().end();

    for ( Process::const_iterator itr = bgn; itr != end; ++itr ) {
      children.push_back((*itr)->pid());
    }
    pids.add("children", children);
  }

  if ( !(main_process_only && child_processes_only) ) {
    JSON::Array b2g_processes;
    Process::const_iterator bgn = ProcessList::singleton().b2g_processes().begin();
    Process::const_iterator end = ProcessList::singleton().b2g_processes().end();

    for ( Process::const_iterator itr = bgn; itr != end; ++itr ) {
      b2g_processes.push_back((*itr)->pid());
    }
    pids.add("b2g_processes", b2g_processes);
  }
 
  // output the JSON
  std::cout << pids << std::endl;
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

struct meminfo_t {
  meminfo_t() : total(-1), free(-1), buffers(-1), cached(-1), swap_total(-1),
                swap_free(-1), swap_cached(-1) {}
  int total;
  int free;
  int buffers;
  int cached;
  int swap_total;
  int swap_free;
  int swap_cached;
};

bool get_system_meminfo(meminfo_t & mi)
{
  // We can't use sysinfo() here because iit doesn't tell us how much cached
  // memory we're using.  (On B2G, this is often upwards of 30mb.)
  //
  // Instead, we have to parse /proc/meminfo.

  FILE* meminfo = fopen("/proc/meminfo", "r");
  if (!meminfo) {
    perror("Couldn't open /proc/meminfo");
    return false;
  }

  char line[256];
  while(fgets(line, sizeof(line), meminfo)) {
    int val;
    if (sscanf(line, "MemTotal: %d kB", &val) == 1) {
        mi.total = val;
    } else if (sscanf(line, "MemFree: %d kB", &val) == 1) {
        mi.free = val;
    } else if (sscanf(line, "Buffers: %d kB", &val) == 1) {
        mi.buffers = val;
    } else if (sscanf(line, "Cached: %d kB", &val) == 1) {
        mi.cached = val;
    } else if (sscanf(line, "SwapTotal: %d kB", &val) == 1) {
        mi.swap_total = val;
    } else if (sscanf(line, "SwapFree: %d kB", &val) == 1) {
        mi.swap_free = val;
    } else if (sscanf(line, "SwapCached: %d kB", &val) == 1) {
        mi.swap_cached = val;
    }
  }

  fclose(meminfo);

  if (mi.total == -1 || mi.free == -1 || mi.buffers == -1 || mi.cached == -1 ||
      mi.swap_total == -1 || mi.swap_free == -1 || mi.swap_cached == -1) {
    fprintf(stderr, "Unable to parse /proc/meminfo.\n");
    return false;
  }

  return true;
}


void print_system_meminfo()
{
  meminfo_t mi;

  assert(get_system_meminfo(mi));
  int actually_used = mi.total - mi.free - mi.buffers - mi.cached - mi.swap_cached;

  puts("System memory info:\n");

  Table t;

  t.start_row();
  t.add("Total");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.total));

  t.start_row();
  t.add("SwapTotal");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.swap_total));

  t.start_row();
  t.add("Used - cache");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.total - mi.free - mi.buffers - mi.cached - mi.swap_cached));

  t.start_row();
  t.add("B2G procs (PSS)");

  int b2g_mem_kb = 0;
  for (Process::const_iterator it = ProcessList::singleton().b2g_processes().begin();
       it != ProcessList::singleton().b2g_processes().end(); ++it) {
    b2g_mem_kb += (*it)->pss_kb();
  }
  t.add_fmt("%0.1f MB", b2g_mem_kb / 1024.0);

  t.start_row();
  t.add("Non-B2G procs");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.total - mi.free - mi.buffers - mi.cached - b2g_mem_kb - mi.swap_cached));

  t.start_row();
  t.add("Free + cache");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.free + mi.buffers + mi.cached + mi.swap_cached));

  t.start_row();
  t.add("Free");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.free));

  t.start_row();
  t.add("Cache");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.buffers + mi.cached + mi.swap_cached));

  t.start_row();
  t.add("SwapFree");
  t.add_fmt("%0.1f MB", kb_to_mb(mi.swap_free));

  t.print_with_indent(2);
}

struct lmk_params_t {
  lmk_params_t() : notify_pages(0) {}
  int notify_pages;
  vector<int> oom_adjs;
  vector<int> minfrees;
};

bool get_lmk_params(lmk_params_t & l)
{
  #define LMK_DIR "/sys/module/lowmemorykiller/parameters/"
  l.notify_pages = str_to_int(read_whole_file(LMK_DIR "notify_trigger"), -1);

  {
    stringstream ss(read_whole_file(LMK_DIR "adj"));
    string item;
    while (getline(ss, item, ',')) {
      l.oom_adjs.push_back(str_to_int(item, -1));
    }
  }

  {
    stringstream ss(read_whole_file(LMK_DIR "minfree"));
    string item;
    while (getline(ss, item, ',')) {
      l.minfrees.push_back(pages_to_kb(str_to_int(item, -1)));
    }
  }

  #undef LMK_DIR
  return true;
}


void print_lmk_params()
{
  lmk_params_t l;

  assert(get_lmk_params(l));
  
  puts("Low-memory killer parameters:\n");
  printf("  notify_trigger %d KB\n", pages_to_kb(l.notify_pages));
  putchar('\n');

  Table t;
  t.start_row();
  t.add("oom_adj");
  t.add("min_free", Table::ALIGN_LEFT);

  for (size_t i = 0; i < max(l.oom_adjs.size(), l.minfrees.size()); i++) {
    t.start_row();
    if (i < l.oom_adjs.size()) {
      t.add(l.oom_adjs[i]);
    } else {
      t.add("");
    }

    if (i < l.minfrees.size()) {
      t.add_fmt("%d KB", l.minfrees[i]);
    } else {
      t.add("");
    }
  }

  t.print_with_indent(2);
}

bool get_threads(JSON::Array & ts, Process * const p)
{
  assert(p);

  Thread::const_iterator itr = p->threads().begin();
  Thread::const_iterator end = p->threads().end();
  for ( ; itr != end; ++itr ) {
    JSON::Object thread;
    thread.add("name", (*itr)->name());
    thread.add("tid", (*itr)->tid());
    thread.add("nice", (*itr)->nice());
    ts.push_back(thread);
  }
  return true;
}

bool get_b2g_process(JSON::Array & ps, Process * const p, bool show_threads)
{
  JSON::Object proc;
  assert(p);

  proc.add("name", p->name());
  proc.add((show_threads ? "tid" : "pid"), p->pid());
  proc.add("ppid", p->ppid());
  proc.add("cpu", p->stime_s() + p->utime_s());
  proc.add("nice", p->nice());
  proc.add("uss", p->uss_mb());
  proc.add("pss", p->pss_mb());
  proc.add("rss", p->rss_mb());
  proc.add("swap", p->swap_mb());
  proc.add("vsize", p->vsize_mb());
  proc.add("oom_adj", p->oom_adj());
  proc.add("user", p->user());

  if( show_threads ) {
    JSON::Array ts;
    assert(get_threads( ts, p ));
    proc.add("threads", ts);
  }
  ps.push_back(proc);
  return true;
}

int print_b2g_info_json(bool show_threads)
{
  JSON::Object b;
  // get all of the b2g process info
  JSON::Array ps;
  {
    Process::const_iterator bgn = ProcessList::singleton().b2g_processes().begin();
    Process::const_iterator end = ProcessList::singleton().b2g_processes().end();
    for (Process::const_iterator itr = bgn; itr != end; ++itr) {
      get_b2g_process( ps, (*itr), show_threads );
    }
  }
  b.add("processes", ps);

  // get the system meminfo
  JSON::Object mi;
  {
    meminfo_t mit;
    get_system_meminfo( mit );
    mi.add("total", kb_to_mb(mit.total));
    mi.add("swap_total", kb_to_mb(mit.swap_total));
    mi.add("used_minus_cache", kb_to_mb(mit.total - mit.free - mit.buffers - mit.cached - mit.swap_cached));
    int b2g_mem_kb = 0;
    Process::const_iterator itr = ProcessList::singleton().b2g_processes().begin();
    Process::const_iterator end = ProcessList::singleton().b2g_processes().end();
    for ( ; itr != end; ++itr ) {
      b2g_mem_kb += (*itr)->pss_kb();
    }
    mi.add("pss", kb_to_mb(b2g_mem_kb));
    mi.add("non_b2g_procs", kb_to_mb(mit.total - mit.free - mit.buffers - 
                                    mit.cached - b2g_mem_kb - mit.swap_cached));
    mi.add("free_plus_cache", kb_to_mb(mit.free + mit.buffers + mit.cached + mit.swap_cached));
    mi.add("free", kb_to_mb(mit.free));
    mi.add("cache", kb_to_mb(mit.buffers + mit.cached + mit.swap_cached));
    mi.add("swapfree", kb_to_mb(mit.swap_free));
  }
  b.add("system_meminfo", mi);

  // get the lmk params
  JSON::Object lmk;
  {
    lmk_params_t lp;
    get_lmk_params(lp);
    lmk.add("notify_trigger", pages_to_kb(lp.notify_pages));
    JSON::Array adjs;
    for (size_t i = 0; i < max(lp.oom_adjs.size(), lp.minfrees.size()); i++) {
      JSON::Object adj;
      if (i < lp.oom_adjs.size()) {
        adj.add("oom_adj", lp.oom_adjs[i]);
      } else {
        adj.add("oom_adj", JSON::Null);
      }

      if (i < lp.minfrees.size()) {
        adj.add("min_free", lp.minfrees[i]);
      } else {
        adj.add("min_free", JSON::Null);
      }
      adjs.push_back(adj);
    }
    lmk.add("oom_adjs", adjs);
  }
  b.add("lmk_params", lmk);

  // print out the JSON
  std::cout << b << std::endl;
  return 0;
}

void
b2g_ps_add_table_headers(Table& t, bool show_threads)
{
  t.start_row();
  t.add("NAME");
  t.add(show_threads ? "TID" : "PID");
  t.add("PPID");
  t.add("CPU(s)");
  t.add("NICE");
  t.add("USS");
  t.add("PSS");
  t.add("RSS");
  t.add("SWAP");
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

  Process::const_iterator bgn = ProcessList::singleton().b2g_processes().begin();
  Process::const_iterator end = ProcessList::singleton().b2g_processes().end();
  for (Process::const_iterator itr = bgn; itr != end; ++itr) {
    if (show_threads) {
      b2g_ps_add_table_headers(t, /* show_threads */ true);
    }

    Process* p = *itr;
    t.start_row();
    t.add(p->name());
    t.add(p->pid());
    t.add(p->ppid());
    t.add_fmt("%0.1f", p->stime_s() + p->utime_s());
    t.add(p->nice());
    t.add_fmt("%0.1f", p->uss_mb());
    t.add_fmt("%0.1f", p->pss_mb());
    t.add_fmt("%0.1f", p->rss_mb());
    t.add_fmt("%0.1f", p->swap_mb());
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

      if (itr + 1 != end) {
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
  printf("  -j, --json         Print data in JSON format.\n");
  printf("  -h, --help         Display this message.\n");
  printf("\n");
  printf("Note that all of these options are mutually-exclusive.\n");
}

int main(int argc, char * const argv[])
{
  static struct option long_options[] = {
    { "threads",      no_argument,       0,    't' },
    { "pids",         no_argument,       0,    'p' },
    { "main-pid",     no_argument,       0,    'm' },
    { "child-pids",   no_argument,       0,    'c' },
    { "json",         no_argument,       0,    'j' },
    { "help",         no_argument,       0,    'h' },
    { 0,              0,                 0,     0  }
  };

  int opt = 0;
  int long_index = 0;
  bool threads = false;
  bool pids_only = false;
  bool main_pid_only = false;
  bool child_pids_only = false;
  bool output_json = false;
  cmd_name = argv[0];

  while ((opt = getopt_long( argc, argv, "tpmcjh", long_options, &long_index )) != -1) {
    switch( opt ) {
      case 't':
        threads = true;
        break;
      case 'p':
        pids_only = true;
        break;
      case 'm':
        main_pid_only = true;
        break;
      case 'c':
        child_pids_only = true;
        break;
      case 'j':
        output_json = true;
        break;
      case 'h':
      default:
        usage();
        return 1;
    }
  }

  // are we outputting the results in json?
  if (output_json) {
    if (pids_only || main_pid_only || child_pids_only) {
      print_b2g_pids_json(main_pid_only, child_pids_only);
      return 0;
    }

    return print_b2g_info_json(threads);
  }

  // nope...
  if (pids_only || main_pid_only || child_pids_only) {
    print_b2g_pids(main_pid_only, child_pids_only);
    return 0;
  }

  return print_b2g_info(threads);
}
