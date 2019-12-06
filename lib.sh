error() {
  local errmsg="$1"

  echo -e "[ERROR] $errmsg"
  exit 1
}

check_root() {
  if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
  fi
}

check_command() {
  local command="$1"

  hash "${command}" 2>/dev/null || error "This application needs '${command}' but it's not installed!"
}
