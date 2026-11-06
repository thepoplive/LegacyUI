THEOS_PACKAGE_INSTALL_PREFIX = /var/mobile

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LegacyUI
LegacyUI_FILES = LUIRootListController.m
LegacyUI_INSTALL_PATH = /Library/PreferenceBundles
LegacyUI_BUNDLE_LOADER = prefs_root
LegacyUI_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/bundle.mk

all: bundle

clean::
	rm -rf obj