ifeq ($(ROOTLESS),1)
THEOS_PACKAGE_SCHEME=rootless
endif

ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube
TARGET = iphone:clang:latest:13.0
PACKAGE_VERSION = 0.2.3

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KaiLiteCore

KaiLiteCore_FILES   = Tweak.x Settings.x SignIn.x Utils/NSBundle+KL.m Utils/KLUserDefaults.m
KaiLiteCore_CFLAGS  = -fobjc-arc -Wno-deprecated-declarations
KaiLiteCore_FRAMEWORKS = UIKit Foundation SystemConfiguration

include $(THEOS_MAKE_PATH)/tweak.mk
