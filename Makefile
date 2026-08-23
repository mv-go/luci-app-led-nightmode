.PHONY: check test

check:
	sh -n bin/led-nightmode
	sh -n tests/test-cli.sh

test: check
	./tests/test-cli.sh
