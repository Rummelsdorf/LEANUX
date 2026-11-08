PYTHON := python3
PKGS ?= zlib

.PHONY: help check-host directories verify bootstrap-dietlibc cast test clean

help:
	@echo "LEANUX build system"
	@echo ""
	@echo "Available targets:"
	@echo "  check-host         Check development environment"
	@echo "  directories        Create build directories"
	@echo "  verify             Verify downloaded sources"
	@echo "  bootstrap-dietlibc Build dietlibc into tools/diet"
	@echo "  cast PKGS='...'    Build spells with dietlibc (default: zlib)"
	@echo "  test               Run the build-system test suite"
	@echo "  clean              Remove generated build files"

check-host:
	$(PYTHON) tools/check_host.py

directories:
	mkdir -p sources build-output sysroot

verify:
	$(PYTHON) tools/verify_sources.py

bootstrap-dietlibc:
	./bootstrap/dietlibc.sh

cast:
	./spells/cast.sh $(PKGS)

test:
	./tests/run-tests.sh

clean:
	rm -rf build-output sysroot
