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

#include "utils.h"
#include <assert.h>
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <string>
#include <unistd.h>

long PAGE_SIZE = sysconf(_SC_PAGESIZE);

using namespace std;

/**
 * Convert a number of pages to kb.
 *
 * -1 signifies an error, so if pages == -1, we return -1 (instead of -4).
 */
int pages_to_kb(int pages)
{
  if (pages == -1) {
    return -1;
  }

  return pages * PAGE_SIZE / 1024;
}

/**
 * Convert a number of kb to mb.
 *
 * -1 signifies an error, so if kb == -1, return -1.
 */
double kb_to_mb(int kb)
{
  if (kb == -1) {
    return -1;
  }

  return kb / 1024.0;
}

/**
 * Strip whitespace off the beginning and end of the string.
 */
void strip(string& str)
{
  string::iterator it;
  for (it = str.begin(); isspace(*it) && it != str.end(); ++it)
  {}
  str.erase(str.begin(), it);

  string::reverse_iterator rit;
  for (rit = str.rbegin(); isspace(*rit) && rit != str.rend(); ++rit)
  {}
  str.erase(rit.base(), str.end());

  // If the string is non-empty, its first and last chars must not be
  // whitespace.
  assert(str.begin() == str.end() ||
         (!isspace(*str.begin()) && !isspace(*str.rbegin())));
}

/**
 * Convert a string to an int.
 *
 * If the conversion fails, return _default.
 */
int str_to_int(const char* str, int _default)
{
  char* endptr = NULL;

  string tmp(str);
  strip(tmp);
  long result = strtol(tmp.c_str(), &endptr, 10);
  if (tmp.length() && !*endptr) {
    return result;
  }
  return _default;
}

int str_to_int(const std::string& str, int _default)
{
  return str_to_int(str.c_str(), _default);
}

/**
 * Convert a string to an int and write it into *result.
 *
 * If the conversion fails, return false and set *result to 0.  Otherwise,
 * return true.
 */
bool str_to_int(const char* str, int* result)
{
  string tmp(str);
  strip(tmp);

  char* endptr = NULL;
  *result = strtol(tmp.c_str(), &endptr, 10);
  return tmp.length() && !*endptr;
}

bool str_to_int(const string& str, int* result)
{
  return str_to_int(str.c_str(), result);
}

DIR* safe_opendir(const char* dir)
{
  // opendir() calls open(), so it can fail with EINTR.  On the other hand,
  // opendir() can also fail due to malloc() returning null, in which case the
  // bionic implementation doesn't modify errno.  So to be totally safe, we
  // have to set errno to 0 before we invoke TEMP_FAILURE_RETRY.
  errno = 0;
  DIR* d;
  while (!(d = opendir(dir)) && errno == EINTR) {}
  return d;
}
