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
#include <string>

/**
 * A simple class for generating tables of aligned data printed to stdout.
 *
 * Example use:
 *
 *   Table t;
 *   t.start_row();
 *   t.add("NAME", Table::ALIGN_LEFT);
 *   t.add("POSITION");
 *   t.add("SALARY");
 *
 *   t.add_delimiter();
 *
 *   t.start_row();
 *   t.add("Who");
 *   t.add("First");
 *   t.add_fmt("$%0.1f", 42.2);
 *
 *   t.start_row();
 *   t.add("What");
 *   t.add("Second");
 *
 *   t.start_row();
 *   t.add("I don't know");
 *   t.add("Third");
 *   t.add_fmt("$%d", 24);
 *
 *   t.print();
 *
 * This prints the following table.
 *
 *   NAME         POSITION SALARY
 *   ----------------------------
 *            Who    First  $42.2
 *           What   Second
 *   I don't know    Third    $24
 *
 */
class Table
{
public:
  enum Alignment {
    ALIGN_LEFT,
    ALIGN_RIGHT
  };

  Table();

  /**
   * Stick a header over the given columns.
   *
   * Right now only one multi-column header is supported per table.
   */
  void multi_col_header(const char* val, int start_col, int end_col);

  /**
   * Start a new row in the table.
   *
   * This must be called before any calls to add() or add_fmt().
   */
  void start_row();

  /**
   * Add a value to the current row in the table.
   */
  void add(const char* val, Alignment align = ALIGN_RIGHT);
  void add(const std::string& val, Alignment align = ALIGN_RIGHT);
  void add(int val, Alignment align = ALIGN_RIGHT);
  void add_fmt(const char* format, ...);
  void add_fmt_align(const char* format, Alignment align, ...);

  /**
   * Add a whole-row delimiter to the table after the current row.
   *
   * Note that this does not implicitly call start_row().
   */
  void add_delimiter();

  /**
   * Print the table to stdout.
   */
  void print();

  /*
   * Print the table to stdout, indenting each row by |indent| spaces.
   */
  void print_with_indent(int indent);

private:
  typedef std::pair<std::string, Alignment> cell_t;

  class TableRow : public std::vector<cell_t>
  {
  public:
    static TableRow create()
    {
      return TableRow(false);
    }

    static TableRow create_delimiter()
    {
      return TableRow(true);
    }

    bool is_delimiter() const
    {
      return m_is_delimiter;
    }

  private:
    TableRow(bool is_delimiter)
      : m_is_delimiter(is_delimiter)
    {}

    bool m_is_delimiter;
  };

  std::vector<TableRow> m_rows;

  // Right now we only support one multi-col header.
  std::string m_multi_col_header_str;
  int m_multi_col_header_start;
  int m_multi_col_header_end;

  void add_vfmt_align(const char* fmt, Alignment align, va_list va);
  void print_spaces(int n);
};
