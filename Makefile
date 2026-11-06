# LegacyUI — build orchestration (NO Theos; plain clang + ldid + dpkg-deb).
# Real logic lives in scripts/build.sh. macOS runner required for iOS armv7.

APP_NAME := LegacyUI

.PHONY: all build package validate clean

all: package validate

build:
	@./scripts/build.sh build

package:
	@./scripts/build.sh package

validate:
	@./scripts/build.sh validate

clean:
	@rm -rf build stage