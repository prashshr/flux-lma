#!/usr/bin/env bash

set -o errexit
set -o pipefail

# shellcheck disable=SC2155
export PROJECT_DIR=$(git rev-parse --show-toplevel)

# shellcheck disable=SC2155
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# shellcheck disable=SC1091
source "${PROJECT_DIR}/.config.env"

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help                      Display help
    --verify                        Verify .config.env settings
EOF
}

main() {
    local verify=

    parse_command_line "$@"

    verify_binaries

    if [[ "${verify}" == 1 ]]; then
        verify_age
        verify_git_repository
        success
    else
        # sops configuration file
        envsubst < "${PROJECT_DIR}/tmpl/.sops.yaml" \
            > "${PROJECT_DIR}/.sops.yaml"
        # cluster
        envsubst < "${PROJECT_DIR}/tmpl/cluster/cluster-settings.yaml" \
            > "${PROJECT_DIR}/cluster/base/cluster-settings.yaml"
        envsubst < "${PROJECT_DIR}/tmpl/cluster/gotk-sync.yaml" \
            > "${PROJECT_DIR}/cluster/base/flux-system/gotk-sync.yaml"
        envsubst < "${PROJECT_DIR}/tmpl/cluster/cluster-secrets.sops.yaml" \
            > "${PROJECT_DIR}/cluster/base/cluster-secrets.sops.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/base/cluster-secrets.sops.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/apps/monitoring/thanos/secret.sops.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/apps/tools/minio/secret.sops-op.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/apps/monitoring/botkube/secret.sops.yaml"
        sops --encrypt --in-place "${PROJECT_DIR}/cluster/apps/monitoring/uptimerobot-heartbeat/secret.sops.yaml"
    fi
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            --verify)
                verify=1
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$verify" ]]; then
        verify=0
    fi
}

_has_binary() {
    command -v "${1}" >/dev/null 2>&1 || {
        _log "ERROR" "${1} is not installed or not found in \$PATH"
        exit 1
    }
}

_has_envar() {
    local option="${1}"
    # shellcheck disable=SC2015
    [[ "${!option}" == "" ]] && {
        _log "ERROR" "Unset variable ${option}"
        exit 1
    } || {
        _log "INFO" "Found variable '${option}' with value '${!option}'"
    }
}


verify_age() {
    _has_envar "BOOTSTRAP_AGE_PUBLIC_KEY"
    _has_envar "SOPS_AGE_KEY_FILE"

    if [[ ! "$BOOTSTRAP_AGE_PUBLIC_KEY" =~ ^age.* ]]; then
        _log "ERROR" "BOOTSTRAP_AGE_PUBLIC_KEY does not start with age"
        exit 1
    else
        _log "INFO" "Age public key is in the correct format"
    fi

    if [[ ! -f ~/.config/sops/age/keys.txt ]]; then
        _log "ERROR" "Unable to find Age file keys.txt in ~/.config/sops/age"
        exit 1
    else
        _log "INFO" "Found Age public key '${BOOTSTRAP_AGE_PUBLIC_KEY}'"
    fi
}

verify_binaries() {
    _has_binary "envsubst"
    _has_binary "flux"
    _has_binary "git"
    _has_binary "age"
    _has_binary "helm"
    _has_binary "jq"
    _has_binary "sops"
    _has_binary "task"
}


verify_git_repository() {
    _has_envar "BOOTSTRAP_GIT_REPOSITORY"

    export GIT_TERMINAL_PROMPT=0
    pushd "$(mktemp -d)" >/dev/null 2>&1
    [ "$(git ls-remote "${BOOTSTRAP_GIT_REPOSITORY}" 2> /dev/null)" ] || {
        _log "ERROR" "Unable to find the remote Git repository '${BOOTSTRAP_GIT_REPOSITORY}'"
        exit 1
    }
    popd >/dev/null 2>&1
    export GIT_TERMINAL_PROMPT=1
}


success() {
    printf "\nAll checks pass!"
    exit 0
}


_log() {
    local type="${1}"
    local msg="${2}"
    printf "[%s] [%s] %s\n" "$(date -u)" "${type}" "${msg}"
}

main "$@"
