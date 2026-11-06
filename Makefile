# LegacyUI — Theos-based build
export THEOS ?= /opt/theos

ARCHS = armv7
TARGET = iphoneos:8.4.1

TWEAK_NAME = LegacyUI
LegacyUI_FILES = Tweak.xm Core/CUIConfiguration.m Core/CUITheme.m Core/CUIGlassView.m

include $(THEOS)/makefiles/common.mk