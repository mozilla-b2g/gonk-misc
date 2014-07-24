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

#include <map>
#include <vector>
#include <string>
#include <sstream>

/**
 * A simple class for accumulating data to output in JSON format.
 *
 * Example use:
 *
 *   JSON::Object obj, tmp
 *   JSON::Array arr;
 *
 *   tmp.add("foo", "bar");
 *   arr.push_back(1);
 *   arr.push_back("blah");
 *
 *   obj.add("key1", "value");
 *   obj.add("key2", 1234);
 *   obj.add("key3", tmp);
 *   obj.add("key4", arr);
 *   obj.add("key5", true);
 *   obj.add("key6", JSON::Null);
 *
 *   std::cout << obj << std::endl;
 *
 * This prints the following JSON:
 *
 * { "key1":"value", "key2": 1234, "key3": { "foo": "bar" }, "key4": [ 1, "blah" ], "key5": true, "key6": null }
 * 
 */

namespace JSON {

std::string const Null = "null";

class Object {
  typedef std::map<std::string, std::string>::const_iterator const_iterator;

  public:
    Object() {}
    Object( Object const & rhs ) : members(rhs.members) {}
    
    void add( std::string const &, std::string const & );
    void add( std::string const &, bool );

    // use stringstream to convert the value to a string
    template< typename T >
    void add( std::string k, const T& v ) {
      std::stringstream ss;
      ss << v;
      members[k] = ss.str();
    }

    friend std::ostream& operator<<( std::ostream& out, Object const & obj ) {
      Object::const_iterator bgn = obj.members.begin();
      Object::const_iterator end = obj.members.end();
      out << "{ ";

      for ( Object::const_iterator itr = bgn; itr != end; ++itr ) {
        out << ((itr != bgn) ? ", " : "") 
            << "\"" << itr->first << "\": " << itr->second;
      }

      out << " }";
      return out;
    }

  private:
    std::map<std::string, std::string> members;
};

class Array {
  typedef std::vector<std::string>::const_iterator const_iterator;

  public:
    Array() {}
    Array( Array const & rhs ) : members(rhs.members) {}

    void push_back( std::string const & );
    void push_back( bool );

    // use stringstream to convert the parameter to a string first
    template< typename T >
    void push_back( const T& v ) {
      std::stringstream ss;
      ss << v;
      members.push_back( ss.str() );
    }

    friend std::ostream& operator<<( std::ostream& out, Array const & arr ) {
      Array::const_iterator bgn = arr.members.begin();
      Array::const_iterator end = arr.members.end();
      
      out << "[ ";

      for ( Array::const_iterator itr = bgn; itr != end; ++itr ) {
        out << ((itr != bgn) ? ", " : "")
            << (*itr);
      }

      out << " ]";
      return out;
    }
        
  private:
    std::vector<std::string> members;
};

}
  
