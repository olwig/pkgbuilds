#!/bin/bash

set -euo pipefail

# Purpose:
# This script prepares a consistent workspace for each job, whether it runs in
# GitHub Actions, with act, or locally via bash.
#
# Behavior:
# - Validates and initializes the expected workspace layout.
# - Ensures required workflow environment variables are set.
# - Creates isolated run/job directories under work/ to avoid cross-run interference.
# - Provides a per-job repository copy at:
#     work/<run_id>/<job_id>/repo
#
# Rationale:
# When using act --bind (or local execution), the host folder may be mounted
# directly into GITHUB_WORKSPACE. To avoid accidental edits to source files,
# all workflow operations run inside WORK_ROOT and per-job WORK_DIR.
#
# Result:
# After this script completes, the process runs from GITHUB_WORKSPACE and
# WORK_DIR points to the current job's isolated working directory.


export WF_ENVIRONMENT=${WF_ENVIRONMENT:-}
export WF_DEBUG="${WF_DEBUG:-}"


wf_ensure_cmds() {
    declare -A required_commands=(
        ["git"]=""
        ["rsync"]=""
        ["tree"]=""
    )
    for cmd in "${!required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            wf_echo "Required command '$cmd' is not installed or not in PATH. Attempting to install..." "warn"
        
            # try to install missing cmd for apt or pacman
            if command -v apt &>/dev/null; then
                wf_echo "Attempting to install '$cmd' using apt..." "info"
                sudo apt update && sudo apt install -y "$cmd"
            elif command -v pacman &>/dev/null; then
                wf_echo "Attempting to install '$cmd' using pacman..." "info"
                sudo pacman -Sy --noconfirm "$cmd"
            else
                wf_echo "No supported package manager found to install '$cmd'. Please install it manually." "err"
                exit 1
            fi
        fi
    done

   
}

determine_exec_environment() {
    local exec_env=""
    if [[ -z "${GITHUB_WORKSPACE:-}" && "${ACT:-}" != "true" && ${GITHUB_ACTIONS:-} != "true" ]]; then
        exec_env="bash"
    elif [[ -d "${GITHUB_WORKSPACE:-}" && "${ACT:-}" == "true" && "$GITHUB_WORKSPACE" == $PWD && ${GITHUB_ACTIONS,-} == "true" ]]; then
        exec_env="act"
    elif [[ -d "${GITHUB_WORKSPACE:-}" && "${ACT:-}" != "true" && "$GITHUB_WORKSPACE" == $PWD && -z "$(ls -A $PWD)" && ${GITHUB_ACTIONS,-} == "true" ]]; then
        exec_env="gha"
    else
        echo "Error: Unknown execution environment. GITHUB_WORKSPACE: ${GITHUB_WORKSPACE:-}, ACT: ${ACT:-}, PWD: $PWD"
        exit 1
    fi
    WF_ENVIRONMENT="$exec_env"

    wf_echo_debug "Determined execution environment: $WF_ENVIRONMENT"

    echo "$WF_ENVIRONMENT"s
}

wf_ensure_environment() {
    if [[ -z "${WF_ENVIRONMENT:-}" ]]; then
        determine_exec_environment
    fi
}

wf_is_gha() {
    [[ "$WF_ENVIRONMENT" == "gha" ]] && {
        echo "true"
        return 0
    }
    echo "false"
    return 1
}

wf_is_act() {
    [[ "$WF_ENVIRONMENT" == "act" ]] && {
        echo "true"
        return 0
    }
    echo "false"
    return 1
}

wf_is_bash() {
    [[ "$WF_ENVIRONMENT" == "bash" ]] && {
        echo "true"
        return 0
    }
    echo "false"
    return 1
}

wf_ensure_github_envs() {
    echo "=> Ensuring github actions environment variables are set..."

    # we set only whats needed

    # defaults
    local github_repo="olwig/pkgbuilds"
    local ref="refs/heads/main"
    local ref_name="main"
    local ref_type="branch"
    local job_id="job-$(random_id 6)"
    local run_id="run-$(timestamp_id)"

    # ensure env's if not available
    export GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-$github_repo}"
    export GITHUB_REF="${GITHUB_REF:-$ref}"
    export GITHUB_REF_NAME="${GITHUB_REF_NAME:-$ref_name}"
    export GITHUB_REF_TYPE="${GITHUB_REF_TYPE:-$ref_type}"
    export GITHUB_JOB="${GITHUB_JOB:-$job_id}"
    export GITHUB_RUN_ID="${GITHUB_RUN_ID:-$run_id}"

    # ensure GITHUB_ENV set and writable
    if [[ -z "${GITHUB_ENV:-}" ]]; then
        GITHUB_ENV=$(mktemp)

        if [[ ! -w "$GITHUB_ENV" ]]; then
            echo "Error: GITHUB_ENV is not writable or not set. Please ensure it is set to a writable file path."
            exit 1
        fi

        export GITHUB_ENV
    fi

    # ensure GITHUB_OUTPUT set and writable
    if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
        GITHUB_OUTPUT=$(mktemp)

        if [[ ! -w "$GITHUB_OUTPUT" ]]; then
            echo "Error: GITHUB_OUTPUT is not writable or not set. Please ensure it is set to a writable file path."
            exit 1
        fi

        export GITHUB_OUTPUT
    fi

    # ensure GITHUB_WORKSPACE
    if [[ -z "${GITHUB_WORKSPACE:-}" ]]; then
        
        if [[ -d "$PWD/.github" ]]; then
            # local bash, or act with --bind
            echo "PWD has .github, take as GITHUB_WORKSPACE."
            GITHUB_WORKSPACE="$PWD"
        elif [[ -z $(ls -A "$PWD") ]]; then
            # act without bind or gha
            echo "PWD is empty, clone repo to PWD and take as GITHUB_WORKSPACE."
            GITHUB_WORKSPACE="$PWD"

            git clone "https://github.com/$GITHUB_REPOSITORY.git" "$GITHUB_WORKSPACE" || {
                echo "Error: Failed to clone repository $GITHUB_REPOSITORY into $GITHUB_WORKSPACE."
                exit 1
            }

            git checkout "$GITHUB_REF_NAME" || {
                echo "Error: Failed to checkout branch $GITHUB_REF_NAME in $GITHUB_WORKSPACE."
                exit 1
            }
        else
            echo "Error: Current directory ($PWD) is not empty and does not contain .github folder. Cannot determine GITHUB_WORKSPACE."
            exit 1
        fi

        echo "GITHUB_WORKSPACE set to: $GITHUB_WORKSPACE"
        cd "$GITHUB_WORKSPACE"
        export GITHUB_WORKSPACE

    elif [[ ! -d "${GITHUB_WORKSPACE:-}" ]]; then
        echo "Error: GITHUB_WORKSPACE ($GITHUB_WORKSPACE) is set but is not a directory."
        exit 1
    elif [[ $GITHUB_WORKSPACE != "$PWD" ]]; then
        echo "Error: GITHUB_WORKSPACE ($GITHUB_WORKSPACE) is set but does not match current working directory ($PWD)."
        exit 1
    fi


    echo "GitHub Actions environment variables set:"
    echo "-----------------------------------------"
    env | grep 'GITHUB_' | sort
}

wf_ensure_workflow_envs() {
    echo "=> Ensuring workflow environment variables are set..."

    # defaults
    local work_root="work"
    local work_flush="true"

    export WORK_ROOT="${WORK_ROOT:-$work_root}"
    export WORK_FLUSH="${WORK_FLUSH:-$work_flush}"
    export WORK_DIR="" # just declare, will be set later
    export WF_ALLOW_WORKTREE="${WF_ALLOW_WORKTREE:-false}"

    echo "Workflow environment variables set:"
    echo "-----------------------------------"
    env | grep 'WORK_' | sort
}


wf_ensure_work_dir() {
    echo "=> Ensuring work directory is set up..."

    # flush work if requested
    if [[ "$WORK_FLUSH" == "true" ]]; then
        rm -rf "$GITHUB_WORKSPACE/$WORK_ROOT"
        echo "Flushed work root: $GITHUB_WORKSPACE/$WORK_ROOT"
    fi


        
    # create unique work id for current run
    # TODO add env to override it with fixed value
    WORK_DIR="$WORK_ROOT/$GITHUB_RUN_ID/$GITHUB_JOB"
    mkdir -p "$GITHUB_WORKSPACE/$WORK_DIR"
    wf_export_github_env "WORK_DIR" "$WORK_DIR"
    echo "Work directory set to: $WORK_DIR"

    # copy repo to actual work dir, thus we dont mness with the host in case of act --bind and bash exec
    #rsync -av \
    #    --exclude "$WORK_ROOT/" \
    #    "$GITHUB_WORKSPACE/" "$GITHUB_WORKSPACE/$WORK_DIR/repo/"
}

wf_check() {
    local func_msg="Checking workspace integrity..."
    wf_echo "$func_msg" "arrow-down"

    # pwd must be GITHUB_WORKSPACE
    # GITHUB_WORKSPACE must have at least subfolder work. 
    # must be valid git repository

    # check GITHUB_WORKSPACE is directory
    if [[ ! -d "$GITHUB_WORKSPACE" ]]; then
        wf_echo "Error: GITHUB_WORKSPACE ($GITHUB_WORKSPACE) is not a directory." "fatal"
        exit 1
    fi

    # pwd = GITHUB_WORKSPACE
    if [[ $PWD != "$GITHUB_WORKSPACE" ]]; then
        wf_echo "Error: Current working directory ($PWD) does not match GITHUB_WORKSPACE ($GITHUB_WORKSPACE)." "fatal"
        exit 1
    fi

    # woktrees are not supported while using act since the gitdir show to locxal nbot in the container
    # not supported if WF_ENVIRONMENT is act or gha
    wf_echo_debug "WF_ALLOW_WORKTREE: $WF_ALLOW_WORKTREE"
    wf_echo_debug "WF_ENVIRONMENT: $WF_ENVIRONMENT"
    wf_echo_debug "is_act: $(wf_is_act)"
    wf_echo_debug "is_gha: $(wf_is_gha)"
    wf_echo_debug "is_bash: $(wf_is_bash)"


    if [[ "$WF_ALLOW_WORKTREE" == "true" ]] ; then
        if ! is_git_worktree "$GITHUB_WORKSPACE" && ! is_git_repo "$GITHUB_WORKSPACE"; then
            wf_echo "Error: GITHUB_WORKSPACE ($GITHUB_WORKSPACE) is not a git worktree or a git repository." "fatal"
            exit 1
        fi
    else
        if ! is_git_repo "$GITHUB_WORKSPACE"; then
            wf_echo "Error: GITHUB_WORKSPACE ($GITHUB_WORKSPACE) is not a git repository." "fatal"
            exit 1
        fi
    fi

    wf_echo "$func_msg ✅" "arrow-right"
}

wf_ensure() {
    wf_ensure_cmds
    wf_ensure_environment
    wf_ensure_github_envs
    wf_ensure_workflow_envs
    wf_ensure_work_dir
    wf_check
}

get_git_root() {
  local dir="${1:-$PWD}"
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true
}

is_git_repo() {
  local dir="${1:-$PWD}"
  [[ -d "$(get_git_root "$dir")" ]]
}

is_git_worktree() {
  local dir="${1:-$PWD}"
  [[ -f "$dir/.git" && "$(cat "$dir/.git")" == gitdir:* ]]
}

random_id() {
    local charset="a-zA-Z0-9"
    local length="${1:-12}"
    tr -dc "$charset" </dev/urandom | head -c "$length" || true
}

timestamp_id() {
    date +%Y%m%d-%H%M%S-%3N
}

wf_export_github_env() {
    local name="$1"
    local value="$2"
    echo "$name=$value" >> "$GITHUB_ENV"
    export "$name=$value"
}

wf_set_github_output() {
    local name="$1"
    local value="$2"
    echo "$name=$value" >> "$GITHUB_OUTPUT"
}

wf_echo() {
    local msg="${1:-}"
    local type="${2:-}"
    local prefix=""

    local -A emoji_map=(
        ["ok"]="✅ "
        ["err"]="❌ "
        ["fatal"]="💀 "
        ["info"]="ℹ️ "
        ["warn"]="⚠️ "
        ["debug"]="🐛 "
        ["todo"]="📝 "
        ["echo"]="💬 "
        ["arrow-right"]="➡️ "
        ["arrow-left"]="⬅️ "
        ["arrow-up"]="⬆️ "
        ["arrow-down"]="⬇️ "
    )

    if [[ -n "$type" && -n "${emoji_map[$type]+x}" ]]; then
        prefix="${emoji_map[$type]}"
    fi
    echo "${prefix}workflow: $msg"
}

wf_echo_debug() {
    if [[ -n ${WF_DEBUG:-} ]]; then
        wf_echo "$1" "debug"
    fi
}

wf_is_debug() {
    [[ -n ${WF_DEBUG:-} ]] && {
        echo "true"
        return 0
    }
    echo "false"
    return 1
}


wf_ensure