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
LOCAL_MODULE       := fakebattery
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := fakebattery.cpp
LOCAL_SHARED_LIBRARIES := libbinder libutils
include $(BUILD_EXECUTABLE)

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

ifneq ($(TARGET_DEVICE_BLOBS),)
### We enable this only if the device tree provides TARGET_DEVICE_BLOBS

# Intermediate targets
TARGET_BLOBS_SHA1_OUT := $(PRODUCT_OUT)/$(TARGET_DEVICE)-blobs-sha1-out.txt
TARGET_DEVICE_BLOBS_OUT := $(PRODUCT_OUT)/$(TARGET_DEVICE)-blobs-out.txt
TARGET_BLOBS_MAP := $(PRODUCT_OUT)/$(TARGET_DEVICE)-blobsmap.txt
TARGET_LISTFILES_BLOBS := $(PRODUCT_OUT)/$(TARGET_DEVICE)-listfiles_blobs.txt
TARGET_LISTFILES_NOBLOBS := $(PRODUCT_OUT)/$(TARGET_DEVICE)-listfiles_noblobs.txt
TARGET_BLOBS_DELETE_LIST := $(PRODUCT_OUT)/$(TARGET_DEVICE)-blobs-todelete.txt

# Final blob free targets
TARGET_BLOBS_INJECT_LIST := $(PRODUCT_OUT)/blobs-toinject.txt
TARGET_CMDLINE_FS := $(PRODUCT_OUT)/cmdline-fs.txt
TARGET_BLOBFREE_ZIP := $(PRODUCT_OUT)/blobfree.zip
TARGET_DEVICES_JSON := $(TARGET_DEVICE_DIR)/devices.json
TARGET_BLOBFREE_RECOVERY_FSTAB := $(PRODUCT_OUT)/recovery.fstab

# Final package
TARGET_BLOBFREE_PKG := $(PRODUCT_OUT)/$(TARGET_DEVICE).blobfree-dist.zip

# Producing map for blobs. We need to go deep with sha1 because the build might
# play behind our back, e.g., external/init_sh/Android.mk does symlink /init to
# /sbin/init.sh and moves real /init to /init.real. So we use find and sha1 to
# find potential dupes.
# This file will contain lines following this patter:
# <sha1>  <PRODUCT_OUT/ path>
#
# We only analyze root/ and system/ within PRODUCT_OUT/ since those should be
# enough to work on boot.img, recovery.img (root/) and system.img (system/).
.PHONY: $(TARGET_BLOBS_SHA1_OUT)
$(TARGET_BLOBS_SHA1_OUT):
	@find $(PRODUCT_OUT)/root/ $(PRODUCT_OUT)/system/ -type f | \
	xargs sha1sum | \
	sed -e "s|$(PRODUCT_OUT)/||g" > $@

# The source for identifying blobs can be in two formats. It is either a simple
# list of blobs in the device tree, or it is a .mk file produced by
# extract-files.sh (or a vendor-provided device-partial.mk file).
#
# Because the format of these two sources differ, we must process them to have
# them in a common format. We write a file to $OUT containing the list of blobs
# in the format:
# <vendor path>:<device path>
# where:
# vendor_path is the location in our build tree
# device_path is the location on the device
.PHONY: $(TARGET_DEVICE_BLOBS_OUT)
$(TARGET_DEVICE_BLOBS_OUT): $(TARGET_BLOBS_SHA1_OUT)
ifeq ($(TARGET_DEVICE_BLOBS_LIST),true)
	@rm -f $@ && touch $@; \
	grep -h '/' $(TARGET_DEVICE_BLOBS) | grep -v '^\s*#' | sed -e 's/^-\(.*\)/\1/' | while read line; \
	do \
		echo "$(TARGET_DEVICE_BLOBS_SRC_DIR)/$$line:system/$$line" >> $@; \
	done
else
	@rm -f $@ && touch $@; \
	grep -h ':' $(TARGET_DEVICE_BLOBS) | grep -v '^\s*#' | sed -e 's/^ *//' | sed -e 's/ *\\$$//' | grep ':[^=]' | while read line; \
	do \
		echo "$$line" >> $@; \
	done
endif

# Then, given list of device blob list files, we will identify where each blob
# is being used and we will produce a single blob mapping file. Each line will
# contain the mapping, following this pattern:
# <device path>:<blobfree distribution path>
#
# In case a blob is being used a several places (boot ramdisk, recovery
# ramdisk, ...), there will be multiple lines, which will differ by the second
# part of the mapping, the blobfree distribution path.
#
# So we extract both values and we cross-check this with the list of sha1 files
# such that we can identify three types of blobs:
#  (1) unused ones still referenced within .mk file
#  (2) blobs used only once
#  (3) blobs used at multiple places
#
# So, in case of (1) we just skip it. In case of (2) we compute the target
# within PRODUCT_OUT using the sha1 list results and we add this blob to the
# mapping. In case of (3), we do the same as in case of (2) but we generate
# the mapping for all the duped uses that have been identified.
#
# The data fed into while read line is the contents of the .mk files with
# comments, the PRODUCT_COPY_FILES statement, and whitespace stripped out. The
# -h flag to grep strips out the file information normally included in grep's
# output when run on multiple files. The grep -v removes comments, the first
# sed strips leading whitespace, the second sed removes trailing whitespace and
# \, and the final grep removes any line containing an assignment operator
# (:=).
.PHONY: $(TARGET_BLOBS_MAP)
$(TARGET_BLOBS_MAP): $(TARGET_BLOBS_SHA1_OUT) $(TARGET_DEVICE_BLOBS_OUT)
	@rm -f $@ && touch $@; \
	cat $(TARGET_DEVICE_BLOBS_OUT) | while read line; \
	do \
		vendor_src=$$(echo "$$line" | cut -d':' -f1); \
		builds_tgt=$$(echo "$$line" | cut -d':' -f2); \
		sha1=$$(sha1sum "$$vendor_src" | cut -d' ' -f1); \
		dupes=$$(grep "$$sha1" $(TARGET_BLOBS_SHA1_OUT)); \
		dupes_count=$$(echo "$$dupes" | wc -l); \
		if [ -z "$$dupes" -o $${dupes_count} -eq 0 ]; then \
			echo "Blob $$vendor_src is not used"; \
		else \
			if [ $${dupes_count} -eq 1 ]; then \
				target=$$(echo $$dupes | awk '{ print $$2 }'); \
				echo "$${vendor_src}:$${target}" >> $@; \
			elif [ $${dupes_count} -gt 1 ]; then \
				dupes_target=$$(echo "$$dupes" | awk '{ print $$2 }'); \
				for target in $$dupes_target; do \
					echo "$${vendor_src}:$${target}" >> $@; \
				done; \
			fi; \
		fi; \
	done

# Parameters for rebuilding filesystem
# We hardcode sparse for now
# b2g-installer builds system.img and userdata.img using make_ext4fs, which
# needs the hardcoded sparse flag, the partition size, and the output name.
# b2g-installer builds boot.img and recovery.img using mkbootimg, requiring the
# device-defined mkbootimg args
.PHONY: $(TARGET_CMDLINE_FS)
$(TARGET_CMDLINE_FS):
	echo "system.img: -s -l $(BOARD_SYSTEMIMAGE_PARTITION_SIZE) -a system" > $@
	echo "userdata.img: -s -l $(BOARD_USERDATAIMAGE_PARTITION_SIZE) -a userdata" >> $@
	echo "boot.img: $(BOARD_MKBOOTIMG_ARGS)" >> $@
	echo "recovery.img: $(BOARD_MKBOOTIMG_ARGS)" >> $@

# Building the list of blobs we want to delete from the ZIP file
# So we take the target files from the blob map and we mangle them to match
# what will be done in the ZIP file
.PHONY: $(TARGET_BLOBS_DELETE_LIST)
$(TARGET_BLOBS_DELETE_LIST): $(TARGET_LISTFILES_BLOBS) $(TARGET_BLOBS_MAP)
	@rm -f $@ && touch $@; \
	cut -d':' -f2 < $(TARGET_BLOBS_MAP) | sed -e 's|root/|ramdisk/|g' | while read l; \
	do \
		grep -i "$$l$$" $(TARGET_LISTFILES_BLOBS) | while read b; \
		do \
			echo $$b >> $@; \
		done; \
	done; \
	sort -o $@ < $@; mv $@ $@.tmp; uniq < $@.tmp > $@; rm $@.tmp

# Building the list of blobs we will want to reinject, from the device, so we
# need to make use of the source of the blob map.
# This reads all the device blob lists available using the hide filename (-h)
# flag, which means that it will find the first instance of the blob_in_mk
# variable in any blob list file.
# We need to retransform ramdisk/ into /
# We also force blacklisting blobs coming from "obj/" because somehow we
# have some in aries/shinano bobs list but this do not even exists on device
.PHONY: $(TARGET_BLOBS_INJECT_LIST)
$(TARGET_BLOBS_INJECT_LIST): $(TARGET_LISTFILES_BLOBS) $(TARGET_BLOBS_MAP) $(TARGET_DEVICE_BLOBS_OUT)
	@rm -f $@ && touch $@; \
	while read map; \
	do \
		blob_in_mk=$$(echo "$$map" | cut -d':' -f1); \
		blob_in_fs=$$(echo "$$map" | cut -d':' -f2); \
		source=$$(grep -h -m1 "^ *$$blob_in_mk:" $(TARGET_DEVICE_BLOBS_OUT) | sed -e 's/^ *//' | sed -e 's/ *\\$$//' | cut -d':' -f2 | grep -v '^obj/'); \
		l=$$(echo "$$blob_in_fs" | sed -e 's|root/|ramdisk/|g'); \
		if [ ! -z "$$source" ]; then \
			grep -i "$$l$$" $(TARGET_LISTFILES_BLOBS) | while read b; \
			do \
				reall="/$$(echo $$source | sed -e 's|root/||g')"; \
				echo "$$reall:$$b" >> $@; \
			done; \
		else \
			echo "Empty source for blob_in_mk=$$blob_in_mk blob_in_fs=$$blob_in_fs"; \
		fi; \
	done < $(TARGET_BLOBS_MAP); \
	sort -t ':' -k 2 -o $@ < $@; mv $@ $@.tmp; uniq < $@.tmp > $@; rm $@.tmp

# This will produce the blobfree main distribution file. We rely on the make
# target "target-files-package" that produces intermediate ready-to-use ZIP
# file and tree from which we can build upon.
$(TARGET_BLOBFREE_ZIP): target-files-package $(TARGET_BLOBS_DELETE_LIST)
	@cp $(BUILT_TARGET_FILES_PACKAGE) $@ && \
	zip --delete $@ $$(tr '\n' ' ' < $(TARGET_BLOBS_DELETE_LIST)); \
	zip --delete $@ "IMAGES/*" "OTA/*" "RADIO/*" "META/*"

.PHONY: $(TARGET_LISTFILES_BLOBS) $(TARGET_LISTFILES_NOBLOBS) compare-zipfiles
$(TARGET_LISTFILES_BLOBS): target-files-package
	@zipinfo -l2 $(BUILT_TARGET_FILES_PACKAGE) > $@

$(TARGET_LISTFILES_NOBLOBS): $(TARGET_BLOBFREE_ZIP)
	@zipinfo -l2 $(TARGET_BLOBFREE_ZIP) > $@

compare-zipfiles: $(TARGET_LISTFILES_BLOBS) $(TARGET_LISTFILES_NOBLOBS)
	diff -uw $(TARGET_LISTFILES_BLOBS) $(TARGET_LISTFILES_NOBLOBS) || true

# Necessary to ensure the recovery.fstab file name
# Prefers TARGET_RECOVERY_FSTAB but attempts to copy both in the event of
# failure.
$(TARGET_BLOBFREE_RECOVERY_FSTAB): $(TARGET_RECOVERY_FSTAB) $(recovery_fstab)
	cp -f $(TARGET_RECOVERY_FSTAB) $@ || cp -f $(recovery_fstab) $@

# CyanogenMod uses custom mkbootimg.sh scripts to generate the device tree
# image and we can't detect that here. We can at least force use of dt.img
# If we detect the custom script.
ifeq ($(BOARD_KERNEL_SEPARATED_DT),true)
ifneq ($(BOARD_CUSTOM_BOOTIMG_MK),)
INSTALLED_DTIMAGE_TARGET := $(PRODUCT_OUT)/dt.img
endif
endif

# Target controlling the build of the {user,addon}-facing ZIP distribution file,
# which will just contain all the dependencies within the root of the archive.
$(TARGET_BLOBFREE_PKG): $(TARGET_BLOBFREE_ZIP) $(TARGET_BLOBS_INJECT_LIST) $(TARGET_CMDLINE_FS) $(INSTALLED_DTIMAGE_TARGET) $(TARGET_DEVICES_JSON) $(TARGET_BLOBFREE_RECOVERY_FSTAB)
	rm $@ || true; \
	zip -r0 --junk-paths $@ $^

.PHONY: blobfree
blobfree: $(TARGET_BLOBFREE_PKG)
	echo "Built blobfree."

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
PRESERVE_DIRS += apps # This is for use with kanikani gaia branch
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
ifeq ($(TARGET_ARCH), arm)
	ifeq ($(ARCH_ARM_HAVE_VFP), true)
	ARCH_ARM_VFP := vfp
	endif
	ifeq ($(ARCH_ARM_HAVE_VFP_D32), true)
	ARCH_ARM_VFP := vfpv3
	endif
	ifeq ($(ARCH_ARM_HAVE_NEON), true)
	ARCH_ARM_VFP := neon
	endif
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

ifneq ($(PLATFORM_SDK_VERSION),15)
GECKO_LIB_DEPS += libmdnssd.so
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

# If our build target is multilib then we may want to build Gecko as the 2nd arch
ifeq ($(BUILD_MULTILIB_GECKO_AS_2ND_ARCH), true)
MULTILIB := 2ND_
# All 64bit arm64 targets support 32bit neon extensions
ifeq ($(TARGET_ARCH), arm64)
ARCH_ARM_VFP := neon
endif
endif

# Multilib complicates the obj dir in Gecko, so export it from here
GONK_OUT_INTERMEDIATES := $($(MULTILIB)TARGET_OUT_INTERMEDIATES)

ifeq ($(strip $(GECKO_TOOLS_PREFIX)),)
GECKO_TOOLS_PREFIX = $($(MULTILIB)TARGET_TOOLS_PREFIX)
endif

.PHONY: $(LOCAL_BUILT_MODULE)
$(LOCAL_BUILT_MODULE): $($(MULTILIB)TARGET_CRTBEGIN_DYNAMIC_O) $($(MULTILIB)TARGET_CRTEND_O) $(addprefix $($(MULTILIB)TARGET_OUT_SHARED_LIBRARIES)/,$(GECKO_LIB_DEPS))
	(echo "export GECKO_OBJDIR=$(abspath $(GECKO_OBJDIR))"; \
	echo "export GECKO_TOOLS_PREFIX=$(abspath $(GECKO_TOOLS_PREFIX))"; \
	echo "export PRODUCT_OUT=$(abspath $(PRODUCT_OUT))" ) > .var.profile
	export CONFIGURE_ARGS="$(GECKO_CONFIGURE_ARGS)" && \
	export GONK_OUT_INTERMEDIATES="$(GONK_OUT_INTERMEDIATES)" && \
	export GONK_PRODUCT="$(TARGET_DEVICE)" && \
	export TARGET_ARCH="$(TARGET_$(MULTILIB)ARCH)" && \
	export TARGET_BUILD_VARIANT="$(TARGET_BUILD_VARIANT)" && \
	export TARGET_C_INCLUDES="$(addprefix -isystem ,$(abspath $($(MULTILIB)TARGET_C_INCLUDES)))" && \
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
	export MALLOC_IMPL="$(MALLOC_IMPL)" && \
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
	$(HOST_OUT)/lib \
	development/tools/emulator/skins \
	prebuilts/qemu-kernel/arm/kernel-qemu-armv7 \
	$(PRODUCT_OUT)/system/build.prop \
	$(PRODUCT_OUT)/system.img \
	$(PRODUCT_OUT)/userdata.img \
	$(PRODUCT_OUT)/ramdisk.img

ifneq ($(filter 15 17 18, $(PLATFORM_SDK_VERSION)),)
EMULATOR_FILES += \
	$(HOST_OUT)/bin/qemu-android-x86
else
EMULATOR_FILES += \
	$(HOST_OUT)/bin/emulator-x86 \
	$(HOST_OUT)/usr/share/pc-bios/bios.bin \
	$(HOST_OUT)/usr/share/pc-bios/vgabios-cirrus.bin \
	prebuilts/qemu-kernel/x86/kernel-qemu
endif

EMULATOR_ARCHIVE:="$(OUT_DIR)/emulator.tar.gz"
package-emulator: $(EMULATOR_ARCHIVE)
$(EMULATOR_ARCHIVE): $(EMULATOR_FILES)
	echo "Creating emulator archive at $@" && \
	rm -f $@ && \
	tar -cvzf $@ --transform 's,^,b2g-distro/,S' --show-transformed-names $^

B2G_FOTA_UPDATE_MAR := fota-$(TARGET_DEVICE)-update.mar
B2G_FOTA_UPDATE_FULL_MAR := fota-$(TARGET_DEVICE)-update-full.mar
B2G_FOTA_UPDATE_FULLIMG_MAR := fota-$(TARGET_DEVICE)-update-fullimg.mar
B2G_FOTA_UPDATE_ZIP := fota/partial/update.zip
B2G_FOTA_UPDATE_FULL_ZIP := fota/full/update.zip
B2G_FOTA_UPDATE_FULLIMG_ZIP := fota/fullimg/update.zip

.PHONY: gecko-update-fota gecko-update-fota-full gecko-update-fota-fullimg
gecko-update-fota: $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_MAR)
gecko-update-fota-full: $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_MAR)
gecko-update-fota-fullimg: $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULLIMG_MAR)

B2G_FOTA_DIRS ?= "system/b2g"
B2G_FOTA_FILES ?= "system/bin/bluetoothd" \
                  "system/lib/libfdio.so" \
                  "system/bin/nfcd"

# We expand the content of all B2G_FOTA_DIRS into B2G_FOTA_FILES
B2G_FOTA_FILES += $(shell (for d in $(B2G_FOTA_DIRS); do find $(PRODUCT_OUT)/$$d; done;) | sed -e 's|$(PRODUCT_OUT)/||g')

B2G_FOTA_SYSTEM_FILES := $(PRODUCT_OUT)/system.files

B2G_FOTA_FLASH_SCRIPT := tools/update-tools/build-flash-fota.py
B2G_FOTA_FLASH_MAR_SCRIPT := tools/update-tools/build-fota-mar.py

$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_MAR): $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_ZIP)
	@$(B2G_FOTA_FLASH_MAR_SCRIPT) --output $@ $^

$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_MAR): $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_ZIP)
	@$(B2G_FOTA_FLASH_MAR_SCRIPT) --output $@ $^

$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULLIMG_MAR): $(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULLIMG_ZIP)
	@$(B2G_FOTA_FLASH_MAR_SCRIPT) --output $@ $^

# We want to rebuild this list everytime
.PHONY: $(B2G_FOTA_SYSTEM_FILES)
$(B2G_FOTA_SYSTEM_FILES): $(PRODUCT_OUT)/system.img
	@(for d in $(B2G_FOTA_FILES); do find $(PRODUCT_OUT)/$$d; done;) | sed -e 's|$(PRODUCT_OUT)/||g' > $@

# We temporarily remove Android'd Java from the path
# Otherwise, our fake java will be used to run signapk.jar
B2G_FOTA_ENV_PATH := $(shell echo "$$PATH" | sed -e 's|$(ANDROID_JAVA_TOOLCHAIN)||g')

# In case we have this set to true, then we will force formatting
# the userdata partition
ifeq ($(B2G_FOTA_WIPE_DATA),true)
B2G_FOTA_PARTS_FORMAT += "/data"
endif

# In case we have this set to true, then we will force formatting
# the cache partition
ifeq ($(B2G_FOTA_WIPE_CACHE),true)
B2G_FOTA_PARTS_FORMAT += "/cache"
endif

# B2G_FOTA_PARTS is expected to be a string like:
# "name:source name:source"
# with:
#  - name: device
#  - source: the $(OUT)/ .img file to pickup
ifneq ($(B2G_FOTA_PARTS),)
B2G_FOTA_RAW_PARTITIONS := --fota-partitions "$(B2G_FOTA_PARTS)"
endif

# This is the same as above, but we force this. When forcing this value, please
# keep in mind that the goal is to perform a full flash of as much as possible.
ifeq ($(B2G_FOTA_FULLIMG_PARTS),)
B2G_FOTA_FULLIMG_PARTS := --fota-partitions "/boot:boot.img /system:system.img /recovery:recovery.img /cache:cache.img $(B2G_FOTA_PARTS)"
else
B2G_FOTA_FULLIMG_PARTS := --fota-partitions "$(B2G_FOTA_FULLIMG_PARTS) $(B2G_FOTA_PARTS)"
endif

# Space separated list of partition mountpoint we should format
ifneq ($(B2G_FOTA_PARTS_FORMAT),)
B2G_FOTA_FORCE_FORMAT := --fota-format-partitions "$(B2G_FOTA_PARTS_FORMAT)"
endif

# This will build the list of dependencies against each .img file
ALL_FOTA_PARTITIONS := $(subst ",,$(filter %.img,$(B2G_FOTA_FULLIMG_PARTS) $(B2G_FOTA_RAW_PARTITIONS)))
ifneq ($(ALL_FOTA_PARTITIONS),)
B2G_FOTA_EXTRA_TARGETS := $(shell for px in $(ALL_FOTA_PARTITIONS); do echo $$px | cut -d':' -f2 | sort | uniq | grep '\.img$$' | sed -e 's|^|$(PRODUCT_OUT)/|g'; done;)
endif

B2G_FOTA_COMMON_TARGETS := $(PRODUCT_OUT)/system.img $(B2G_FOTA_EXTRA_TARGETS) updater
define B2G_FOTA_COMMON_VARIABLES
    --update-bin $(PRODUCT_OUT)/system/bin/updater \
    --sdk-version $(PLATFORM_SDK_VERSION) \
    --system-dir $(PRODUCT_OUT)/system \
    --system-fstab $(recovery_fstab) \
    --fota-sdcard "$(RECOVERY_EXTERNAL_STORAGE)" \
    --fota-check-device-name "$(TARGET_DEVICE)" \
    $(B2G_FOTA_RAW_PARTITIONS) \
    $(B2G_FOTA_FORCE_FORMAT)
endef

# The partial target will drop just what is needed
$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_ZIP): $(B2G_FOTA_SYSTEM_FILES) $(B2G_FOTA_COMMON_TARGETS)
	mkdir -p `dirname $@` || true
	$(info Generating FOTA update package)
	@PATH="$(B2G_FOTA_ENV_PATH)" $(B2G_FOTA_FLASH_SCRIPT) \
            $(B2G_FOTA_COMMON_VARIABLES) \
	    --fota-type partial \
	    --fota-dirs "$(B2G_FOTA_DIRS)" \
	    --fota-files $(B2G_FOTA_SYSTEM_FILES) \
	    --fota-check-gonk-version \
	    --output $@

# The full target will update completely the /system partition but just by extracting files
$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULL_ZIP): $(B2G_FOTA_COMMON_TARGETS)
	mkdir -p `dirname $@` || true
	$(info Generating full FOTA update package)
	@PATH="$(B2G_FOTA_ENV_PATH)" $(B2G_FOTA_FLASH_SCRIPT) \
            $(B2G_FOTA_COMMON_VARIABLES) \
	    --output $@

# The fullimg target should flash as much as possible, except userdata by default.
$(PRODUCT_OUT)/$(B2G_FOTA_UPDATE_FULLIMG_ZIP): $(B2G_FOTA_COMMON_TARGETS)
	mkdir -p `dirname $@` || true
	$(info Generating fullimg FOTA update package)
	@PATH="$(B2G_FOTA_ENV_PATH)" $(B2G_FOTA_FLASH_SCRIPT) \
            $(B2G_FOTA_COMMON_VARIABLES) \
	    --fota-type fullimg \
	    $(B2G_FOTA_FULLIMG_PARTS) \
	    --output $@
