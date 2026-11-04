# The CloudXR viewer with foveated streaming as a literate program.
#   make check    tangle the web and verify it reproduces the project's sources exactly
#   make pdf      weave the web and typeset cloudxrviewer.pdf (needs tectonic; a copy is committed)
#   make tangle   write the tangled sources to build/tangled/ without touching the project
#   make clean

PYTHON  ?= python3
TECTONIC ?= tectonic
WEB     := $(sort $(wildcard chapters/*.nw))
ROOT    := ..
REQUIRE := --require 'CloudXRViewer/**/*.swift' \
           --require 'Config.xcconfig' \
           --require 'CloudXRViewer/visionOS/CloudXRViewer-visionOS.entitlements' \
           --require 'CloudXRViewer/visionOS/CloudXRViewer-visionOS-Info.plist' \
           --require 'CloudXRViewer/iOS/CloudXRViewer-iOS-Info.plist'
# (CloudXRViewer.xcodeproj/project.pbxproj is left out: it is maintained by Xcode, not by hand.)

.PHONY: all pdf check tangle clean

all: check pdf

check:
	$(PYTHON) lit.py check --root $(ROOT) $(REQUIRE) $(WEB)

tangle:
	$(PYTHON) lit.py tangle -o build/tangled $(WEB)

build/body.tex build/chunkindex.tex: $(WEB) lit.py
	$(PYTHON) lit.py weave -o build $(WEB)

pdf: cloudxrviewer.pdf

cloudxrviewer.pdf: build/cloudxrviewer.pdf
	cp build/cloudxrviewer.pdf cloudxrviewer.pdf

build/cloudxrviewer.pdf: cloudxrviewer.tex build/body.tex build/chunkindex.tex
	$(TECTONIC) --keep-logs --outdir build cloudxrviewer.tex

clean:
	rm -rf build
