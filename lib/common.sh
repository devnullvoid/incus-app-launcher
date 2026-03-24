#!/usr/bin/env bash

UPSTREAM_REPO="${UPSTREAM_REPO:-community-scripts/ProxmoxVE}"
UPSTREAM_RAW_BASE="${UPSTREAM_RAW_BASE:-https://raw.githubusercontent.com/${UPSTREAM_REPO}}"

META_CPU=""
META_RAM=""
META_DISK=""
META_OS=""
META_VERSION=""
META_APP_DISPLAY=""
META_UNPRIVILEGED=""
META_TUN="no"
META_NESTING="no"
META_FUSE="no"
META_GPU="no"
INTERACTIVE_DETECTED="no"
INTERACTIVE_MATCHES=""

log() {
  printf '[incus-app] %s\n' "$*" >&2
}

die() {
  printf '[incus-app] error: %s\n' "$*" >&2
  exit 1
}

require_bin() {
  command -v "$1" >/dev/null 2>&1 || die "Required binary not found: $1"
}

fetch_raw_file() {
  local ref="$1"
  local path="$2"
  local out="$3"
  local url

  if [[ "${UPSTREAM_RAW_BASE}" == file://* ]]; then
    url="${UPSTREAM_RAW_BASE}/${path}"
  else
    url="${UPSTREAM_RAW_BASE}/${ref}/${path}"
  fi

  curl -fsSL "${url}" -o "${out}"
}

fetch_upstream_bundle() {
  local app="$1"
  local ref="$2"
  local workdir="$3"

  fetch_raw_file "${ref}" "ct/${app}.sh" "${workdir}/ct.sh"
  fetch_raw_file "${ref}" "install/${app}-install.sh" "${workdir}/install.sh"
  fetch_raw_file "${ref}" "misc/install.func" "${workdir}/install.func"
}

fetch_upstream_addon() {
  local addon="$1"
  local ref="$2"
  local workdir="$3"

  fetch_raw_file "${ref}" "tools/addon/${addon}.sh" "${workdir}/addon.sh"
}

extract_var_default() {
  local key="$1"
  local file="$2"

  sed -n "s/^${key}=.*\\\${[^:]*:-\\([^}]*\\)}.*/\\1/p" "${file}" | head -n 1
}

parse_ct_metadata() {
  local ct_file="$1"

  META_CPU="$(extract_var_default "var_cpu" "${ct_file}")"
  META_RAM="$(extract_var_default "var_ram" "${ct_file}")"
  META_DISK="$(extract_var_default "var_disk" "${ct_file}")"
  META_OS="$(extract_var_default "var_os" "${ct_file}")"
  META_VERSION="$(extract_var_default "var_version" "${ct_file}")"
  META_APP_DISPLAY="$(awk -F'"' '/^APP="/ {print $2; exit}' "${ct_file}")"
  META_UNPRIVILEGED="$(extract_var_default "var_unprivileged" "${ct_file}")"
  META_TUN="$(extract_var_default "var_tun" "${ct_file}")"
  META_NESTING="$(extract_var_default "var_nesting" "${ct_file}")"
  META_FUSE="$(extract_var_default "var_fuse" "${ct_file}")"
  META_GPU="$(extract_var_default "var_gpu" "${ct_file}")"

  [[ -n "${META_CPU}" ]] || META_CPU="1"
  [[ -n "${META_RAM}" ]] || META_RAM="512"
  [[ -n "${META_DISK}" ]] || META_DISK="8"
  [[ -n "${META_OS}" ]] || die "Could not determine var_os from ${ct_file}"
  [[ -n "${META_VERSION}" ]] || die "Could not determine var_version from ${ct_file}"
  [[ -n "${META_APP_DISPLAY}" ]] || META_APP_DISPLAY="${META_OS}"
  [[ -n "${META_UNPRIVILEGED}" ]] || META_UNPRIVILEGED="1"
  [[ -n "${META_TUN}" ]] || META_TUN="no"
  [[ -n "${META_NESTING}" ]] || META_NESTING="1"
  [[ -n "${META_FUSE}" ]] || META_FUSE="no"
  [[ -n "${META_GPU}" ]] || META_GPU="no"
}

detect_install_interactivity() {
  local install_file="$1"
  local pattern

  pattern='read[[:space:]]+-|whiptail|dialog|inputbox|radiolist|checklist|menu|select[[:space:]]'
  INTERACTIVE_MATCHES="$(
    rg -n "${pattern}" "${install_file}" -S 2>/dev/null | head -n 8 || true
  )"

  if [[ -n "${INTERACTIVE_MATCHES}" ]]; then
    INTERACTIVE_DETECTED="yes"
  else
    INTERACTIVE_DETECTED="no"
  fi
}

resolve_image() {
  local os="$1"
  local version="$2"

  case "${os}" in
    debian|ubuntu|alpine)
      printf 'images:%s/%s' "${os}" "${version}"
      ;;
    *)
      die "Unsupported upstream OS for MVP: ${os}"
      ;;
  esac
}

shell_quote_file_contents() {
  local path="$1"
  local content
  content="$(<"${path}")"
  printf '%q' "${content}"
}

render_runtime_files() {
  local app="$1"
  local name="$2"
  local workdir="$3"

  local functions_q
  functions_q="$(shell_quote_file_contents "${workdir}/install.func")"

  cat > "${workdir}/runtime.env" <<EOF
export FUNCTIONS_FILE_PATH=${functions_q}
export APPLICATION=$(printf '%q' "${META_APP_DISPLAY}")
export app=$(printf '%q' "${app}")
export PASSWORD=""
export VERBOSE="no"
export SSH_ROOT="no"
export SSH_AUTHORIZED_KEY=""
export CTID=$(printf '%q' "${name}")
export CTTYPE=$(printf '%q' "${META_UNPRIVILEGED}")
export ENABLE_FUSE=$(printf '%q' "${META_FUSE}")
export ENABLE_TUN=$(printf '%q' "${META_TUN}")
export PCT_OSTYPE=$(printf '%q' "${META_OS}")
export PCT_OSVERSION=$(printf '%q' "${META_VERSION}")
export PCT_DISK_SIZE=$(printf '%q' "${META_DISK}")
export IPV6_METHOD="auto"
export ENABLE_GPU=$(printf '%q' "${META_GPU}")
export DIAGNOSTICS="no"
export RANDOM_UUID=""
export EXECUTION_ID=""
export SESSION_ID="incus-app-launcher"
export CACHER="no"
export CACHER_IP=""
export tz="Etc/UTC"
EOF

  app_write_stdin "${app}" "${workdir}/installer.stdin"
}

run_or_print() {
  local dry_run="$1"
  shift
  if [[ "${dry_run}" == "true" ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

run_captured_command() {
  local __out_var="$1"
  local __err_var="$2"
  shift 2

  local stdout_file
  local stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  local rc=0
  set +e
  "$@" >"${stdout_file}" 2>"${stderr_file}"
  rc=$?
  set -e

  printf -v "${__out_var}" '%s' "$(<"${stdout_file}")"
  printf -v "${__err_var}" '%s' "$(<"${stderr_file}")"
  rm -f "${stdout_file}" "${stderr_file}"
  return "${rc}"
}

incus_prepare_instance() {
  local name="$1"
  local image="$2"
  local dry_run="$3"

  run_or_print "${dry_run}" incus init "${image}" "${name}"
}

incus_apply_limits() {
  local name="$1"
  local dry_run="$2"

  run_or_print "${dry_run}" incus config set "${name}" limits.cpu "${META_CPU}"
  run_or_print "${dry_run}" incus config set "${name}" limits.memory "${META_RAM}MiB"
  run_or_print "${dry_run}" incus config device override "${name}" root size="${META_DISK}GiB"
}

incus_apply_features() {
  local name="$1"
  local dry_run="$2"

  if [[ "${META_TUN}" == "yes" ]]; then
    run_or_print "${dry_run}" incus config device add "${name}" tun unix-char source=/dev/net/tun path=/dev/net/tun
  fi

  if [[ "${META_NESTING}" == "1" || "${META_NESTING}" == "yes" ]]; then
    run_or_print "${dry_run}" incus config set "${name}" security.nesting true
  fi

  if [[ "${META_FUSE}" == "1" || "${META_FUSE}" == "yes" ]]; then
    run_or_print "${dry_run}" incus config set "${name}" security.syscalls.intercept.mount true
    run_or_print "${dry_run}" incus config set "${name}" security.syscalls.intercept.mount.allowed fuse
  fi

  if [[ "${META_UNPRIVILEGED}" == "0" ]]; then
    log "Upstream requested privileged mode. MVP keeps Incus defaults unless you adjust the profile manually."
  fi

  if [[ "${META_GPU}" == "yes" ]]; then
    log "GPU passthrough is not automated in the MVP."
  fi
}

incus_start_instance() {
  local name="$1"
  local dry_run="$2"

  run_or_print "${dry_run}" incus start "${name}"
}

incus_push_runtime() {
  local name="$1"
  local workdir="$2"
  local dry_run="$3"

  run_or_print "${dry_run}" incus file push "${workdir}/install.sh" "${name}/root/install.sh"
  run_or_print "${dry_run}" incus file push "${workdir}/runtime.env" "${name}/root/runtime.env"
  run_or_print "${dry_run}" incus file push "${workdir}/installer.stdin" "${name}/root/installer.stdin"
}

incus_bootstrap_guest() {
  local name="$1"
  local dry_run="$2"

  case "${META_OS}" in
    alpine)
      run_or_print "${dry_run}" incus exec "${name}" -- ash -lc "apk update && apk add bash newt curl openssh nano mc ncurses jq"
      ;;
    debian|ubuntu)
      run_or_print "${dry_run}" incus exec "${name}" -- bash -lc "apt-get update && apt-get install -y sudo curl mc gnupg2 jq"
      ;;
    *)
      log "No guest bootstrap package set defined for ${META_OS}"
      ;;
  esac
}

incus_bootstrap_existing_guest() {
  local name="$1"
  local dry_run="$2"

  run_or_print "${dry_run}" incus exec "${name}" -- sh -lc '
if command -v apk >/dev/null 2>&1; then
  apk update && apk add --no-cache bash curl
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update && apt-get install -y bash curl
else
  echo "Unsupported guest package manager" >&2
  exit 1
fi
'
}

incus_run_installer() {
  local name="$1"
  local dry_run="$2"
  local prompt_mode="$3"

  case "${prompt_mode}" in
    interactive)
      run_or_print "${dry_run}" incus exec "${name}" -- bash -lc "set -euo pipefail; source /root/runtime.env; bash /root/install.sh"
      ;;
    profile|empty)
      run_or_print "${dry_run}" incus exec "${name}" -- bash -lc "set -euo pipefail; source /root/runtime.env; bash /root/install.sh < /root/installer.stdin"
      ;;
    *)
      die "Unknown prompt mode: ${prompt_mode}"
      ;;
  esac
}

incus_push_addon_script() {
  local name="$1"
  local workdir="$2"
  local dry_run="$3"

  run_or_print "${dry_run}" incus file push "${workdir}/addon.sh" "${name}/root/addon.sh"
}

incus_run_addon_script() {
  local name="$1"
  local dry_run="$2"
  local prompt_mode="$3"
  local addon_action="$4"

  local exec_cmd="set -euo pipefail; export type=${addon_action}; bash /root/addon.sh"
  if [[ "${addon_action}" == "install" ]]; then
    exec_cmd="set -euo pipefail; unset type; bash /root/addon.sh"
  fi

  case "${prompt_mode}" in
    interactive)
      run_or_print "${dry_run}" incus exec "${name}" -- bash -lc "${exec_cmd}"
      ;;
    empty|profile)
      run_or_print "${dry_run}" incus exec "${name}" -- bash -lc "${exec_cmd} < /dev/null"
      ;;
    *)
      die "Unknown prompt mode: ${prompt_mode}"
      ;;
  esac
}

incus_instance_exists() {
  local name="$1"
  incus info "${name}" >/dev/null 2>&1
}

incus_delete_instance() {
  local name="$1"
  incus delete "${name}" --force >/dev/null 2>&1 || true
}

incus_smoke_check() {
  local name="$1"
  local check_cmd="$2"
  local dry_run="$3"

  run_or_print "${dry_run}" incus list "${name}" --format table
  if [[ "${dry_run}" == "true" ]]; then
    run_or_print "${dry_run}" incus exec "${name}" -- bash -lc "${check_cmd}"
    run_or_print "${dry_run}" incus exec "${name}" -- hostname -I
    return
  fi

  local attempt
  local max_attempts=10
  local delay_seconds=3
  local stdout=""
  local stderr=""
  local rc=0

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if run_captured_command stdout stderr incus exec "${name}" -- bash -lc "${check_cmd}"; then
      break
    fi
    rc=$?

    if (( attempt == max_attempts )); then
      log "Smoke check failed after ${max_attempts} attempts: ${check_cmd}"
      log "Smoke check exit code: ${rc}"
      [[ -n "${stdout}" ]] && printf '%s\n' "${stdout}" >&2
      [[ -n "${stderr}" ]] && printf '%s\n' "${stderr}" >&2
      return 1
    fi

    log "Smoke check attempt ${attempt}/${max_attempts} failed with exit code ${rc}: ${check_cmd}"
    [[ -n "${stdout}" ]] && printf '%s\n' "${stdout}" >&2
    [[ -n "${stderr}" ]] && printf '%s\n' "${stderr}" >&2
    sleep "${delay_seconds}"
  done

  incus exec "${name}" -- bash -lc "${check_cmd}"
  incus exec "${name}" -- hostname -I
}
