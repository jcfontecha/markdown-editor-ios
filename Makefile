PACKAGE_SCHEME := MarkdownEditor
PACKAGE_WORKSPACE := .swiftpm/xcode/package.xcworkspace
DEMO_SCHEME := MarkdownEditorDemo
DEMO_PROJECT := Demo/MarkdownEditor.xcodeproj

.PHONY: build markdown-editor demo-app open --verbose

build:
	./scripts/build.sh $(filter markdown-editor demo-app --verbose,$(MAKECMDGOALS))

markdown-editor:
	@:

demo-app:
	@:

open:
	open $(DEMO_PROJECT)

--verbose:
	@:
