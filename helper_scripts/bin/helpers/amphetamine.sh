#!/usr/bin/env bash

set -u

STATE_DIR="${TMPDIR:-/tmp}/local-amphetamine"
PID_FILE="$STATE_DIR/caffeinate.pid"
END_FILE="$STATE_DIR/end_epoch"
FLAGS_FILE="$STATE_DIR/flags"
DEFAULT_FLAGS_FILE="$STATE_DIR/default_flags"
DEFAULT_FLAGS="-d -i -m"

mkdir -p "$STATE_DIR"

usage() {
	cat <<'EOF'
Usage:
  amphetamine.sh [command] [options]

Commands:
  i                 Print 0 if active, 1 if inactive
  status            Print active/remaining/flags for fast polling
  remaining         Print remaining seconds for timed session
  flags             Print flags for active session or current default
  profile "..."     Set profile flags (applies now + next sessions)
  default-flags     Print current default flags
  1|start|on        Start indefinite no-sleep session
  0|stop|off        Stop current session
  toggle|t          Toggle session on/off
  <duration>        Start timed session (default unit is minutes)
  -h|--help|help    Show this help

Options:
  --flags "..."     Use given caffeinate flags for this start/toggle

Duration format:
  Ns  N seconds
  Nm  N minutes
  Nh  N hours
  Nd  N days
  N   N minutes

Examples:
  amphetamine.sh start
  amphetamine.sh start --flags "-i -m"
  amphetamine.sh stop
  amphetamine.sh toggle
  amphetamine.sh toggle --flags "-d"
  amphetamine.sh profile "-i -m"
  amphetamine.sh default-flags
  amphetamine.sh status
  amphetamine.sh 30m
  amphetamine.sh 2h --flags "-i"
  amphetamine.sh 2h
  amphetamine.sh 90
  amphetamine.sh flags
  amphetamine.sh remaining
EOF
}

get_default_flags() {
	if [[ -f "$DEFAULT_FLAGS_FILE" ]]; then
		local stored
		stored="$(<"$DEFAULT_FLAGS_FILE")"
		if [[ -n "$stored" ]]; then
			echo "$stored"
			return 0
		fi
	fi

	echo "$DEFAULT_FLAGS"
}

set_default_flags() {
	local flags_string="$1"
	echo "$flags_string" >"$DEFAULT_FLAGS_FILE"
}

validate_flags() {
	local flags_string="$1"
	if [[ -z "$flags_string" ]]; then
		return 1
	fi

	if [[ "$flags_string" =~ [^[:space:][:alnum:]-] ]]; then
		return 1
	fi

	if [[ "$flags_string" != *-* ]]; then
		return 1
	fi

	return 0
}

parse_common_options() {
	PARSED_FLAGS=""
	PARSED_DURATION=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--flags)
			if [[ $# -lt 2 ]]; then
				return 1
			fi
			PARSED_FLAGS="$2"
			shift 2
			;;
		*)
			if [[ -n "$PARSED_DURATION" ]]; then
				return 1
			fi
			PARSED_DURATION="$1"
			shift
			;;
		esac
	done

	return 0
}

is_active() {
	if [[ ! -f "$PID_FILE" ]]; then
		return 1
	fi

	local pid
	pid="$(<"$PID_FILE")"
	if [[ -z "$pid" ]] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
		rm -f "$PID_FILE"
		return 1
	fi

	if ! kill -0 "$pid" 2>/dev/null; then
		rm -f "$PID_FILE"
		return 1
	fi

	local command
	command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
	if [[ "$command" != *"caffeinate"* ]]; then
		rm -f "$PID_FILE"
		return 1
	fi

	return 0
}

stop_session() {
	if is_active; then
		local pid
		pid="$(<"$PID_FILE")"
		kill "$pid" 2>/dev/null || true
	fi
	rm -f "$PID_FILE"
	rm -f "$END_FILE"
	rm -f "$FLAGS_FILE"
}

remaining_seconds() {
	if ! is_active; then
		echo ""
		return 0
	fi

	if [[ ! -f "$END_FILE" ]]; then
		echo ""
		return 0
	fi

	local end_epoch
	end_epoch="$(<"$END_FILE")"
	if [[ -z "$end_epoch" ]] || ! [[ "$end_epoch" =~ ^[0-9]+$ ]]; then
		rm -f "$END_FILE"
		echo ""
		return 0
	fi

	local now
	now="$(date +%s)"
	local remaining=$((end_epoch - now))
	if ((remaining < 0)); then
		remaining=0
	fi

	echo "$remaining"
}

duration_to_seconds() {
	local value="$1"

	if [[ "$value" =~ ^([0-9]+)([smhd]?)$ ]]; then
		local count="${BASH_REMATCH[1]}"
		local unit="${BASH_REMATCH[2]}"
		case "$unit" in
		s) echo "$count" ;;
		m | "") echo $((count * 60)) ;;
		h) echo $((count * 60 * 60)) ;;
		d) echo $((count * 60 * 60 * 24)) ;;
		*) return 1 ;;
		esac
		return 0
	fi

	return 1
}

start_session() {
	local duration_seconds="${1:-}"
	local flags_string="${2:-}"
	if [[ -z "$flags_string" ]]; then
		flags_string="$(get_default_flags)"
	fi

	if ! validate_flags "$flags_string"; then
		exit 1
	fi

	stop_session

	local flags=()
	read -r -a flags <<<"$flags_string"
	echo "$flags_string" >"$FLAGS_FILE"

	if [[ -n "$duration_seconds" ]]; then
		local now
		now="$(date +%s)"
		echo $((now + duration_seconds)) >"$END_FILE"
		nohup caffeinate "${flags[@]}" -t "$duration_seconds" >/dev/null 2>&1 &
	else
		rm -f "$END_FILE"
		nohup caffeinate "${flags[@]}" >/dev/null 2>&1 &
	fi

	local pid=$!
	echo "$pid" >"$PID_FILE"
}

apply_profile() {
	local flags_string="$1"

	if ! validate_flags "$flags_string"; then
		exit 1
	fi

	set_default_flags "$flags_string"

	if is_active; then
		local remaining
		remaining="$(remaining_seconds)"
		if [[ -n "$remaining" ]] && [[ "$remaining" =~ ^[0-9]+$ ]] && ((remaining > 0)); then
			start_session "$remaining" "$flags_string"
		else
			start_session "" "$flags_string"
		fi
	fi
}

command="${1:-0}"

if [[ $# -gt 0 ]]; then
	shift
fi

case "$command" in
help | -h | --help)
	usage
	;;
i)
	if is_active; then
		echo 0
	else
		echo 1
	fi
	;;
remaining)
	remaining_seconds
	;;
status)
	if is_active; then
		echo "active=1"
		echo "remaining=$(remaining_seconds)"
		if [[ -f "$FLAGS_FILE" ]]; then
			echo "flags=$(<"$FLAGS_FILE")"
		else
			echo "flags=$(get_default_flags)"
		fi
	else
		echo "active=0"
		echo "remaining="
		echo "flags=$(get_default_flags)"
	fi
	;;
flags)
	if is_active && [[ -f "$FLAGS_FILE" ]]; then
		cat "$FLAGS_FILE"
	else
		get_default_flags
	fi
	;;
default-flags)
	get_default_flags
	;;
profile)
	if [[ $# -lt 1 ]]; then
		exit 1
	fi
	apply_profile "$1"
	;;
1 | start | on)
	if ! parse_common_options "$@"; then
		exit 1
	fi

	duration_seconds=""
	if [[ -n "$PARSED_DURATION" ]]; then
		duration_seconds="$(duration_to_seconds "$PARSED_DURATION" 2>/dev/null || true)"
		if [[ -z "$duration_seconds" ]]; then
			exit 1
		fi
	fi

	start_session "$duration_seconds" "$PARSED_FLAGS"
	;;
0 | stop | off)
	stop_session
	;;
toggle | t)
	if ! parse_common_options "$@"; then
		exit 1
	fi

	duration_seconds=""
	if [[ -n "$PARSED_DURATION" ]]; then
		duration_seconds="$(duration_to_seconds "$PARSED_DURATION" 2>/dev/null || true)"
		if [[ -z "$duration_seconds" ]]; then
			exit 1
		fi
	fi

	if is_active; then
		stop_session
	else
		start_session "$duration_seconds" "$PARSED_FLAGS"
	fi
	;;
*)
	if ! parse_common_options "$@"; then
		exit 1
	fi

	duration_value="$command"
	if [[ -n "$PARSED_DURATION" ]]; then
		exit 1
	fi

	duration_seconds="$(duration_to_seconds "$duration_value" 2>/dev/null || true)"
	if [[ -z "$duration_seconds" ]]; then
		exit 1
	fi

	start_session "$duration_seconds" "$PARSED_FLAGS"
	;;
esac
