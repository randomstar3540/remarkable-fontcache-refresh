#!/usr/bin/env bash
set -euo pipefail

RM_HOST=""
RM_USER="root"
RM_PASSWORD=""
SSH_KEY=""
USE_PASSWORD=0
USE_SSH_KEY=0

DEFAULT_SSH_OPTS="-o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_OPTS="${SSH_OPTS:-${DEFAULT_SSH_OPTS}}"

SERVICE_NAME="fontcache-refresh.service"
SERVICE_DIR="/home/root/fontcache-units"

usage() {
  cat <<EOF
Usage: $(basename "$0") --host <ip> (--password | --ssh-key <path>) <install|uninstall>
Options:
  --host <ip>            Target reMarkable IP address
  -p, --password         Prompt for password-based authentication
  -k, --ssh-key [path]   Use SSH key (optionally specify key file with path)
  -h, --help             Show this help text
Examples:
  $(basename "$0") --host 10.11.99.1 --password install
  $(basename "$0") --host 10.11.99.1 --ssh-key install
  $(basename "$0") --host 10.11.99.1 --ssh-key ~/.ssh/id_rsa uninstall
EOF
}

COMMAND=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) RM_HOST="$2"; shift 2;;
    -p|--password) USE_PASSWORD=1; shift;;
    -k|--ssh-key)
      USE_SSH_KEY=1
      if [[ $# -gt 1 ]]; then
        next_arg="$2"
        case "${next_arg}" in
          --*|install|uninstall)
            SSH_KEY=""
            shift
            ;;
          *)
            SSH_KEY="${next_arg}"
            shift 2
            ;;
        esac
      else
        SSH_KEY=""
        shift
      fi
      ;;
    install|uninstall) COMMAND="$1"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" && usage && exit 1;;
  esac
done

if [[ -z "${RM_HOST}" || -z "${COMMAND}" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

if [[ "${USE_PASSWORD}" -eq 1 && "${USE_SSH_KEY}" -eq 1 ]]; then
  echo "Specify either --password or --ssh-key, not both." >&2
  exit 1
fi

if [[ "${USE_PASSWORD}" -eq 0 && "${USE_SSH_KEY}" -eq 0 ]]; then
  echo "Authentication method missing: use --password to prompt or --ssh-key." >&2
  exit 1
fi

if [[ "${USE_PASSWORD}" -eq 1 ]]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "sshpass is required for password authentication but was not found in PATH." >&2
    exit 1
  fi
  read -rsp "Enter password for ${RM_USER}@${RM_HOST}: " RM_PASSWORD
  echo
  if [[ -z "${RM_PASSWORD}" ]]; then
    echo "Password cannot be empty." >&2
    exit 1
  fi
else
  if [[ -n "${SSH_KEY}" ]]; then
    expanded_key="${SSH_KEY}"
    if [[ "${expanded_key}" == ~* ]]; then
      expanded_key="${expanded_key/#\~/$HOME}"
    fi
    if [[ ! -f "${expanded_key}" ]]; then
      echo "SSH key '${expanded_key}' not found." >&2
      exit 1
    fi
    SSH_KEY="${expanded_key}"
    SSH_OPTS="${SSH_OPTS} -i ${SSH_KEY}"
  fi
fi

if [[ "${USE_PASSWORD}" -eq 1 ]]; then
  ssh_rm() { sshpass -p "${RM_PASSWORD}" ssh ${SSH_OPTS} "${RM_USER}@${RM_HOST}" "$@"; }
else
  ssh_rm() { ssh ${SSH_OPTS} "${RM_USER}@${RM_HOST}" "$@"; }
fi

echo ">> Testing connection to reMarkable: ${RM_USER}@${RM_HOST}"
ssh_rm 'echo "connected"' >/dev/null

case "${COMMAND}" in
  install)
    # Check if service already exists
    if ssh_rm "test -f /etc/systemd/system/${SERVICE_NAME}"; then
      echo "Service ${SERVICE_NAME} already installed. Aborting." >&2
      exit 1
    fi

    echo ">> Preparing service directory on the device"
    ssh_rm "mkdir -p ${SERVICE_DIR}"

    echo ">> Writing service file to ${SERVICE_DIR}/${SERVICE_NAME}"
    ssh_rm "cat >${SERVICE_DIR}/${SERVICE_NAME} <<'EOF'
[Unit]
Description=Rebuild fontconfig cache after home is mounted and restart xochitl
After=home.mount
Requires=home.mount

[Service]
Type=oneshot
ExecStart=/bin/sh -lc 'fc-cache -fsv && systemctl restart xochitl'

[Install]
WantedBy=multi-user.target
EOF"

    echo ">> Installing service into /etc/systemd/system"
    ssh_rm "cp ${SERVICE_DIR}/${SERVICE_NAME} /etc/systemd/system/${SERVICE_NAME}"
    ssh_rm "systemctl daemon-reload"
    ssh_rm "systemctl enable ${SERVICE_NAME}"

    echo ">> Starting the service immediately"
    ssh_rm "systemctl start ${SERVICE_NAME}"
    ;;

  uninstall)
    # Check if service exists
    if ! ssh_rm "test -f /etc/systemd/system/${SERVICE_NAME}";
    then
      echo "Service ${SERVICE_NAME} is not installed. Aborting." >&2
      exit 1
    fi

    echo ">> Disabling service if enabled"
    ssh_rm "systemctl disable ${SERVICE_NAME} || true"

    echo ">> Removing service files"
    ssh_rm "rm -f /etc/systemd/system/${SERVICE_NAME}"
    ssh_rm "rm -f ${SERVICE_DIR}/${SERVICE_NAME}"

    echo ">> Reloading systemd daemon"
    ssh_rm "systemctl daemon-reload"
    ;;
esac
