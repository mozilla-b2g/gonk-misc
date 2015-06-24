TARGET_PROVIDES_INIT_RC := true
CONFIG_ESD := no
HTTP := android

PRODUCT_PACKAGES += \
	b2g.sh \
	b2g-info \
	b2g-prlimit \
	b2g-ps \
	bluetoothd \
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
	oom-msg-logger \
	$(NULL)

-include external/svox/pico/lang/all_pico_languages.mk
-include gaia/gaia.mk

ifeq ($(B2G_VALGRIND),1)
include external/valgrind/valgrind.mk
endif

ifeq ($(ENABLE_DEFAULT_BOOTANIMATION),true)
ifeq ($(BOOTANIMATION_ASSET_SIZE),)
	BOOTANIMATION_ASSET_SIZE := hvga
endif
BOOTANIMATION_ASSET := bootanimation_$(BOOTANIMATION_ASSET_SIZE).zip
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

ifneq ($(POWERTEST),)
include external/i2c-tools/i2c-tools.mk
endif
