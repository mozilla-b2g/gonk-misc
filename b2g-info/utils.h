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
 * This file contains common utilities for b2g-info.
 */

#pragma once

#include <string>

struct DIR;

/**
 * Convert a number of pages to kb.
 *
 * -1 signifies an error, so if pages == -1, we return -1 (instead of -4).
 */
int pages_to_kb(int pages);

/**
 * Convert a number of kb to mb.
 *
 * -1 signifies an error, so if kb == -1, return -1.
 */
double kb_to_mb(int kb);

/**
 * Strip whitespace off the beginning and end of the given string.
 */
void strip(std::string& str);

/**
 * Convert a string to an int.
 *
 * If the conversion fails, return _default.
 */
int str_to_int(const char* str, int _default);
int str_to_int(const std::string& str, int _default);

/**
 * Convert a string to an int and write it into *result.
 *
 * If the conversion fails, return false and set *result to 0.  Otherwise,
 * return true.
 */
bool str_to_int(const char* str, int* result);
bool str_to_int(const std::string& str, int* result);

/**
 * Call opendir(dir), properly retrying the call if we receive EINTR.
 */
DIR* safe_opendir(const char* dir);
