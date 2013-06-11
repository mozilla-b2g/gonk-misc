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

#include "table.h"
#include <assert.h>

using namespace std;

Table::Table()
  : m_multi_col_header_start(-1)
  , m_multi_col_header_end(-1)
{}

void
Table::start_row()
{
  m_rows.push_back(TableRow::create());
}

void
Table::multi_col_header(const char* val, int start_col, int end_col)
{
  // Right now, we support only one multi-col header.
  m_multi_col_header_str = val;
  m_multi_col_header_start = start_col;
  m_multi_col_header_end = end_col;
}

void
Table::add(const char* val, Alignment align /* = ALIGN_RIGHT */)
{
  add_fmt_align("%s", align, val);
}

void
Table::add(const string& val, Alignment align /* = ALIGN_RIGHT */)
{
  add(val.c_str(), align);
}

void
Table::add(int val, Alignment align /* = ALIGN_RIGHT */)
{
  add_fmt_align("%d", align, val);
}

void
Table::add_fmt(const char* fmt, ...)
{
  va_list va;
  va_start(va, fmt);

  add_vfmt_align(fmt, ALIGN_RIGHT, va);

  va_end(va);
}

void
Table::add_fmt_align(const char* fmt, Alignment align, ...)
{
  va_list va;
  va_start(va, align);

  add_vfmt_align(fmt, align, va);

  va_end(va);
}

void
Table::add_vfmt_align(const char* fmt, Alignment align, va_list va)
{
  char str[128];
  vsnprintf(str, sizeof(str), fmt, va);

  assert(m_rows.size() > 0);
  m_rows[m_rows.size() - 1].push_back(cell_t(str, align));
}

void
Table::add_delimiter()
{
  m_rows.push_back(TableRow::create_delimiter());
}

void
Table::print()
{
  print_with_indent(0);
}

void
Table::print_spaces(int n)
{
  for (int i = 0; i < n; i++) {
    putchar(' ');
  }
}

void
Table::print_with_indent(int indent)
{
  // Figure out how wide each column has to be.
  vector<size_t> col_widths;
  for (vector<TableRow>::const_iterator row = m_rows.begin();
       row != m_rows.end(); ++row) {
    if (col_widths.size() < row->size()) {
      col_widths.resize(row->size(), 0);
    }

    for (size_t i = 0; i < row->size(); i++) {
      col_widths[i] = max(col_widths[i], row->at(i).first.length());
    }
  }

  // Figure out the table's full width.
  int table_width = 0;
  for (size_t i = 0; i < col_widths.size(); i++) {
    table_width += col_widths[i] + 1;
  }
  table_width -= 1;

  // Print the multi-column header, if we have one.
  assert((m_multi_col_header_start == -1) == (m_multi_col_header_end == -1));
  assert(m_multi_col_header_start < (int) col_widths.size());
  assert(m_multi_col_header_end <= (int) col_widths.size());

  if (m_multi_col_header_start != -1) {
    print_spaces(indent);

    int i;
    for (i = 0; i < m_multi_col_header_start; i++) {
      print_spaces(col_widths[i] + 1);
    }

    putchar('|');

    // Figure out how many chars we have between the two |'s.
    int chars_between = 0;
    for (; i < m_multi_col_header_end - 1; i++) {
      chars_between += col_widths[i] + 1;
    }
    chars_between += col_widths[i++] - 2;

    int spaces_between = chars_between - m_multi_col_header_str.length();
    spaces_between = max(spaces_between, 0);
    print_spaces((spaces_between + 1)/ 2);
    fputs(m_multi_col_header_str.c_str(), stdout);
    print_spaces(spaces_between / 2);

    fputs("|\n", stdout);
  }

  // Now print each row.
  for (vector<TableRow>::const_iterator row = m_rows.begin();
       row != m_rows.end(); ++row) {
    print_spaces(indent);

    if (row->is_delimiter()) {
      for (int i = 0; i < table_width; i++) {
        putchar('-');
      }
      putchar('\n');
      continue;
    }

    for (size_t i = 0; i < row->size(); i++) {
      const cell_t& cell = row->at(i);
      const char* fmt_string = cell.second == ALIGN_RIGHT ? "%*s" : "%-*s";
      printf(fmt_string, col_widths[i], cell.first.c_str());
      if (i != row->size() - 1) {
        putchar(' ');
      }
    }
    putchar('\n');
  }
}


