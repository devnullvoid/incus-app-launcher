#!/usr/bin/env bash

PROFILED_APPS=(
  adguard
  vaultwarden
  netbird
)

list_profiled_apps() {
  printf '%s\n' "${PROFILED_APPS[@]}"
}

has_automation_profile() {
  local app="$1"
  local item

  for item in "${PROFILED_APPS[@]}"; do
    if [[ "${item}" == "${app}" ]]; then
      return 0
    fi
  done

  return 1
}

app_interactivity() {
  local app="$1"
  case "${app}" in
    adguard) echo "non-interactive" ;;
    vaultwarden) echo "non-interactive" ;;
    netbird) echo "interactive upstream, automated in launcher" ;;
    *)
      if [[ "${INTERACTIVE_DETECTED:-no}" == "yes" ]]; then
        if has_automation_profile "${app}"; then
          echo "interactive upstream, automated in launcher"
        else
          echo "interactive upstream, no launcher automation profile"
        fi
      elif has_automation_profile "${app}"; then
        echo "profiled, no prompt pattern detected"
      else
        echo "no prompt pattern detected"
      fi
      ;;
  esac
}

app_automation_summary() {
  local app="$1"
  case "${app}" in
    adguard) echo "no prompt handling required" ;;
    vaultwarden) echo "no prompt handling required" ;;
    netbird) echo "answers: managed deployment, skip network enrollment" ;;
    *)
      if has_automation_profile "${app}"; then
        echo "custom launcher profile"
      else
        echo "none, installer stdin left empty"
      fi
      ;;
  esac
}

app_write_stdin() {
  local app="$1"
  local out="$2"

  case "${app}" in
    adguard|vaultwarden)
      : > "${out}"
      ;;
    netbird)
      cat > "${out}" <<'EOF'
1
3
EOF
      ;;
    *)
      : > "${out}"
      ;;
  esac
}

app_smoke_check_command() {
  local app="$1"
  case "${app}" in
    adguard)
      echo "systemctl is-active AdGuardHome"
      ;;
    netbird)
      echo "systemctl is-active netbird"
      ;;
    vaultwarden)
      echo "systemctl is-active vaultwarden || systemctl is-active vaultwarden.service"
      ;;
    *)
      echo "true"
      ;;
  esac
}
