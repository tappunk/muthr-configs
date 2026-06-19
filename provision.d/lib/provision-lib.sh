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
