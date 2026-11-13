# Adapters Makefile
# Build/verify experiment adapters

ADAPTERS := $(shell ls -d */ 2>/dev/null | sed 's:/::' | grep -v template)

.PHONY: all build test clean $(ADAPTERS)

all: build

build: $(ADAPTERS)

$(ADAPTERS):
	@echo "Building adapter: $@"
	@if [ -f "$@/Makefile" ]; then \
		$(MAKE) -C $@ build; \
	elif [ -f "$@/build.sh" ]; then \
		cd $@ && ./build.sh; \
	elif [ -f "$@/pyproject.toml" ] || [ -f "$@/requirements.txt" ]; then \
		echo "Python adapter - dependencies should be installed via pip"; \
	elif [ -f "$@/Cargo.toml" ]; then \
		cd $@ && cargo build --release; \
	elif [ -f "$@/go.mod" ]; then \
		cd $@ && go build ./...; \
	else \
		echo "No build system detected for $@"; \
	fi

test:
	@for adapter in $(ADAPTERS); do \
		echo "Testing adapter: $$adapter"; \
		if [ -f "$$adapter/Makefile" ]; then \
			$(MAKE) -C $$adapter test; \
		elif [ -f "$$adapter/test.sh" ]; then \
			cd $$adapter && ./test.sh; \
		elif [ -f "$$adapter/experiment.py" ]; then \
			python3 $$adapter/experiment.py --help; \
		fi; \
	done

clean:
	@for adapter in $(ADAPTERS); do \
		if [ -f "$$adapter/Makefile" ]; then \
			$(MAKE) -C $$adapter clean; \
		elif [ -f "$$adapter/Cargo.toml" ]; then \
			cd $$adapter && cargo clean; \
		fi; \
	done

# Install Python dependencies for all adapters
install-python-deps:
	@for adapter in $(ADAPTERS); do \
		if [ -f "$$adapter/requirements.txt" ]; then \
			echo "Installing deps for $$adapter"; \
			pip3 install -r $$adapter/requirements.txt; \
		elif [ -f "$$adapter/pyproject.toml" ]; then \
			echo "Installing $$adapter"; \
			pip3 install -e $$adapter; \
		fi; \
	done