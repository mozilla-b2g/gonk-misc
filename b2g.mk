TARGET_PROVIDES_INIT_RC := true
CONFIG_ESD := no
HTTP := android

PRODUCT_PACKAGES += \
	b2g.sh \
	b2g-info \
	b2g-ps \
	fakeperm \
	fakesched \
	gaia \
	gecko \
	init.rc \
	init.b2g.rc \
	killer \
	rild \
	rilproxy \
	sources.xml \
	$(NULL)

ifneq ($(B2G_VALGRIND),)
include external/valgrind/valgrind.mk
endif

ifeq ($(ENABLE_DEFAULT_BOOTANIMATION),true)
PRODUCT_COPY_FILES += \
	gonk-misc/bootanimation.zip:system/media/bootanimation.zip 
endif

ifeq ($(ENABLE_LIBRECOVERY),true)
PRODUCT_PACKAGES += \
  librecovery
endif
