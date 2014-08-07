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

// Enable assertions.
#ifdef NDEBUG
#undef NDEBUG
#endif

#include "processlist.h"
#include "process.h"
#include <assert.h>
#include <dirent.h>

using namespace std;

/* static */ ProcessList&
ProcessList::singleton()
{
  static ProcessList singleton;
  return singleton;
}

ProcessList::ProcessList()
  : m_main_process(NULL)
  , m_got_child_processes(false)
{}

const vector<Process*>&
ProcessList::all_processes()
{
  if (m_all_processes.size()) {
    return m_all_processes;
  }

  // Create a Process object for each pid in /proc.

  DIR* proc = safe_opendir("/proc");
  if (!proc) {
    perror("Error opening /proc");
    exit(2);
  }

  dirent* de;
  while ((de = readdir(proc))) {
    int pid;
    if (str_to_int(de->d_name, &pid)) {
      m_all_processes.push_back(new Process(pid));
    }
  }

  closedir(proc);

  return m_all_processes;
}

Process*
ProcessList::main_process()
{
  if (m_main_process) {
    return m_main_process;
  }

  const vector<Process*>& processes = unordered_b2g_processes();
  for (vector<Process*>::const_iterator it = processes.begin();
       it != processes.end(); ++it) {
    // Check to so if this processes parent is contained in the b2g_processes
    pid_t it_ppid = (*it)->ppid();
    vector<Process*>::const_iterator it2;
    for (it2 = processes.begin(); it2 != processes.end(); ++it2) {
      if ((*it2)->pid() == it_ppid) {
        // Our parent is another b2g-process - that makes us a child process
        // of some type.
        break;
      }
    }
    if (it2 != processes.end()) {
      // We found a child process
      continue;
    }
    // Our processes parent wasn't in the list of b2g processes. This makes
    // us a main process.
    if (m_main_process == NULL) {
      m_main_process = *it;
    } else {
      fprintf(stderr,
              "Fatal error: Two B2G main processes found (pids %d and %d)\n",
              m_main_process->pid(), (*it)->pid());
      exit(2);
    }
  }

  if (!m_main_process) {
    fprintf(stderr, "Fatal error: B2G main process not found.\n");
    exit(2);
  }

  return m_main_process;
}

const vector<Process*>&
ProcessList::child_processes()
{
  if (m_got_child_processes) {
    return m_child_processes;
  }

  assert(m_child_processes.size() == 0);

  pid_t main_pid = main_process()->pid();

  const vector<Process*>& processes = unordered_b2g_processes();
  for (vector<Process*>::const_iterator it = processes.begin();
       it != processes.end(); ++it) {
    if ((*it)->pid() != main_pid) {
      m_child_processes.push_back(*it); 
    }
  }
  m_got_child_processes = true;
  return m_child_processes;
}

const vector<Process*>&
ProcessList::unordered_b2g_processes()
{
  if (m_unordered_b2g_processes.size()) {
    return m_unordered_b2g_processes;
  }

  assert(m_unordered_b2g_processes.size() == 0);

  // We could find child processes by looking for processes whose ppid matches
  // the main process's pid, but this requires reading /proc/<pid>/stat for
  // every process on the system.  It's a bit faster just to look for processes
  // whose |exe|s are "/system/b2g/plugin-container" or "/system/b2g/b2g".  As
  // an added bonus, this will work properly with nested content processes.

  const vector<Process*>& processes = all_processes();
  for (vector<Process*>::const_iterator it = processes.begin();
       it != processes.end(); ++it) {
    if ((*it)->exe() == "/system/b2g/plugin-container" || 
        (*it)->exe() == "/system/b2g/b2g") {
      m_unordered_b2g_processes.push_back(*it);
    }
  }
  return m_unordered_b2g_processes;
}

const vector<Process*>&
ProcessList::b2g_processes()
{
  if (m_b2g_processes.size()) {
    return m_b2g_processes;
  }

  assert(m_b2g_processes.size() == 0);

  const vector<Process*>& processes = unordered_b2g_processes();
  if (processes.size() == 0) {
    // This can happen when we're not running as root.
    return processes;
  }

  // Order the processes such that we have the main process followed by the
  // child processes.

  Process* main_proc = main_process();
  const vector<Process*>& child_proc = child_processes();

  m_b2g_processes.push_back(main_proc);
  for (vector<Process*>::const_iterator it = child_proc.begin();
       it != child_proc.end(); ++it) {
    m_b2g_processes.push_back(*it);
  }

  return m_b2g_processes;
}
