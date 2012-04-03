LOCAL_PATH:= $(call my-dir)

ifneq ($(TARGET_PROVIDES_B2G_INIT_RC),true)
include $(CLEAR_VARS)
LOCAL_MODULE       := init.rc
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES    := init.rc
LOCAL_MODULE_PATH  := $(TARGET_ROOT_OUT)
include $(BUILD_PREBUILT)
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


include $(CLEAR_VARS)
LOCAL_MODULE       := mountvol.sh
LOCAL_MODULE_TAGS  := optional eng
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES    := mountvol.sh
LOCAL_MODULE_PATH  := $(TARGET_OUT_EXECUTABLES)
include $(BUILD_PREBUILT)
