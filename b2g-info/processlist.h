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

#include <vector>

class Process;

/**
 * This singleton class gives you access to the processes on the system.
 *
 * You never have to free pointers returned by this class; it owns all of the
 * objects it returns.
 *
 * This class caches all of its return values; once you call a method once, it
 * will return the same object for all future calls.  It's therefore safe and
 * efficient to call e.g. b2g_processes() multiple times from a loop.
 */
class ProcessList
{
public:
  static ProcessList& singleton();

  /**
   * Get the main B2G process, or crash if it doesn't exist.
   */
  Process* main_process();

  /**
   * Get all of the B2G child processes on the system.
   */
  const std::vector<Process*>& child_processes();

  /**
   * Equal to [main_process] + [child_processes].
   */
  const std::vector<Process*>& b2g_processes();

  /**
   * All processes on the system (not just B2G processes).
   */
  const std::vector<Process*>& all_processes();

private:
  ProcessList();

  Process* m_main_process;
  std::vector<Process*> m_all_processes;

  bool m_got_child_processes;
  std::vector<Process*> m_child_processes;

  std::vector<Process*> m_b2g_processes;
};
