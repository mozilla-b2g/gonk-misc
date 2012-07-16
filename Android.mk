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

$(LOCAL_INSTALLED_MODULE):
	@echo Install dir: $(TARGET_OUT)/b2g
	rm -rf $(TARGET_OUT)/b2g
	cd $(TARGET_OUT) && tar xvfz $(abspath $<)

# Target to create Gecko update package (MAR)
UPDATE_PACKAGE_TARGET := $(GECKO_OBJDIR)/dist/b2g/b2g-gecko-update.mar
MAR := $(GECKO_OBJDIR)/dist/host/bin/mar
MAKE_FULL_UPDATE := $(GECKO_PATH)/tools/update-packaging/make_full_update.sh
.PHONY: gecko-update-full
gecko-update-full:
	MAR=$(MAR) $(MAKE_FULL_UPDATE) $(UPDATE_PACKAGE_TARGET) $(GECKO_OBJDIR)/dist/b2g
	sha512sum $(UPDATE_PACKAGE_TARGET)

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
	echo $(MAKE) -C $(GECKO_PATH) -f client.mk -s && \
	$(MAKE) -C $(GECKO_PATH) -f client.mk -s && \
	rm -f $(GECKO_OBJDIR)/dist/b2g-*.tar.gz && \
	$(MAKE) -C $(GECKO_OBJDIR) package && \
	mkdir -p $(@D) && cp $(GECKO_OBJDIR)/dist/b2g-*.tar.gz $@
