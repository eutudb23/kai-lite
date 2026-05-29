ifeq ($(ROOTLESS),1)
THEOS_PACKAGE_SCHEME=rootless
endif

ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube
TARGET = iphone:clang:latest:13.0
PACKAGE_VERSION = 0.1.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KaiLiteCore

KaiLiteCore_FILES   = Tweak.x Settings.x Utils/NSBundle+KL.m Utils/KLUserDefaults.m
KaiLiteCore_CFLAGS  = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
