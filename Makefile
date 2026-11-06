# LegacyUI — Theos-based build
export THEOS ?= $(HOME)/theos

ARCHS = armv7
TARGET = iphoneos:8.4.1

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

TWEAK_NAME = LegacyUI
LegacyUI_FILES = Tweak.xm Core/CUIConfiguration.m Core/CUITheme.m Core/CUIGlassView.m

include $(THEOS)/makefiles/common.mk