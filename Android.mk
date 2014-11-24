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

gonk_misc_LOCAL_PATH := $(LOCAL_PATH)
include $(call all-subdir-makefiles)
LOCAL_PATH := $(gonk_misc_LOCAL_PATH)

ifneq ($(TARGET_PROVIDES_B2G_INIT_RC),true)
include $(CLEAR_VARS)
LOCAL_MODULE       := init.rc
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH  := $(TARGET_ROOT_OUT)
include $(BUILD_PREBUILT)

$(LOCAL_BUILT_MODULE):
	mkdir -p $(@D)
	echo import /init.b2g.rc > $@
	cat system/core/rootdir/init.rc >> $@
ifeq ($(PLATFORM_SDK_VERSION),15)
	patch $@ gonk-misc/init.rc.patch
endif
endif

include $(CLEAR_VARS)
LOCAL_MODULE       := init.b2g.rc
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES    := init.b2g.rc
LOCAL_MODULE_PATH  := $(TARGET_ROOT_OUT)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := b2g.sh
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := DATA
LOCAL_SRC_FILES    := b2g.sh
LOCAL_MODULE_PATH  := $(TARGET_OUT_EXECUTABLES)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := httpd.conf
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES    := httpd.conf
LOCAL_MODULE_PATH  := $(TARGET_OUT_ETC)
include $(BUILD_PREBUILT)

ifneq ($(wildcard frameworks/av/services/audioflinger),)
include $(CLEAR_VARS)
LOCAL_MODULE       := gonksched
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := gonksched.cpp
LOCAL_SHARED_LIBRARIES := libbinder libutils libcutils
LOCAL_STATIC_LIBRARIES := libscheduling_policy

LOCAL_C_INCLUDES := frameworks/av/services/audioflinger
include $(BUILD_EXECUTABLE)
endif

ifneq ($(wildcard frameworks/native/libs/binder/IAppOpsService.cpp),)
include $(CLEAR_VARS)
LOCAL_MODULE       := fakeappops
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := fakeappops.cpp
LOCAL_SHARED_LIBRARIES := libbinder libutils
include $(BUILD_EXECUTABLE)
endif

include $(CLEAR_VARS)
LOCAL_MODULE       := b2g-ps
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := b2g-ps
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := b2g-procrank
LOCAL_MODULE_TAGS  := debug	# should match system/extras/procrank/Android.mk
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := b2g-procrank
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := killer
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := killer.cpp
LOCAL_FORCE_STATIC_EXECUTABLE := true	# since this is setuid root
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


ifneq ($(DISABLE_SOURCES_XML),true)
ifneq (,$(realpath .repo/manifest.xml))
#
# Include a copy of the repo manifest that has the revisions used
#
include $(CLEAR_VARS)
LOCAL_MODULE       := sources.xml
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := DATA
LOCAL_MODULE_PATH  := $(TARGET_OUT)

ADD_REVISION := $(abspath $(LOCAL_PATH)/add-revision.py)

include $(BUILD_PREBUILT)

# Don't use dependencies on .repo/manifest.xml, since the result can
# change even when .repo/manifest.xml doesn't.
$(LOCAL_BUILT_MODULE): FORCE
	mkdir -p $(@D)
	python $(ADD_REVISION) --b2g-path . \
		--tags .repo/manifest.xml --force --output $@
endif
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
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_PATH := $(TARGET_OUT)
include $(BUILD_PREBUILT)

PRESERVE_B2G_WEBAPPS := 0

# In user (production) builds, gaia goes in $(TARGET_OUT)/b2g/webapps
# This flag helps us preserve the directory when cleaning out $(TARGET_OUT)/b2g
ifneq ($(filter user userdebug, $(TARGET_BUILD_VARIANT)),)
B2G_SYSTEM_APPS := 1
B2G_UPDATER ?= 1
else
B2G_UPDATER ?= 0
endif

ifeq ($(B2G_SYSTEM_APPS),1)
PRESERVE_B2G_WEBAPPS := 1
endif

ifeq ($(ENABLE_GLOBAL_PRELINK),1)
APRIORI := $(HOST_OUT_EXECUTABLES)/apriori$(HOST_EXECUTABLE_SUFFIX)
PRELINK_MAP := $(abspath $(LOCAL_PATH)/prelink.map)
ifeq ($(MOZ_DMD),1)
PRELOAD_LIBS := -Dlibmozglue.so -Dlibdmd.so
else
PRELOAD_LIBS := -Dlibmozglue.so
endif
endif

GAIA_PATH ?= $(abspath $(LOCAL_PATH)/../gaia)
ifeq (,$(wildcard $(GAIA_PATH)))
$(error GAIA_PATH is not defined)
endif

# Preserve the /system/b2g/distribution/ directory as its contents are not
# populated as a part of this rule, and may even be populated before this
# rule executes
PRESERVE_DIRS := distribution
ifeq ($(PRESERVE_B2G_WEBAPPS), 1)
PRESERVE_DIRS += webapps
endif
$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE) gaia-prefs $(APRIORI) $(PRELINK_MAP)
	@echo Install dir: $(TARGET_OUT)/b2g

	rm -rf $(filter-out $(addprefix $(TARGET_OUT)/b2g/,$(PRESERVE_DIRS)),$(wildcard $(TARGET_OUT)/b2g/*))

	mkdir -p $(TARGET_OUT)/b2g/defaults/pref
	cp -r $(GAIA_PATH)/profile/defaults/* $(TARGET_OUT)/b2g/defaults/
ifneq (,$(EXPORT_DEVICE_PREFS))
	cp -n $(EXPORT_DEVICE_PREFS)/*.js $(TARGET_OUT)/b2g/defaults/pref/
endif

	cd $(TARGET_OUT) && tar xvfz $(abspath $<)

ifeq ($(ENABLE_GLOBAL_PRELINK),1)
	$(APRIORI)  \
		$(PRELOAD_LIBS) \
		-L$(TARGET_OUT_SHARED_LIBRARIES) \
		-L$(TARGET_OUT)/b2g \
		-p $(PRELINK_MAP) \
		`find $(TARGET_OUT)/b2g -name "lib*.so"`
endif

# Target to create Gecko update package (MAR)
DIST_B2G_UPDATE_DIR := $(GECKO_OBJDIR)/dist/b2g-update
UPDATE_PACKAGE_TARGET := $(DIST_B2G_UPDATE_DIR)/b2g-$(TARGET_DEVICE)-gecko-update.mar
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

GECKO_LIB_DEPS := \
	libc.so \
	libdl.so \
	liblog.so \
	libm.so \
	libmedia.so \
	libmtp.so \
	libsensorservice.so \
	libstagefright.so \
	libstagefright_omx.so \
	libsysutils.so \
	$(NULL)

ifneq ($(wildcard external/dbus),)
GECKO_LIB_DEPS += libdbus.so
endif

ifneq ($(wildcard system/core/libsuspend),)
GECKO_LIB_DEPS += libsuspend.so
endif

ifneq ($(strip $(SHOW_COMMANDS)),)
SKIP_DASH_S = 1
endif

ifneq ($(strip $(FORCE_GECKO_BUILD_OUTPUT)),)
SKIP_DASH_S = 1
endif

ifneq ($(strip $(SKIP_DASH_S)),1)
SHOW_COMMAND_GECKO = -s
endif

ifeq ($(strip $(GECKO_TOOLS_PREFIX)),)
GECKO_TOOLS_PREFIX = $(TARGET_TOOLS_PREFIX)
endif

.PHONY: $(LOCAL_BUILT_MODULE)
$(LOCAL_BUILT_MODULE): $(TARGET_CRTBEGIN_DYNAMIC_O) $(TARGET_CRTEND_O) $(addprefix $(TARGET_OUT_SHARED_LIBRARIES)/,$(GECKO_LIB_DEPS))
	(echo "export GECKO_OBJDIR=$(abspath $(GECKO_OBJDIR))"; \
	echo "export GECKO_TOOLS_PREFIX=$(abspath $(GECKO_TOOLS_PREFIX))"; \
	echo "export PRODUCT_OUT=$(abspath $(PRODUCT_OUT))" ) > .var.profile
	export CONFIGURE_ARGS="$(GECKO_CONFIGURE_ARGS)" && \
	export GONK_PRODUCT="$(TARGET_DEVICE)" && \
	export TARGET_ARCH="$(TARGET_ARCH)" && \
	export TARGET_BUILD_VARIANT="$(TARGET_BUILD_VARIANT)" && \
	export PLATFORM_SDK_VERSION="$(PLATFORM_SDK_VERSION)" && \
	export HOST_OS="$(HOST_OS)" && \
	export GECKO_TOOLS_PREFIX="$(abspath $(GECKO_TOOLS_PREFIX))" && \
	export GONK_PATH="$(abspath .)" && \
	export GECKO_OBJDIR="$(abspath $(GECKO_OBJDIR))" && \
	export USE_CACHE=$(USE_CCACHE) && \
	export MOZCONFIG="$(abspath $(MOZCONFIG_PATH))" && \
	export EXTRA_INCLUDE="-include $(UNICODE_HEADER_PATH)" && \
	export DISABLE_JEMALLOC="$(DISABLE_JEMALLOC)" && \
	export B2G_UPDATER="$(B2G_UPDATER)" && \
	export B2G_UPDATE_CHANNEL="$(B2G_UPDATE_CHANNEL)" && \
	export ARCH_ARM_VFP="$(ARCH_ARM_VFP)" && \
	echo $(MAKE) -C $(GECKO_PATH) -f client.mk $(SHOW_COMMAND_GECKO) MOZ_MAKE_FLAGS= && \
	$(MAKE) -C $(GECKO_PATH) -f client.mk $(SHOW_COMMAND_GECKO) MOZ_MAKE_FLAGS= && \
	rm -f $(GECKO_OBJDIR)/dist/b2g-*.tar.gz && \
	for LOCALE in $(MOZ_CHROME_MULTILOCALE); do \
          $(MAKE) -C $(GECKO_OBJDIR)/b2g/locales merge-$$LOCALE LOCALE_MERGEDIR=$(GECKO_OBJDIR)/b2g/locales/merge-$$LOCALE && \
          $(MAKE) -C $(GECKO_OBJDIR)/b2g/locales chrome-$$LOCALE LOCALE_MERGEDIR=$(GECKO_OBJDIR)/b2g/locales/merge-$$LOCALE ; \
	done && \
	$(MAKE) -C $(GECKO_OBJDIR) package && \
	mkdir -p $(@D) && cp $(GECKO_OBJDIR)/dist/b2g-*.tar.gz $@

MAKE_SYM_STORE_PATH := \
  $(abspath $(PRODUCT_OUT)/symbols) \
  $(abspath $(PRODUCT_OUT)/system/vendor/lib) \
  $(abspath $(GECKO_OBJDIR)/dist/bin) \
  $(NULL)

# Override the defaults so we don't try to strip
# system libraries.
MAKE_SYM_STORE_ARGS := --vcs-info

.PHONY: buildsymbols uploadsymbols
buildsymbols uploadsymbols:
	$(MAKE) -C $(GECKO_OBJDIR) $@ MAKE_SYM_STORE_PATH="$(MAKE_SYM_STORE_PATH)" MAKE_SYM_STORE_ARGS="$(MAKE_SYM_STORE_ARGS)"

package-tests: gaia-tests-zip

TEST_DIR=$(abspath $(PRODUCT_OUT)/tests)
.PHONY: package-tests
package-tests:
	rm -rf $(TEST_DIR)
	mkdir $(TEST_DIR)
	cp gaia/gaia-tests.zip $(TEST_DIR)
	$(MAKE) -C $(GECKO_OBJDIR) package-tests && \
	cp $(GECKO_OBJDIR)/dist/*.tests*zip $(TEST_DIR)
	cd $(GECKO_PATH)/testing && zip -r $(TEST_DIR)/gaia-tests.zip marionette/client/* mozbase/*

EMULATOR_FILES := \
	.config \
	load-config.sh \
	run-emulator.sh \
	$(HOST_OUT)/bin/adb \
	$(HOST_OUT)/bin/emulator \
	$(HOST_OUT)/bin/emulator-arm \
	$(HOST_OUT)/bin/mksdcard \
	$(HOST_OUT)/bin/qemu-android-x86 \
	$(HOST_OUT)/lib \
	development/tools/emulator/skins \
	prebuilts/qemu-kernel/arm/kernel-qemu-armv7 \
	$(PRODUCT_OUT)/system/build.prop \
	$(PRODUCT_OUT)/system.img \
	$(PRODUCT_OUT)/userdata.img \
	$(PRODUCT_OUT)/ramdisk.img
EMULATOR_ARCHIVE:="$(OUT_DIR)/emulator.tar.gz"
package-emulator: $(EMULATOR_ARCHIVE)
$(EMULATOR_ARCHIVE): $(EMULATOR_FILES)
	echo "Creating emulator archive at $@" && \
	rm -f $@ && \
	tar -cvzf $@ --transform 's,^,b2g-distro/,S' --show-transformed-names $^

B2G_FOTA_UPDATE_MAR := fota-$(TARGET_DEVICE)-update.mar
B2G_FOTA_UPDATE_FULL_MAR := fota-$(TARGET_DEVICE)-update-full.mar
B2G_FOTA_UPDATE_ZIP := fota/partial/update.zip
B2G_FOTA_UPDATE_FULL_ZIP := fota/full/update.zip

.PHONY: gecko-update-fota gecko-update-fota-full
gecko-update-fota: $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_MAR)
gecko-update-fota-full: $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_MAR)

B2G_FOTA_FSTYPE := yaffs2
B2G_FOTA_SYSTEM_PARTITION := "system"
B2G_FOTA_DATA_PARTITION := "userdata"

B2G_FOTA_DIRS ?= "system/b2g"
B2G_FOTA_SYSTEM_FILES := $(PRODUCT_OUT)/system.files

define detect-fstype
  $(if $(filter true, $(INTERNAL_USERIMAGES_USE_EXT)),
    $(eval B2G_FOTA_FSTYPE := $(INTERNAL_USERIMAGES_EXT_VARIANT)))
  $(if $(filter true, $(TARGET_USERIMAGES_USE_UBIFS)),
    $(eval B2G_FOTA_FSTYPE := "ubifs"))
  $(info Using $(B2G_FOTA_FSTYPE) filesystem)
endef

FSTAB_TYPE := recovery
# $(1): recovery_fstab
#
# Android recovery fstab file format is like:
# /system ext4 /dev/...
#
# Linux fstab file format is like:
# /dev/... /system ext4
#
# Linux fstab file format is also like(ubifs):
# system /system ubifs
#
# We will first probe for any line starting with '/dev' or
# NOT starting with '/' that contains /system.
# If we find any, it means we have a Linux fstab.
# Otherwise it means it's an Android recovery fstab.
define detect-partitions
  $(eval FSTAB_FILE := $(basename $(notdir $(1))))

  $(if $(FSTAB_FILE),
    $(eval STARTS_WITH_DEV := $(shell grep '^/dev/' $(1) | grep '/system'))
    $(eval STARTS_WITH_NAME := $(shell grep -v '^\#' $(1) | grep -v '^/' | grep '/system'))
    $(if $(filter /system, $(STARTS_WITH_DEV) $(STARTS_WITH_NAME)),
      $(eval FSTAB_TYPE := linux))

    $(info Extracting partitions from $(FSTAB_TYPE) fstab ($(1)))

    $(if $(filter linux, $(FSTAB_TYPE)),
      $(eval B2G_FOTA_SYSTEM_PARTITION := $(shell grep -v '^\#' $(1) | grep '\s\+/system\s\+' | awk '{ print $$1 }'))
      $(eval B2G_FOTA_DATA_PARTITION := $(shell grep -v '^\#' $(1) | grep '\s\+/data\s\+' | awk '{ print $$1 }'))
    )

    $(if $(filter recovery, $(FSTAB_TYPE)),
      $(eval B2G_FOTA_SYSTEM_PARTITION := $(shell grep -v '^\#' $(1) | grep '^/system\s\+' | awk '{ print $$3 }'))
      $(eval B2G_FOTA_DATA_PARTITION := $(shell grep -v '^\#' $(1) | grep '^/data\s\+' | awk '{ print $$3 }'))
    ),

    $(if $(filter ext%, $(B2G_FOTA_FSTYPE)),
      $(warning Ext FS but no recovery fstab. Using values specified by env: SYSTEM_PARTITION and DATA_PARTITION:)
      $(warning SYSTEM_PARTITION @ $(SYSTEM_PARTITION))
      $(warning DATA_PARTITION @ $(DATA_PARTITION))
      $(if $(SYSTEM_PARTITION),
        $(if $(DATA_PARTITION),
          $(eval B2G_FOTA_SYSTEM_PARTITION := $(SYSTEM_PARTITION))
          $(eval B2G_FOTA_DATA_PARTITION := $(DATA_PARTITION)),
          $(error No DATA_PARTITION)
        ),
        $(error No SYSTEM_PARTITION)
      ),
      $(info No recovery, but not Ext FS)
    )
  )

  $(info Mounting /system from $(B2G_FOTA_SYSTEM_PARTITION))
  $(info Mounting /data   from $(B2G_FOTA_DATA_PARTITION))
endef

define detect-update-bin
  $(if $(wildcard $(TARGET_UPDATE_BINARY)),
    $(eval FOTA_UPDATE_BIN := --update-bin $(TARGET_UPDATE_BINARY)))
endef

define setup-fs
  $(call detect-fstype)
  $(call detect-partitions,$(recovery_fstab))
  $(call detect-update-bin)
endef

B2G_FOTA_FLASH_SCRIPT := tools/update-tools/build-flash-fota.py
B2G_FOTA_FLASH_MAR_SCRIPT := tools/update-tools/build-fota-mar.py

$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_MAR): $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_ZIP)
	@$(B2G_FOTA_FLASH_MAR_SCRIPT) --output $@ $^

$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_MAR): $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_ZIP)
	@$(B2G_FOTA_FLASH_MAR_SCRIPT) --output $@ $^

# We want to rebuild this list everytime
.PHONY: $(B2G_FOTA_SYSTEM_FILES)
$(B2G_FOTA_SYSTEM_FILES): $(PRODUCT_OUT)/system.img
	@(for d in $(B2G_FOTA_DIRS); do find $(PRODUCT_OUT)/$$d; done;) | sed -e 's|$(PRODUCT_OUT)/||g' > $@

# We temporarily remove Android'd Java from the path
# Otherwise, our fake java will be used to run signapk.jar
B2G_FOTA_ENV_PATH := $(shell echo "$$PATH" | sed -e 's|$(ANDROID_JAVA_TOOLCHAIN)||g')

$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_ZIP): $(B2G_FOTA_SYSTEM_FILES) $(PRODUCT_OUT)/system.img
	mkdir -p `dirname $@` || true
	$(call setup-fs)
	$(info Generating FOTA update package)
	@PATH="$(B2G_FOTA_ENV_PATH)" $(B2G_FOTA_FLASH_SCRIPT) \
	    $(FOTA_UPDATE_BIN) \
	    --sdk-version $(PLATFORM_SDK_VERSION) \
	    --system-dir $(PRODUCT_OUT)/system \
	    --system-fs-type $(B2G_FOTA_FSTYPE) \
	    --system-location $(B2G_FOTA_SYSTEM_PARTITION) \
	    --data-fs-type $(B2G_FOTA_FSTYPE) \
	    --data-location $(B2G_FOTA_DATA_PARTITION) \
	    --fota-type partial \
	    --fota-dirs "$(B2G_FOTA_DIRS)" \
	    --fota-files $(B2G_FOTA_SYSTEM_FILES) \
	    --fota-check-device-name "$(TARGET_DEVICE)" \
	    --fota-check-gonk-version \
	    --output $@

$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_ZIP): $(PRODUCT_OUT)/system.img
	mkdir -p `dirname $@` || true
	$(call setup-fs)
	$(info Generating full FOTA update package)
	@PATH="$(B2G_FOTA_ENV_PATH)" $(B2G_FOTA_FLASH_SCRIPT) \
	    $(FOTA_UPDATE_BIN) \
	    --sdk-version $(PLATFORM_SDK_VERSION) \
	    --system-dir $(PRODUCT_OUT)/system \
	    --system-fs-type $(B2G_FOTA_FSTYPE) \
	    --system-location $(B2G_FOTA_SYSTEM_PARTITION) \
	    --data-fs-type $(B2G_FOTA_FSTYPE) \
	    --data-location $(B2G_FOTA_DATA_PARTITION) \
	    --fota-check-device-name "$(TARGET_DEVICE)" \
	    --output $@
