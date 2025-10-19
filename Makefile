.PHONY: deploy update clean archive export install fix-signature

# Main target - build and deploy the app
deploy: archive export install
	@echo "✅ BabyKeyboardLock deployed successfully to /Applications/"

# Alias for deploy - update the installed app
update: deploy

# Clean build artifacts
clean:
	@./scripts/clean.sh

# Build archive
archive: clean
	@./scripts/archive.sh

# Export archive
export:
	@./scripts/export.sh

# Install to Applications folder
install:
	@./scripts/install.sh

# Fix signature issues (resets accessibility permissions!)
fix-signature:
	@./scripts/fix-signature.sh
