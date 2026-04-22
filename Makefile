PLIST := Sources/MarkdownEditor/Resources/Info.plist

.DEFAULT_GOAL := help
.PHONY: help version build release-patch release-minor release-major push-release _bump _guard-clean

help: ## Show available commands
	@printf "Markdown Editor $$($(MAKE) -s version)\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@printf "\n"

version: ## Print current version from Info.plist
	@/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(PLIST)

build: ## Build release app bundle locally (via build.sh)
	@bash build.sh

# ── Release targets ────────────────────────────────────────────────────────────

release-patch: _guard-clean ## Bump patch (x.x.N+1), commit, tag, and push
	@$(MAKE) -s _bump COMPONENT=patch

release-minor: _guard-clean ## Bump minor (x.N+1.0), commit, tag, and push
	@$(MAKE) -s _bump COMPONENT=minor

release-major: _guard-clean ## Bump major (N+1.0.0), commit, tag, and push
	@$(MAKE) -s _bump COMPONENT=major

push-release: _guard-clean ## Tag and push the current version without bumping
	@CURRENT="$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(PLIST))"; \
	TAG="v$$CURRENT"; \
	if git tag --list | grep -qx "$$TAG"; then \
		echo "    Tag $$TAG already exists, pushing..."; \
	else \
		git tag -a "$$TAG" -m "Release $$TAG"; \
		echo "==> Created tag $$TAG"; \
	fi; \
	git push origin main; \
	git push origin "$$TAG"; \
	echo "==> Pushed $$TAG — GitHub Actions is building the release DMG"

# ── Internal ────────────────────────────────────────────────────────────────────

_bump:
	@CURRENT="$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(PLIST))"; \
	MAJOR=$$(echo "$$CURRENT" | cut -d. -f1); \
	MINOR=$$(echo "$$CURRENT" | cut -d. -f2); \
	PATCH=$$(echo "$$CURRENT" | cut -d. -f3); \
	case "$(COMPONENT)" in \
		patch) NEW="$$MAJOR.$$MINOR.$$(( PATCH + 1 ))" ;; \
		minor) NEW="$$MAJOR.$$(( MINOR + 1 )).0" ;; \
		major) NEW="$$(( MAJOR + 1 )).0.0" ;; \
	esac; \
	echo "==> Bumping $$CURRENT → $$NEW"; \
	bash scripts/bump-version.sh "$$NEW"; \
	git push origin main; \
	git push origin "v$$NEW"; \
	echo "==> Released v$$NEW — GitHub Actions is building the release DMG"

_guard-clean:
	@if ! git diff --quiet || ! git diff --cached --quiet; then \
		echo "Error: Working tree has uncommitted changes. Commit or stash them first."; \
		exit 1; \
	fi
