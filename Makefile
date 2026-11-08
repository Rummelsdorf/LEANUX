PYTHON := python3
PKGS ?= zlib

.PHONY: help check-host directories verify bootstrap-dietlibc cast world plan plan-world test clean

help:
	@echo "LEANUX build system"
	@echo ""
	@echo "Available targets:"
	@echo "  check-host         Check development environment"
	@echo "  directories        Create build directories"
	@echo "  verify             Verify downloaded sources"
	@echo "  bootstrap-dietlibc Build dietlibc into tools/diet"
	@echo "  cast PKGS='...'    Build spells with dietlibc (default: zlib)"
	@echo "  world              Build every package in build/world.order"
	@echo "  plan PKGS='...'    Print the resolved build plan (dry run)"
	@echo "  plan-world         Print the full world build plan"
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

world:
	./spells/cast.sh --world

plan:
	./spells/cast.sh --dry-run $(PKGS)

plan-world:
	./spells/cast.sh --dry-run --world

test:
	./tests/run-tests.sh

clean:
	rm -rf build-output sysroot
