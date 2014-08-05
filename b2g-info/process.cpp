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

#include "process.h"
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <pwd.h>
#include <sys/stat.h>
#include <regex.h>

using namespace std;

Task::Task(pid_t pid)
  : m_task_id(pid)
  , m_got_stat(false)
  , m_ppid(-1)
  , m_nice(0)
{
  char procdir[128];
  snprintf(procdir, sizeof(procdir), "/proc/%d/", pid);
  m_proc_dir = procdir;
}

Task::Task(pid_t pid, pid_t tid)
  : m_task_id(tid)
  , m_got_stat(false)
  , m_ppid(-1)
  , m_nice(0)
  , m_utime(-1)
  , m_stime(-1)
{
  char procdir[128];
  snprintf(procdir, sizeof(procdir), "/proc/%d/task/%d/", pid, tid);
  m_proc_dir = procdir;
}

pid_t
Task::task_id()
{
  return m_task_id;
}

pid_t
Task::ppid()
{
  ensure_got_stat();
  return m_ppid;
}

const string&
Task::name()
{
  ensure_got_stat();
  return m_name;
}

int
Task::nice()
{
  ensure_got_stat();
  return m_nice;
}

double
Task::utime_s()
{
  ensure_got_stat();
  return m_utime;
}

double
Task::stime_s()
{
  ensure_got_stat();
  return m_stime;
}

void
Task::ensure_got_stat()
{
  static const unsigned int NUM_CAPTURES = 7;
  const char* pattern =
    "^"           // beginning of string
    "([0-9]+) "   // pid
    "\\((.*)\\) " // proc name
    "[A-Z] "      // state
    "([0-9]+) "   // ppid       #include <sys/types.h>
    "[0-9]+ "     // pgrp
    "[0-9]+ "     // session
    "[0-9]+ "     // tty_nr
    "-?[0-9]+ "   // tpgid
    "[0-9]+ "     // flags
    "[0-9]+ "     // minflt (%lu)
    "[0-9]+ "     // cminflt (%lu)
    "[0-9]+ "     // majflt (%lu)
    "[0-9]+ "     // cmajflt (%lu)
    "([0-9]+) "   // utime (%lu)
    "([0-9]+) "   // stime (%ld)
    "[0-9]+ "     // cutime (%ld)
    "[0-9]+ "     // cstime (%ld)
    "[0-9]+ "     // priority (%ld)
    "(-?[0-9]+)"; // niceness

  if (m_got_stat) {
    return;
  }

  char filename[128];
  snprintf(filename, sizeof(filename), "%s/stat", m_proc_dir.c_str());

  // If anything goes wrong after this point, we still want to say that we read
  // the stat file; there's no use in reading it a second time if we failed
  // once.
  m_got_stat = true;

  FILE* stat_file = fopen(filename, "r");
  if (!stat_file) {
    // We expect ENOENT; that indicates that the file doesn't exist (maybe the
    // process exited or something).  If we get anything else, print a warning
    // to the console.
    if (errno != ENOENT) {
      perror("Unable to open /proc/<pid>/stat");
    }
    return;
  }

  char buf[512];

  // read a line (fgets performs NULL plugging for us)
  fgets(buf, sizeof(buf), stat_file);

  fclose(stat_file);

  // now parse the line
  int rc;

  regex_t preg;
  if (0 != (rc = regcomp(&preg, pattern, REG_EXTENDED))) {
    fprintf(stderr, "regcomp() failed, returning nonzero (%d)\n",
            rc);
    return;
  }

  size_t     nmatch = NUM_CAPTURES;
  regmatch_t pmatch[NUM_CAPTURES];

  if (0 != (rc = regexec(&preg, buf, nmatch, pmatch, 0))) {
    fprintf(stderr, "Failed to match '%s' with '%s',returning %d.\n",
            buf, pattern, rc);
    return;
  }

  // Okay, everything worked out.  Store the data we parsed.
  m_name.clear();
  m_name.append(buf + pmatch[2].rm_so, pmatch[2].rm_eo - pmatch[2].rm_so);
  m_ppid = strtol(buf + pmatch[3].rm_so, NULL, 10);
  m_nice = strtol(buf + pmatch[6].rm_so, NULL, 10);
  m_utime = ticks_to_secs(strtol(buf + pmatch[4].rm_so, NULL, 10));
  m_stime = ticks_to_secs(strtol(buf + pmatch[5].rm_so, NULL, 10));

  // finally, emit an error if the line we read doesn't correspond
  // to the process we expect
  int readPid = strtol(buf + pmatch[1].rm_so, NULL, 10);
  if (task_id() != readPid) {
    fprintf(stderr, "When reading %s, got pid %d, but expected pid %d.\n",
            filename, readPid, task_id());
  }

  // free the compiled regular expression
  regfree(&preg);
};

Thread::Thread(pid_t pid, pid_t tid)
  : Task(pid, tid)
  , m_tid(tid)
{}

pid_t
Thread::tid()
{
  return m_tid;
}

Process::Process(pid_t pid)
  : Task(pid)
  , m_pid(pid)
  , m_got_threads(false)
  , m_got_exe(false)
  , m_got_meminfo(false)
  , m_vsize_kb(-1)
  , m_rss_kb(-1)
  , m_pss_kb(-1)
  , m_uss_kb(-1)
  , m_swap_kb(-1)
{}

pid_t
Process::pid()
{
  return m_pid;
}

const vector<Thread*>&
Process::threads()
{
  if (m_got_threads) {
    return m_threads;
  }

  m_got_threads = true;

  DIR* tasks = safe_opendir((m_proc_dir + "task").c_str());
  if (!tasks) {
    return m_threads;
  }

  dirent *de;
  while ((de = readdir(tasks))) {
    int tid;
    if (str_to_int(de->d_name, &tid) && tid != pid()) {
      m_threads.push_back(new Thread(m_pid, tid));
    }
  }

  closedir(tasks);

  return m_threads;
}

const string&
Process::exe()
{
  if (m_got_exe) {
    return m_exe;
  }

  char filename[128];
  snprintf(filename, sizeof(filename), "/proc/%d/exe", pid());

  char link[128];
  ssize_t link_length = readlink(filename, link, sizeof(link) - 1);
  if (link_length == -1) {
    // Maybe this process doesn't exist anymore, or maybe |exe| is a broken
    // link.  If so, that's OK; just let m_exe be the empty string.
    link[0] = '\0';
  } else {
    link[link_length] = '\0';
  }

  m_exe = link;

  m_got_exe = true;
  return m_exe;
}

int
Process::get_int_file(const char* name)
{
  // TODO: Use a cache?

  char filename[128];
  snprintf(filename, sizeof(filename), "/proc/%d/%s", pid(), name);

  int fd = TEMP_FAILURE_RETRY(open(filename, O_RDONLY));
  if (fd == -1) {
    return -1;
  }

  char buf[32];
  int nread = TEMP_FAILURE_RETRY(read(fd, buf, sizeof(buf) - 1));
  TEMP_FAILURE_RETRY(close(fd));

  if (nread == -1) {
    return -1;
  }

  buf[nread] = '\0';
  return str_to_int(buf, -1);
}

int
Process::oom_score()
{
  return get_int_file("oom_score");
}

int
Process::oom_score_adj()
{
  return get_int_file("oom_score_adj");
}

int
Process::oom_adj()
{
  return get_int_file("oom_adj");
}


void
Process::ensure_got_meminfo()
{
  if (m_got_meminfo) {
    return;
  }

  // If anything goes wrong after this point (e.g. smaps doesn't exist), we
  // still want to say that we got meminfo; there's no point in trying again.
  m_got_meminfo = true;

  // Android has this pm_memusage interface to get the data we collect here.
  // But collecting the data from smaps isn't hard, and doing it this way
  // doesn't rely on any external code, which is nice.
  // 
  // Also, the vsize value I get out of procrank (which uses pm_memusage) is
  // way lower than what I get out of statm (which matches smaps).  I presume
  // that statm is correct here.

  char filename[128];
  snprintf(filename, sizeof(filename), "/proc/%d/smaps", pid());
  FILE *f = fopen(filename, "r");
  if (!f) {
    return;
  }

  m_vsize_kb = m_rss_kb = m_pss_kb = m_uss_kb = m_swap_kb = 0;

  char line[256];
  while(fgets(line, sizeof(line), f)) {
      int val = 0;
      if (sscanf(line, "Size: %d kB", &val) == 1) {
        m_vsize_kb += val;
      } else if (sscanf(line, "Rss: %d kB", &val) == 1) {
        m_rss_kb += val;
      } else if (sscanf(line, "Pss: %d kB", &val) == 1) {
        m_pss_kb += val;
      } else if (sscanf(line, "Private_Dirty: %d kB", &val) == 1 ||
                 sscanf(line, "Private_Clean: %d kB", &val) == 1) {
        m_uss_kb += val;
      } else if (sscanf(line, "Swap: %d kB", &val) == 1) {
        m_swap_kb += val;
      }
  }

  fclose(f);
}

int
Process::vsize_kb()
{
  ensure_got_meminfo();
  return m_vsize_kb;
}

int
Process::rss_kb()
{
  ensure_got_meminfo();
  return m_rss_kb;
}

int
Process::pss_kb()
{
  ensure_got_meminfo();
  return m_pss_kb;
}

int
Process::uss_kb()
{
  ensure_got_meminfo();
  return m_uss_kb;
}

int
Process::swap_kb()
{
  ensure_got_meminfo();
  return m_swap_kb;
}

const string&
Process::user()
{
  if (m_user.length()) {
    return m_user;
  }

  char filename[128];
  snprintf(filename, sizeof(filename), "/proc/%d", pid());

  struct stat st;
  if (stat(filename, &st) == -1) {
    m_user = "?";
    return m_user;
  }

  passwd* pw = getpwuid(st.st_uid);
  if (pw) {
    m_user = pw->pw_name;
  } else {
    char uid[32];
    snprintf(uid, sizeof(uid), "%lu", st.st_uid);
    m_user = uid;
  }

  return m_user;
}
