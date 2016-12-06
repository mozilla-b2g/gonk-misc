TARGET_PROVIDES_INIT_RC := true
CONFIG_ESD := no
HTTP := android

MAJOR_VERSION := $(word 1,$(subst ., ,$(PLATFORM_VERSION)))

PRODUCT_PACKAGES += \
	b2g.sh \
	b2g-info \
	b2g-prlimit \
	b2g-ps \
	bluetoothd \
	bluetoothd-snoop \
	gonksched \
	init.bluetooth.rc \
	fakeappops \
	fs_config \
	gaia \
	gecko \
	init.rc \
	init.b2g.rc \
	killer \
	libttspico \
	rild \
	rilproxy \
	sensorsd \
	oom-msg-logger \
	$(NULL)

ifneq ($(filter-out 0 1 2 3 4,$(MAJOR_VERSION)),)
BOARD_SEPOLICY_DIRS += \
	gonk-misc/sepolicy

BOARD_SEPOLICY_UNION += \
	b2g.te \
	bluetoothd.te \
	fakeappops.te \
	gonksched.te \
	nfcd.te \
	plugin-container.te \
	rilproxy.te \
	sensorsd.te \
	file.te \
	file_contexts
endif

-include external/svox/pico/lang/all_pico_languages.mk
-include gaia/gaia.mk

ifeq ($(B2G_VALGRIND),1)
include external/valgrind/valgrind.mk
endif

ifeq ($(ENABLE_DEFAULT_BOOTANIMATION),true)
ifeq ($(BOOTANIMATION_ASSET_SIZE),)
	BOOTANIMATION_ASSET_SIZE := hvga
endif
ifeq ($(MOZILLA_OFFICIAL),1)
	BOOTANIMATION_PATH := bootanimations/official
else
	BOOTANIMATION_PATH := bootanimations/unofficial
endif
BOOTANIMATION_ASSET := $(BOOTANIMATION_PATH)/bootanimation_$(BOOTANIMATION_ASSET_SIZE).zip
PRODUCT_COPY_FILES += \
	gonk-misc/$(BOOTANIMATION_ASSET):system/media/bootanimation.zip
endif

ifeq ($(ENABLE_LIBRECOVERY),true)
PRODUCT_PACKAGES += \
  librecovery
endif

ifneq ($(DISABLE_SOURCES_XML),true)
PRODUCT_PACKAGES += \
	sources.xml
endif

ifeq ($(ENABLE_NGINX),true)
PRODUCT_PACKAGES +=           \
	nginx                 \
	nginx/nginx.conf      \
	nginx/mime.types      \
	nginx/html/index.html \
	nginx/html/50x.html

PRODUCT_PROPERTY_OVERRIDES += \
	ro.moz.httpd=1
endif # ENABLE_NGINX
