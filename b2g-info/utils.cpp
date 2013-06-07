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

#include "utils.h"
#include <algorithm>
#include <ctype.h>
#include <stdlib.h>
#include <string>

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

  return pages * 4;
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
  str.erase(remove_if(str.begin(), str.end(), isspace), str.end());
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
