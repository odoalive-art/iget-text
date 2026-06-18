.PHONY: app package install icon test clean

app:
	scripts/build-app.sh

package:
	scripts/build-app.sh --clean --archive

install:
	scripts/install-local.sh

icon:
	scripts/generate-app-icon.swift

test:
	swift test

clean:
	rm -rf dist
