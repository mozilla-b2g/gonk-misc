# Copyright (C) 2012 Mozilla Foundation
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

ifneq ($(TARGET_PROVIDES_B2G_INIT_RC),true)
include $(CLEAR_VARS)
LOCAL_MODULE       := init.rc
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH  := $(TARGET_ROOT_OUT)
include $(BUILD_PREBUILT)

$(LOCAL_BUILT_MODULE):
	mkdir -p $(@D)
	echo import /init.b2g.rc > $@
	cat system/core/rootdir/init.rc >> $@
	patch $@ gonk-misc/init.rc.patch
endif

include $(CLEAR_VARS)
LOCAL_MODULE       := init.b2g.rc
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES    := init.b2g.rc
LOCAL_MODULE_PATH  := $(TARGET_ROOT_OUT)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := b2g.sh
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := DATA
LOCAL_SRC_FILES    := b2g.sh
LOCAL_MODULE_PATH  := $(TARGET_OUT_EXECUTABLES)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := httpd.conf
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES    := httpd.conf
LOCAL_MODULE_PATH  := $(TARGET_OUT_ETC)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := fakeperm
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := fakeperm.cpp
LOCAL_SHARED_LIBRARIES := libbinder libutils
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE       := b2g-ps
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := b2g-ps
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := b2g-procrank
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := b2g-procrank
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := killer
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := killer.cpp
LOCAL_SHARED_LIBRARIES :=
include $(BUILD_EXECUTABLE)

$(OUT_DOCS)/api-stubs-timestamp:
	mkdir -p `dirname $@`
	touch $@
	mkdir -p $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/android_stubs_current_intermediates/src

$(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk:
	mkdir -p `dirname $@`
	touch `dirname $@`/dummy
	zip $@ `dirname $@`/dummy


ifneq (,$(realpath .repo/manifest.xml))
#
# Include a copy of the repo manifest that has the revisions used
#
include $(CLEAR_VARS)
LOCAL_MODULE       := sources.xml
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := DATA
LOCAL_MODULE_PATH  := $(TARGET_OUT)

ADD_REVISION := $(abspath $(LOCAL_PATH)/add-revision.py)

include $(BUILD_PREBUILT)

$(LOCAL_BUILT_MODULE): .repo/manifest.xml
	mkdir -p $(@D)
	python $(ADD_REVISION) --b2g-path . \
		--tags $< --force --output $@
endif

#
# Gecko glue
#

include $(CLEAR_VARS)
GECKO_PATH ?= gecko
ifeq (,$(GECKO_OBJDIR))
GECKO_OBJDIR := $(TARGET_OUT_INTERMEDIATES)/objdir-gecko
endif
MOZCONFIG_PATH := $(LOCAL_PATH)/default-gecko-config
UNICODE_HEADER_PATH := $(abspath $(LOCAL_PATH)/Unicode.h)

LOCAL_MODULE := gecko
LOCAL_MODULE_CLASS := DATA
LOCAL_MODULE_TAGS := optional eng
LOCAL_MODULE_PATH := $(TARGET_OUT)
include $(BUILD_PREBUILT)

PRESERVE_B2G_WEBAPPS := 0
# In user (production) builds, gaia goes in $(TARGET_OUT)/b2g/webapps
# This flag helps us preserve the directory when cleaning out $(TARGET_OUT)/b2g
ifneq ($(filter user userdebug, $(TARGET_BUILD_VARIANT)),)
PRESERVE_B2G_WEBAPPS := 1
endif

$(LOCAL_INSTALLED_MODULE):
	@echo Install dir: $(TARGET_OUT)/b2g

ifeq ($(PRESERVE_B2G_WEBAPPS), 1)
	mv $(TARGET_OUT)/b2g/webapps $(TARGET_OUT)
endif

# We need to keep user.js around
	mv $(TARGET_OUT)/b2g/user.js $(TARGET_OUT)

	rm -rf $(TARGET_OUT)/b2g
	mkdir -p $(TARGET_OUT)/b2g

ifeq ($(PRESERVE_B2G_WEBAPPS), 1)
	mv $(TARGET_OUT)/webapps $(TARGET_OUT)/b2g
endif

	mkdir -p $(TARGET_OUT)/b2g/defaults/pref
# rename user_pref() to pref() in user.js
	sed s/user_pref\(/pref\(/ $(TARGET_OUT)/user.js > $(TARGET_OUT)/b2g/defaults/pref/user.js
        rm $(TARGET_OUT)/user.js
	cd $(TARGET_OUT) && tar xvfz $(abspath $<)

# Target to create Gecko update package (MAR)
DIST_B2G_UPDATE_DIR := $(GECKO_OBJDIR)/dist/b2g-update
UPDATE_PACKAGE_TARGET := $(DIST_B2G_UPDATE_DIR)/b2g-gecko-update.mar
MAR := $(GECKO_OBJDIR)/dist/host/bin/mar
MAKE_FULL_UPDATE := $(GECKO_PATH)/tools/update-packaging/make_full_update.sh

# Floating point operations hardware support
ARCH_ARM_VFP := toolchain-default
ifeq ($(ARCH_ARM_HAVE_VFP), true)
ARCH_ARM_VFP := vfp
endif
ifeq ($(ARCH_ARM_HAVE_VFP_D32), true)
ARCH_ARM_VFP := vfpv3
endif
ifeq ($(ARCH_ARM_HAVE_NEON), true)
ARCH_ARM_VFP := neon
endif

.PHONY: gecko-update-full
gecko-update-full:
	mkdir -p $(DIST_B2G_UPDATE_DIR)
	MAR=$(MAR) $(MAKE_FULL_UPDATE) $(UPDATE_PACKAGE_TARGET) $(TARGET_OUT)/b2g
	shasum -a 512 $(UPDATE_PACKAGE_TARGET)

GECKO_MAKE_FLAGS ?= -j16
GECKO_LIB_DEPS := \
	libm.so \
	libc.so \
	libdl.so \
	liblog.so \
	libmedia.so \
	libstagefright.so \
	libstagefright_omx.so \
	libdbus.so \
	libsensorservice.so \
	libsysutils.so \


.PHONY: $(LOCAL_BUILT_MODULE)
$(LOCAL_BUILT_MODULE): $(TARGET_CRTBEGIN_DYNAMIC_O) $(TARGET_CRTEND_O) $(addprefix $(TARGET_OUT_SHARED_LIBRARIES)/,$(GECKO_LIB_DEPS))
	export CONFIGURE_ARGS="$(GECKO_CONFIGURE_ARGS)" && \
	export GONK_PRODUCT="$(TARGET_DEVICE)" && \
	export TARGET_ARCH="$(TARGET_ARCH)" && \
	export HOST_OS="$(HOST_OS)" && \
	export TARGET_TOOLS_PREFIX="$(abspath $(TARGET_TOOLS_PREFIX))" && \
	export GONK_PATH="$(abspath .)" && \
	export GECKO_OBJDIR="$(abspath $(GECKO_OBJDIR))" && \
	export USE_CACHE=$(USE_CCACHE) && \
	export MAKE_FLAGS="$(GECKO_MAKE_FLAGS)" && \
	export MOZCONFIG="$(abspath $(MOZCONFIG_PATH))" && \
	export EXTRA_INCLUDE="-include $(UNICODE_HEADER_PATH)" && \
	export DISABLE_JEMALLOC="$(DISABLE_JEMALLOC)" && \
	export ARCH_ARM_VFP="$(ARCH_ARM_VFP)" && \
	echo $(MAKE) -C $(GECKO_PATH) -f client.mk -s && \
	$(MAKE) -C $(GECKO_PATH) -f client.mk -s && \
	rm -f $(GECKO_OBJDIR)/dist/b2g-*.tar.gz && \
	$(MAKE) -C $(GECKO_OBJDIR) package && \
	mkdir -p $(@D) && cp $(GECKO_OBJDIR)/dist/b2g-*.tar.gz $@
