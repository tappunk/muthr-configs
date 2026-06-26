_vm_exists() {
    local vm_name="$1"
    limactl ls -q | grep -q "^${vm_name}$"
}

_vm_is_running() {
    local vm_name="$1"
    local _vm_status
    _vm_status="$(limactl ls -f '{{.Status}}' "$vm_name" 2>/dev/null)" || true
    [[ "$_vm_status" == "Running" ]]
}

_lib_validate_vm_name() {
	VM_NAME="$1"

	if [[ -z "${VM_NAME:-}" ]]; then
		echo "Usage: $0 <vm-name>"
		exit 1
	fi

	if ! _vm_exists "$VM_NAME"; then
		echo "Error: VM '$VM_NAME' does not exist."
		exit 1
	fi

	if ! _vm_is_running "$VM_NAME"; then
		echo "Error: VM '$VM_NAME' is not running."
		exit 1
	fi
}

vm_exec() {
	local vm_name
	if [[ -n "${VM_NAME:-}" ]]; then
		vm_name="$VM_NAME"
	else
		vm_name="$1"
		shift 2>/dev/null || true
	fi
	limactl shell --workdir /tmp "$vm_name" -- "$@"
}

_lib_setup_trap() {
	_lib_cleanup_handler() {
		local exit_code=$?
		if [[ $exit_code -ne 0 ]]; then
			echo "[ERR] unexpected script termination. dropping tracking tokens." >&2
			if [[ -n "${LOCK_FILE:-}" ]]; then
				rm -f "$LOCK_FILE"
			fi
		fi
		exit "$exit_code"
	}
	trap _lib_cleanup_handler EXIT
}

_lib_init_provision_state() {
	local profile="$1"
	shift

	LOCK_FILE="$HOME/.muthr_provision.lock"
	local IFS='|'
	ENV_FINGERPRINT="${profile}|${*}"

	_lib_setup_trap

	if [[ -f "$LOCK_FILE" ]] && [[ "$(cat "$LOCK_FILE" 2>/dev/null || true)" == "$ENV_FINGERPRINT" ]]; then
		echo "[INFO] environment match detected for '${profile}'. skipping provision run."
		exit 0
	fi

	echo "[PROC] initiating installation tracking context for '${profile}'..."
}

_lib_finalize_provision_state() {
	if [[ -z "${LOCK_FILE:-}" ]] || [[ -z "${ENV_FINGERPRINT:-}" ]]; then
		echo "[ERR] provision tracing primitives missing initialization." >&2
		exit 1
	fi

	printf '%s\n' "$ENV_FINGERPRINT" > "$LOCK_FILE"
	chmod 0600 "$LOCK_FILE"
}
