ifneq ($(strip $(TOPDIR)),)

include Makefile

else

.PHONY: check check-ash test release-check stage-upstream stage-upstream-luci stage-upstream-packages

SHELL_SOURCES := \
	bin/led-nightmode \
	core/root/etc/init.d/led-nightmode \
	core/root/etc/uci-defaults/99-led-nightmode \
	core/root/usr/libexec/led-nightmode-provider-service \
	core/root/usr/libexec/led-nightmode-service \
	providers/quectel-qnwcfg-ledmode/root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode \
	core/root/usr/sbin/led-nightmode \
	scripts/stage-upstream-packages.sh \
	scripts/stage-upstream-luci.sh \
	upstream/packages/test-version.sh \
	tests/test-cli.sh \
	tests/test-init.sh \
	tests/test-apk-split-upgrade.sh \
	tests/test-luci-assets.sh \
	tests/test-modem-provider.sh \
	tests/test-release.sh \
	tests/test-service.sh \
	tests/test-upstream.sh \
	tests/test-upstream-packages.sh \
	tests/test-uci-defaults.sh

check:
	@for source in $(SHELL_SOURCES); do sh -n "$$source" || exit; done

check-ash:
	@command -v busybox >/dev/null || { echo 'busybox is required for check-ash' >&2; exit 1; }
	@for source in $(SHELL_SOURCES); do busybox ash -n "$$source" || exit; done

test: check
	./tests/test-cli.sh
	./tests/test-init.sh
	./tests/test-luci-assets.sh
	./tests/test-modem-provider.sh
	./tests/test-service.sh
	./tests/test-upstream.sh
	./tests/test-upstream-packages.sh
	./tests/test-uci-defaults.sh

release-check: test
	./tests/test-release.sh

stage-upstream: stage-upstream-luci

stage-upstream-luci:
	@test -n "$(DEST)" || { echo 'Usage: make stage-upstream-luci DEST=/path/to/luci/applications/luci-app-led-nightmode' >&2; exit 2; }
	./scripts/stage-upstream-luci.sh "$(DEST)"

stage-upstream-packages:
	@test -n "$(DEST)" && test -n "$(PKG_HASH)" || { echo 'Usage: make stage-upstream-packages DEST=/path/to/packages/utils/led-nightmode PKG_HASH=<sha256>' >&2; exit 2; }
	./scripts/stage-upstream-packages.sh "$(DEST)" "$(PKG_HASH)"

endif
