PYTHON := python3
PKGS ?= zlib

.PHONY: help check-host directories verify fetch-all bootstrap-dietlibc cast world plan plan-world compile-all compare-libc libc-selection localrepo localrepo-base localrepo-desktop release release-base release-desktop release-iso full-report test clean

help:
	@echo "LEANUX build system"
	@echo ""
	@echo "Available targets:"
	@echo "  check-host         Check development environment"
	@echo "  directories        Create build directories"
	@echo "  verify             Verify downloaded sources"
	@echo "  fetch-all          Fetch sources for world order + required extras"
	@echo "  bootstrap-dietlibc Build dietlibc into tools/diet"
	@echo "  cast PKGS='...'    Build spells with dietlibc (default: zlib)"
	@echo "  world              Build every package in build/world.order"
	@echo "  plan PKGS='...'    Print the resolved build plan (dry run)"
	@echo "  plan-world         Print the full world build plan"
	@echo "  compile-all        Fetch + try to build every selected spell (matrix)"
	@echo "  compare-libc       Build glibc variants and compare artifact sizes"
	@echo "  libc-selection     Choose dietlibc/glibc per package from the comparison"
	@echo "  localrepo          Generate repository/localrepo from all real spells"
	@echo "  localrepo-base     localrepo for the base profile"
	@echo "  localrepo-desktop  localrepo for the desktop profile"
	@echo "  release            Assemble an image from already built stages"
	@echo "  release-base       Build missing base packages, then create image/ISO"
	@echo "  release-desktop    Build missing desktop packages, then create image/ISO"
	@echo "  full-report        Write LEANUX-ERGEBNISSE.md from the current reports"
	@echo "  test               Run the build-system test suite"
	@echo "  clean              Remove generated build files"

check-host:
	$(PYTHON) tools/check_host.py

directories:
	mkdir -p sources build-output sysroot

verify:
	$(PYTHON) tools/verify_sources.py

fetch-all:
	$(PYTHON) tools/fetch_sources.py --selection world-extras

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

compile-all:
	./tests/compile-all.sh --compare

compare-libc:
	./tests/compare-libc.sh

libc-selection:
	$(PYTHON) tools/select_libc.py

LOCALREPO_PKGS ?= --all

localrepo:
	$(PYTHON) tools/make_localrepo.py $(LOCALREPO_PKGS) --report reports/localrepo.md

localrepo-base:
	$(PYTHON) tools/make_localrepo.py --profile base --report reports/localrepo-base.md

localrepo-desktop:
	$(PYTHON) tools/make_localrepo.py --profile desktop --report reports/localrepo-desktop.md

release:
	./tests/build-release.sh

release-base:
	./tests/build-release.sh --profile base --image both

release-desktop:
	./tests/build-release.sh --profile desktop --image both

release-iso:
	./tests/build-release.sh --image both

full-report:
	$(PYTHON) tools/full_report.py

test:
	./tests/run-tests.sh

clean:
	rm -rf build-output sysroot
