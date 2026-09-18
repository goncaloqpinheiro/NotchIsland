APP_NAME  := NotchIsland
BUNDLE_ID := com.goncalopinheiro.NotchIsland
APP       := build/$(APP_NAME).app
CONFIG    ?= debug

.PHONY: build app run stop logs cpu test snapshots docs-images docs-demo glass-preview focus-check clean

# Compile only.
build:
	swift build -c $(CONFIG)

# Compile and assemble build/NotchIsland.app.
app:
	CONFIG=$(CONFIG) ./Scripts/bundle.sh

# Rebuild, quit the running copy, relaunch in the background (-g: no focus steal).
run: app stop
	open -g $(APP)

stop:
	@pkill -x $(APP_NAME) || true
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done

# Live app logs (os_log).
logs:
	/usr/bin/log stream --style compact --level debug --predicate 'subsystem == "$(BUNDLE_ID)"'

# CPU / memory of the running app.
cpu:
	@ps -o pid,%cpu,rss,command -p $$(pgrep -x $(APP_NAME))

# Build the checks in Tests/ together with the app's code (all but its main.swift)
# and run them. No Xcode needed. `make test ARGS=--verbose` lists every check.
test:
	@mkdir -p .build/tests
	@find Sources/$(APP_NAME) -name '*.swift' ! -path 'Sources/$(APP_NAME)/main.swift' -print0 \
		| xargs -0 swiftc -swift-version 5 -Onone -module-cache-path .build/tests/cache -o .build/tests/$(APP_NAME)Tests Tests/*.swift
	@.build/tests/$(APP_NAME)Tests $(ARGS)

# Render the island and Settings to PNGs in build/snapshots (no screen recording needed).
snapshots: app
	$(APP)/Contents/MacOS/$(APP_NAME) --snapshots build/snapshots

# Render the README's pictures into docs/images.
docs-images: app
	$(APP)/Contents/MacOS/$(APP_NAME) --docs-images docs/images

# Render the animated demo: docs/images/demo.gif for the README, and a 1080p movie
# with captions in build/demo for sharing. Every frame is drawn by the app itself.
docs-demo: app
	$(APP)/Contents/MacOS/$(APP_NAME) --docs-demo docs/images/demo.gif build/demo/NotchIsland-demo.mp4

# Show Natural and Adaptive glass side by side for 20 seconds. The window server
# draws the glass, so it can't be snapshotted; this is how to see it.
glass-preview: app
	$(APP)/Contents/MacOS/$(APP_NAME) --glass-preview

# Log the shape of the Focus files and what NotchIsland reads from them. Opened
# with `open` so it runs with the app's own Full Disk Access.
focus-check: app
	open -g -n $(APP) --args --focus-check
	@sleep 3
	@/usr/bin/log show --last 10s --style compact --predicate 'subsystem == "$(BUNDLE_ID)" AND eventMessage CONTAINS "Focus check"'

clean:
	rm -rf .build build
