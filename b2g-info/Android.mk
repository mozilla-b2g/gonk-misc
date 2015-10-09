# Copyright (C) 2013 Mozilla Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

ifeq ($(filter-out 0 1 2 3 4 5,$(MAJOR_VERSION)),)
include external/stlport/libstlport.mk
endif

LOCAL_MODULE       := b2g-info
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := b2g-info.cpp process.cpp processlist.cpp table.cpp utils.cpp
LOCAL_FORCE_STATIC_EXECUTABLE := false

ifeq ($(filter-out 0 1 2 3 4 5,$(MAJOR_VERSION)),)
LOCAL_SHARED_LIBRARIES := libstlport
endif

include $(BUILD_EXECUTABLE)
