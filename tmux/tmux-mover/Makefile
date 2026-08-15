.PHONY: help build run test fmt vet install watch-trim-log watch-start watch-stop watch-restart

WATCH_PIDFILE := $(HOME)/.cache/tmux-mover/watch.pid
WATCH_LOG := $(HOME)/.cache/tmux-mover/watch.log
WATCH_LOG_MAX_BYTES := 5242880

help:
	@printf "%s\n" "make build" "make run" "make test" "make fmt" "make vet" "make install" "make watch-start" "make watch-stop" "make watch-restart"

build:
	nix develop -c go build -o tmux-mover .

run:
	nix develop -c go run .

test:
	nix develop -c go test ./...

fmt:
	nix develop -c gofmt -w *.go

vet:
	nix develop -c go vet ./...

install: build
	mkdir -p "$$HOME/bin"
	mv ./tmux-mover "$$HOME/bin/tmux-mover"

# watch-stop is safe to call whether or not a watcher is running, and safe to
# call from anywhere (it only touches the fixed pidfile path, not $(PWD)) —
# it's meant to be reused by watch-restart and by other scripts that just
# want to make sure a stale watcher is gone.
watch-stop:
	@if [ -f "$(WATCH_PIDFILE)" ]; then \
		kill "$$(cat "$(WATCH_PIDFILE)")" 2>/dev/null || true; \
		rm -f "$(WATCH_PIDFILE)"; \
	fi

watch-trim-log:
	@mkdir -p "$$(dirname "$(WATCH_LOG)")"
	@if [ -f "$(WATCH_LOG)" ] && [ "$$(wc -c <"$(WATCH_LOG)")" -gt "$(WATCH_LOG_MAX_BYTES)" ]; then \
		tmp="$(WATCH_LOG).tmp"; \
		tail -c "$(WATCH_LOG_MAX_BYTES)" "$(WATCH_LOG)" >"$$tmp" && mv "$$tmp" "$(WATCH_LOG)"; \
	fi

watch-start: watch-trim-log
	@nohup "$$HOME/bin/tmux-mover" --watch-agents >>"$(WATCH_LOG)" 2>&1 &

# Rebuilds/reinstalls first so this always restarts whatever is newest on
# disk — safe to call repeatedly from wherever you happen to be after
# editing the tool.
watch-restart: install watch-stop watch-start
	@echo "tmux-mover --watch-agents restarted (log: $(WATCH_LOG))"
