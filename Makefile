# LegacyUI - Theos-based build
export THEOS ?= $(THEOS)

ARCHS = armv7
TARGET = iphoneos:8.4.1

PACKAGE_VERSION = 0.1.0

TWEAK_NAME = LegacyUI
LegacyUI_FILES = Tweak.xm Core/CUIConfiguration.m Core/CUITheme.m Core/CUIGlassView.m Dock/CUIDockController.m Dock/CUIDockView.m VolumeHUD/CUIVolumeController.m VolumeHUD/CUIVolumePillView.m Preferences/LUIRootListController.m

include $(THEOS)/makefiles/common.mk