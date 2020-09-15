#
#  MAKEFILE
#
#    Steven Hale
#    2020 February 16
#    Birmingham, UK
#

################################################################################

ARDUINO_VERSION := 0.13.0
ARDUINO_URL := https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh

SKETCH := Blink
BOARD := uno
CORE := arduino:avr
LIBRARIES :=

PORT := /dev/ttyACM0
FQBN := $(CORE):$(BOARD)

# Treat all warnings as errors.
BUILDPROP := compiler.warning_flags.all='-Wall -Wextra -Werror'

################################################################################

ROOT := $(PWD)
BINDIR := $(ROOT)/bin
ETCDIR := $(ROOT)/etc
SRCDIR := $(ROOT)/$(SKETCH)
VARDIR := $(ROOT)/var
LOGDIR := $(VARDIR)/log
BUILDDIR := $(VARDIR)/build
CACHEDIR := $(BUILDDIR)/cache

# Build a list of source files for dependency management.
SRCS := $(shell find $(SRCDIR) -name *.ino -or -name *.cpp -or -name *.c -or -name *.h)

# Set the location of the Arduino environment.
export ARDUINO_DATA_DIR = $(VARDIR)

################################################################################

.PHONY: all help env sketch properties build upload whitespace clean

all: build

################################################################################

##
# Tell the user what the targets are.
##

help:
	@echo
	@echo "Targets:"
	@echo "   env        Install the Arduino CLI environment."
	@echo "   sketch     Initialise a new sketch."
	@echo "   properties Show all build properties used instead of compiling."
	@echo "   build      Compile the sketch."
	@echo "   upload     Upload to the board."
	@echo "   clean      Remove only files ignored by Git."
	@echo "   clean-all  Remove all untracked files."
	@echo

################################################################################

# Run in --silent mode unless the user sets VERBOSE=1 on the
# command-line.

ifndef VERBOSE
.SILENT:
endif

# curl|sh really is the documented install method.
# https://arduino.github.io/arduino-cli/latest/installation/

$(BINDIR)/arduino-cli:
	mkdir -p $(BINDIR) $(ETCDIR)
	curl -fsSL $(ARDUINO_URL) | BINDIR=$(BINDIR) sh -s $(ARDUINO_VERSION)

$(ETCDIR)/arduino-cli.yaml: $(BINDIR)/arduino-cli
	mkdir -p $(ETCDIR) $(VARDIR)
	$(BINDIR)/arduino-cli config init --verbose
	mv $(VARDIR)/arduino-cli.yaml $(ETCDIR)
	sed -i 's%\(  user:\)\(.*\)%\1 $(VARDIR)%' $(ETCDIR)/arduino-cli.yaml

env: $(BINDIR)/arduino-cli $(ETCDIR)/arduino-cli.yaml
	mkdir -p $(VARDIR) $(LOGDIR) $(BUILDDIR)
	$(BINDIR)/arduino-cli --config-file=$(ETCDIR)/arduino-cli.yaml core update-index
	$(BINDIR)/arduino-cli --config-file=$(ETCDIR)/arduino-cli.yaml core install $(CORE)
ifdef LIBRARIES
	$(BINDIR)/arduino-cli --config-file=$(ETCDIR)/arduino-cli.yaml lib update-index
	$(BINDIR)/arduino-cli --config-file=$(ETCDIR)/arduino-cli.yaml lib install $(LIBRARIES)
endif

$(SRCDIR)/$(SKETCH).ino: $(BINDIR)/arduino-cli $(ETCDIR)/arduino-cli.yaml
	$(BINDIR)/arduino-cli --config-file=$(ETCDIR)/arduino-cli.yaml sketch new $(SRCDIR)

sketch: $(SRCDIR)/$(SKETCH).ino

properties: $(BINDIR)/arduino-cli $(SRCDIR)/$(SKETCH).ino
	$(BINDIR)/arduino-cli --config-file $(ETCDIR)/arduino-cli.yaml compile \
	--build-path $(BUILDDIR) --build-cache-path $(CACHEDIR) \
	--build-properties $(BUILDPROP) \
	--warnings all --log-file $(LOGDIR)/build.log --log-level debug --verbose \
	--fqbn $(FQBN) $(SRCDIR) --show-properties

$(BUILDDIR)/$(SKETCH).ino.elf: $(BINDIR)/arduino-cli $(SRCS)
	$(BINDIR)/arduino-cli --config-file $(ETCDIR)/arduino-cli.yaml compile \
	--build-path $(BUILDDIR) --build-cache-path $(CACHEDIR) \
	--build-properties $(BUILDPROP) \
	--warnings all --log-file $(LOGDIR)/build.log --log-level debug --verbose \
	--fqbn $(FQBN) $(SRCDIR)

build: $(BUILDDIR)/$(SKETCH).ino.elf
	rm -rf $(SRCDIR)/build

upload: build
	$(BINDIR)/arduino-cli --config-file=$(ETCDIR)/arduino-cli.yaml upload \
	--log-file $(LOGDIR)/upload.log --log-level debug --verbose \
	--port $(PORT) --fqbn $(FQBN) --input-file $(BUILDDIR)/$(SKETCH).ino.hex

clean :
	git clean -dXf

clean-all :
	git clean -dxf

################################################################################
