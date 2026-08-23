ifneq ($(strip $(TOPDIR)),)

include Makefile

else

.PHONY: check test

SHELL_SOURCES := \
	bin/led-nightmode \
	root/etc/init.d/led-nightmode \
	root/usr/libexec/led-nightmode-provider-service \
	root/usr/libexec/led-nightmode-service \
	providers/quectel-qnwcfg-ledmode/root/usr/libexec/led-nightmode/providers/quectel-qnwcfg-ledmode \
	root/usr/sbin/led-nightmode \
	tests/test-cli.sh \
	tests/test-init.sh \
	tests/test-modem-provider.sh \
	tests/test-service.sh

check:
	@for source in $(SHELL_SOURCES); do sh -n "$$source" || exit; done

test: check
	./tests/test-cli.sh
	./tests/test-init.sh
	./tests/test-modem-provider.sh
	./tests/test-service.sh

endif
