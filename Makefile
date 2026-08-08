TESTS_DIR := .tests
PLENARY := $(TESTS_DIR)/plenary.nvim
KOTLIN_REPO := $(TESTS_DIR)/tree-sitter-kotlin
KOTLIN_PARSER := $(TESTS_DIR)/parser/kotlin.so

.PHONY: test e2e deps clean

test: deps
	nvim --headless --clean \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

# Renders sample/ for real. Needs a JDK 21+, the Android SDK and the network.
e2e: $(KOTLIN_PARSER)
	nvim --headless --clean -l tests/e2e.lua

deps: $(PLENARY) $(KOTLIN_PARSER)

$(PLENARY):
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $@

$(KOTLIN_REPO):
	git clone --depth 1 https://github.com/fwcd/tree-sitter-kotlin $@

$(KOTLIN_PARSER): $(KOTLIN_REPO)
	mkdir -p $(TESTS_DIR)/parser
	cc -o $@ -shared -Os -fPIC -I $(KOTLIN_REPO)/src \
		$(KOTLIN_REPO)/src/parser.c $(KOTLIN_REPO)/src/scanner.c

clean:
	rm -rf $(TESTS_DIR)
