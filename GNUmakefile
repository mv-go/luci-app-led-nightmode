ifneq ($(strip $(TOPDIR)),)

include Makefile

else

.PHONY: check test

SHELL_SOURCES := \
	bin/led-nightmode \
	root/etc/init.d/led-nightmode \
	root/usr/libexec/led-nightmode-service \
	root/usr/sbin/led-nightmode \
	tests/test-cli.sh \
	tests/test-init.sh \
	tests/test-service.sh

check:
	@for source in $(SHELL_SOURCES); do sh -n "$$source" || exit; done

test: check
	./tests/test-cli.sh
	./tests/test-init.sh
	./tests/test-service.sh

endif
