# Builds 3D Weather Globe & Atlas as a Universal 2 (arm64 + x86_64) app from
# the translated sources in src/, with the original resources from game/.
#
#   make            build build/3D Weather Globe.app, the screen saver and
#                   the Spotlight importer
#   make progress   count translated and untranslated methods
#   make clean

ARCHS    := -arch arm64 -arch x86_64
MINOS    := -mmacosx-version-min=11.0
CC       := clang
CFLAGS   := $(ARCHS) $(MINOS) -fno-objc-arc -g -O1 -Wall -Wno-deprecated-declarations \
            -Wno-unused-variable -Wno-objc-method-access -Wno-incomplete-implementation \
            -Wno-mismatched-return-types -Wno-mismatched-parameter-types \
            -Wno-unused-function -Wno-comment -DGL_SILENCE_DEPRECATION \
            -Isrc/Common -Isrc/SMKGL -Isrc/SMKControls -Isrc/WeatherGlobe
LDFLAGS  := $(ARCHS) $(MINOS)

ORIG     := game/3D Weather Globe.app
APPNAME  := 3D Weather Globe
APP      := build/$(APPNAME).app
ORIG_SAVER := game/3D Weather Globe.saver
SAVER    := build/3D Weather Globe.saver
ORIG_MDI := game/3DWeatherGlobe.mdimporter
MDI      := build/3DWeatherGlobe.mdimporter
OBJ      := build/obj

COMMON_SRC := $(wildcard src/Common/*.m)
SMKGL_SRC  := $(wildcard src/SMKGL/*.m src/SMKGL/*.c)
SMKCTL_SRC := $(wildcard src/SMKControls/*.m)
WG_SRC     := $(wildcard src/WeatherGlobe/*.m)
SAVER_SRC  := $(wildcard src/GlobeScreenSaver/*.m)
MDI_SRC    := $(wildcard src/GlobeImporter/*.m src/GlobeImporter/*.c)

COMMON_OBJ := $(COMMON_SRC:src/%.m=$(OBJ)/%.o)
SMKGL_OBJ  := $(patsubst src/%.c,$(OBJ)/%.o,$(SMKGL_SRC:src/%.m=$(OBJ)/%.o))
SMKCTL_OBJ := $(SMKCTL_SRC:src/%.m=$(OBJ)/%.o)
WG_OBJ     := $(WG_SRC:src/%.m=$(OBJ)/%.o)
SAVER_OBJ  := $(SAVER_SRC:src/%.m=$(OBJ)/%.o)
MDI_OBJ    := $(patsubst src/%.c,$(OBJ)/%.o,$(MDI_SRC:src/%.m=$(OBJ)/%.o))

# make can't handle the spaces in the bundle path, so binaries are linked in
# build/bin and copied into the bundle by the app rule
SMKGL_BIN  := build/bin/SMKGL
SMKCTL_BIN := build/bin/SMKControls
WG_BIN     := build/bin/WeatherGlobe
URL_BIN    := build/bin/URLCreator.dylib
SAVER_BIN  := build/bin/GlobeScreenSaver
MDI_BIN    := build/bin/GlobeImporter

.PHONY: all clean progress resources
all: build/.app build/.saver build/.mdimporter

# Each target's sources see all of its classes, so messages sent to id
# use the real signatures.
$(SMKGL_OBJ):  TARGET_INCLUDE := -include src/SMKGL/SMKGLUmbrella.h
$(SMKCTL_OBJ): TARGET_INCLUDE := -include src/SMKControls/SMKControlsUmbrella.h
$(WG_OBJ):     TARGET_INCLUDE := -include src/WeatherGlobe/WeatherGlobeUmbrella.h
$(SAVER_OBJ):  TARGET_INCLUDE := -Isrc/GlobeScreenSaver -include src/GlobeScreenSaver/GlobeScreenSaverUmbrella.h

$(OBJ)/%.o: src/%.m
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(TARGET_INCLUDE) -MMD -c $< -o $@

$(OBJ)/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -MMD -c $< -o $@

-include $(shell find $(OBJ) -name '*.d' 2>/dev/null)

# Copies the original bundle's resources (as APFS clones, so they take no
# extra space) and drops in the new binaries.
resources: build/.resources
build/.resources: build/nibconv
	@mkdir -p build
	rm -rf "$(APP)"
	cp -cR "$(ORIG)" "$(APP)"
	rm -f "$(APP)/Contents/MacOS/$(APPNAME)" "$(APP)/Contents/_CodeSignature/CodeResources"
	rm -f "$(APP)/Contents/Frameworks/SMKGL.framework/Versions/A/SMKGL" \
	      "$(APP)/Contents/Frameworks/SMKControls.framework/Versions/A/SMKControls"
	# 64-bit AppKit can't load typedstream nibs; convert them to keyed ones
	for n in "$(APP)"/Contents/Resources/*.lproj/*.nib; do \
	    if [ -f "$$n/objects.nib" ] && [ ! -f "$$n/keyedobjects.nib" ]; then \
	        build/nibconv "$$n" "$$n" 2>&1 | grep -v -e "Weak reference" -e "__weak variable"; \
	        rm -f "$$n/objects.nib"; \
	    fi; \
	done
	/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 11.0" \
	    "$(APP)/Contents/Info.plist" 2>/dev/null || \
	  /usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 11.0" "$(APP)/Contents/Info.plist"
	# the nibs' colors were designed for the light appearance
	/usr/libexec/PlistBuddy -c "Add :NSRequiresAquaSystemAppearance bool true" \
	    "$(APP)/Contents/Info.plist" 2>/dev/null || true
	# Route files' type was declared only by the Spotlight importer, and
	# LaunchServices no longer reads type declarations from importers
	/usr/libexec/PlistBuddy \
	    -c "Add :UTExportedTypeDeclarations array" \
	    -c "Add :UTExportedTypeDeclarations:0 dict" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeIdentifier string com.mackiev.3dweatherglobe.smroute" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeDescription string 3D Weather Globe Route Set" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeIconFile string RouteIcon.icns" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo array" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo:0 string public.data" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo:1 string public.content" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification dict" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension array" \
	    -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:0 string smroute" \
	    -c "Add :CFBundleDocumentTypes:1:LSItemContentTypes array" \
	    -c "Add :CFBundleDocumentTypes:1:LSItemContentTypes:0 string com.mackiev.3dweatherglobe.smroute" \
	    "$(APP)/Contents/Info.plist"
	touch $@

$(SMKGL_BIN): $(SMKGL_OBJ) $(COMMON_OBJ)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) -dynamiclib -o "$@" $(SMKGL_OBJ) $(COMMON_OBJ) \
	    -install_name @rpath/SMKGL.framework/Versions/A/SMKGL \
	    -framework Cocoa -framework OpenGL

$(SMKCTL_BIN): $(SMKCTL_OBJ) $(COMMON_OBJ)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) -dynamiclib -o "$@" $(SMKCTL_OBJ) $(COMMON_OBJ) \
	    -install_name @rpath/SMKControls.framework/Versions/A/SMKControls \
	    -framework Cocoa

$(WG_BIN): $(WG_OBJ) $(COMMON_OBJ) $(SMKGL_BIN) $(SMKCTL_BIN)
	$(CC) $(LDFLAGS) -o "$@" $(WG_OBJ) $(COMMON_OBJ) \
	    -rpath @executable_path/../Frameworks \
	    $(SMKGL_BIN) $(SMKCTL_BIN) \
	    -framework Cocoa -framework OpenGL -framework SystemConfiguration \
	    -framework IOKit -framework ImageIO -framework Security -framework Carbon -framework AddressBook \
	    -lsqlite3 -lz

# the weather URL plugin the app loads at runtime (the original is ppc + i386)
$(URL_BIN): src/URLCreator/URLCreator.m
	@mkdir -p $(@D)
	$(CC) $(ARCHS) $(MINOS) -fno-objc-arc -O1 -Wall -dynamiclib -fvisibility=hidden \
	    -install_name @rpath/URLCreator.dylib -framework Foundation $< -o "$@"

build/.app: $(WG_BIN) $(SMKGL_BIN) $(SMKCTL_BIN) $(URL_BIN) build/.resources
	cp $(SMKGL_BIN) "$(APP)/Contents/Frameworks/SMKGL.framework/Versions/A/SMKGL"
	cp $(SMKCTL_BIN) "$(APP)/Contents/Frameworks/SMKControls.framework/Versions/A/SMKControls"
	cp $(WG_BIN) "$(APP)/Contents/MacOS/$(APPNAME)"
	cp $(URL_BIN) "$(APP)/Contents/Resources/URLCreator.dylib"
	codesign --force --deep --sign - "$(APP)"
	touch $@

# The screen saver: the original bundle's resources, with its own copy of
# SMKGL (the same framework the app uses).
$(SAVER_BIN): $(SAVER_OBJ) $(COMMON_OBJ) $(SMKGL_BIN)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) -bundle -o "$@" $(SAVER_OBJ) $(COMMON_OBJ) \
	    -rpath @loader_path/../Frameworks $(SMKGL_BIN) \
	    -framework Cocoa -framework OpenGL -framework ScreenSaver

build/.saver: $(SAVER_BIN) $(SMKGL_BIN)
	rm -rf "$(SAVER)"
	cp -cR "$(ORIG_SAVER)" "$(SAVER)"
	cp $(SAVER_BIN) "$(SAVER)/Contents/MacOS/3D Weather Globe"
	cp $(SMKGL_BIN) "$(SAVER)/Contents/Frameworks/SMKGL.framework/Versions/A/SMKGL"
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 11.0" "$(SAVER)/Contents/Info.plist"
	codesign --force --deep --sign - "$(SAVER)"
	touch $@

# The Spotlight importer for route files (.smroute).
$(OBJ)/GlobeImporter/%.o: TARGET_INCLUDE :=
$(MDI_BIN): $(MDI_OBJ)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) -bundle -o "$@" $(MDI_OBJ) \
	    -framework Foundation -framework CoreServices

build/.mdimporter: $(MDI_BIN)
	rm -rf "$(MDI)"
	cp -cR "$(ORIG_MDI)" "$(MDI)"
	cp $(MDI_BIN) "$(MDI)/Contents/MacOS/3DWeatherGlobe"
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 11.0" "$(MDI)/Contents/Info.plist"
	codesign --force --sign - "$(MDI)"
	touch $@

build/nibconv: tools/nibconv/nibconv.m
	@mkdir -p build
	$(CC) -fobjc-arc -Wno-deprecated-declarations -framework Cocoa $< -o $@

progress:
	@python3 -I tools/progress.py

clean:
	rm -rf build
