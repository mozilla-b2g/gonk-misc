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

#pragma once

#include "utils.h"
#include <string>
#include <vector>

/**
 * Task is a base class for Process and Thread.
 *
 * In Task, Thread, and Process, we cache the results of (almost) all of the
 * system calls we make, so it's efficient to call any method multiple times.
 */
class Task
{
public:
  int nice();

  const std::string& name();

  /**
   * Get the parent pid of this process.  This corresponds to the id of the
   * task which launched this task.
   *
   * If we can't retrieve the parent pid (because e.g. the task is no longer
   * running), returns -1.
   */
  pid_t ppid();

  /**
   * Get this Task's id (a pid if it's a process, or a tid if it's a thread).
   */
  pid_t task_id();

protected:
  Task(pid_t pid);
  Task(pid_t pid, pid_t tid);

  void ensure_got_stat();

  pid_t m_task_id;

  /**
   * Directory in /proc corresponding to this task.
   */
  std::string m_proc_dir;

  bool m_got_stat;
  pid_t m_ppid;
  int m_nice;

  std::string m_name;
};

/**
 * Encapsulates information about a thread.
 */
class Thread : public Task
{
public:
  Thread(pid_t pid, pid_t tid);
  pid_t tid();

private:
  pid_t m_tid;
};

/**
 * Encapsulates information about a process.
 */
class Process : public Task
{
public:
  Process(pid_t pid);
  pid_t pid();

  const std::vector<Thread*>& threads();

  /**
   * Get the path to the executable file for this task.
   *
   * If we can't retrieve the executable file, returns an empty string.
   */
  const std::string& exe();

  int oom_adj();
  int oom_score_adj();
  int oom_score();

  int vsize_kb();
  double vsize_mb() { return kb_to_mb(vsize_kb()); }

  int rss_kb();
  double rss_mb() { return kb_to_mb(rss_kb()); }

  int pss_kb();
  double pss_mb() { return kb_to_mb(pss_kb()); }

  int uss_kb();
  double uss_mb() { return kb_to_mb(uss_kb()); }

  const std::string& user();

private:
  void ensure_got_meminfo();

  int get_int_file(const char* name);

  pid_t m_pid;

  bool m_got_threads;
  std::vector<Thread*> m_threads;

  bool m_got_exe;
  std::string m_exe;

  bool m_got_meminfo;
  int m_vsize_kb;
  int m_rss_kb;
  int m_pss_kb;
  int m_uss_kb;

  std::string m_user;
};
