#!/usr/bin/env bash

# Configure paths
JARVIS_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
JARVIS_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/jarvis"
JARVIS_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/jarvis"
JARVIS_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/jarvis"
JARVIS_SESSION_DIR="${JARVIS_STATE_HOME}/sessions"
JARVIS_NO_CHANGE_RESULT="-NO-CHANGE-NEEDED-"

# Create necessary directories
mkdir -p "$JARVIS_DATA_HOME" "$JARVIS_CACHE_HOME" "$JARVIS_STATE_HOME" "$JARVIS_SESSION_DIR"

# --- Utility Functions (from utils.sh) ---

# Debug logging utility
_jarvis_debug() {
    local level="$1"
    local msg="$2"
    local color_reset="\033[0m"
    local color_debug="\033[36m"  # Cyan for debug
    local color_trace="\033[35m"  # Magenta for trace
    local color_info="\033[32m"   # Green for info
    case "$level" in
        "info")
            echo -e "${color_info} [🤖 ℹ️]${color_reset} $msg" >&2
            ;;
        "debug")
            [[ "$JARVIS_DEBUG" -eq 1 ]] && echo -e "${color_debug} [🤖 🐛]${color_reset} $msg" >&2
            ;;
        "trace")
            [[ "$JARVIS_DEBUG" -ge 2 ]] && echo -e "${color_trace} [🤖 🧵]${color_reset} $msg" >&2
            ;;
    esac
}

# --- AI Handler Functions (from ai_handler.sh) ---

# Process custom AI queries
_jarvis_process_custom_query() {
    local query="$1"
    _jarvis_debug "debug" "Processing query using llm: $query"

    # Configurable model and prompt with defaults
    local model_name=${JARVIS_LLM_MODEL:-grok-3-mini-fast-latest}
    local no_change_response=${JARVIS_NO_CHANGE_RESULT:-'-NO-CHANGE-NEEDED-'}
    local system_prompt=${JARVIS_LLM_SYSTEM_PROMPT:-'You are a shell command processor. Given a user query, output ONLY the refined shell command that should be run. Output nothing else. The output should be a plain text command, single line, returns stripped, no quotes. It can be multiple commands concatenated with () and &&. If the command looks like a normal command, then simply reply '$no_change_response''}
    _jarvis_debug "trace" "Using model: $model_name, no change response: $no_change_response, system prompt: $system_prompt"
    # Call llm grok directly to process the query
    local result
    result=$(llm -m "$model_name" -s "$system_prompt" "$query" 2>&1)
    local llm_status=$?

    _jarvis_debug "debug" "LLM response: $result"

    # Check for timeout or failure
    if [[ $llm_status -ne 0 ]]; then
        echo "🤖 Failed: $result, status $llm_status" >&2
        return $llm_status
    fi

    echo "$result"
    return 0
}

_jarvis_process_command_result() {
    local status_code="$1"
    local command="$2"
    local output="$3"
    local error="$4"

    _jarvis_debug "trace" "Command result: status=$status_code, output=$output, error=$error"
    local model_name=${JARVIS_LLM_MODEL:-grok-3-mini-fast-latest}
    local system_prompt="You are a shell command result analyzer. You gives clear and short suggestions on failed commands. Given command, '$command', the command status_code is '$status_code', output '$output' and error '$error'. Please provide suggestions of what happened, how can I refine my command to fix the issue."
    _jarvis_debug "trace" "Using model: $model_name, system prompt: $system_prompt"
    # Call llm grok directly to process the query
    local result
    result=$(llm -m "$model_name" -s "$system_prompt" "$command" 2>&1)
    local llm_status=$?

    _jarvis_debug "debug" "LLM response: $result"

    if [[ $llm_status -ne 0 ]]; then
        echo "🤖 Failed: $result, status $llm_status" >&2
        return $llm_status
    fi

    echo "$result"
    return 0
}

# Presents a menu to the user to choose between refined command, original input, or cancel
# Returns the chosen command's exit status, or 0 if cancelled
_jarvis_get_user_command_choice() {
    local refined_cmd="$1"
    local original_cmd="$2"

    # Set up direct terminal output
    exec 3>/dev/tty

    # Present options to the user
    echo "" >&3
    echo "\033[1m👋 I have some suggestion to your request:\033[0m" >&3
    echo "\033[1;32ma|👍 Accept)\033[0m Run: \033[0;32m${refined_cmd}\033[0m" >&3
    echo "\033[1;33md|🖐️ Deny)  \033[0m Run: \033[0;34m${original_cmd}\033[0m" >&3
    echo "\033[1;31ms|📑 Save)  \033[0m Save command to history, so you can edit and run later." >&3

    local choice=""
    while true; do
        echo -n "\033[1mEnter your choice (a/s/d):\033[0m " >&3
        command stty echo  # Ensure echo is on
        read -r choice </dev/tty  # Read directly from terminal
        [[ -z "${choice// /}" ]] && continue
        case "$choice" in
            a)
                exec 3>&-  # Close terminal fd
                echo "$refined_cmd"
                return 0
                ;;
            d)
                exec 3>&-  # Close terminal fd
                echo "$original_cmd"
                return 0
                ;;
            s)
                exec 3>&-  # Close terminal fd
                return 0
                ;;
            *)
                echo -ne "\r\033[K" >&3  # Clear the line
                echo "\033[31mPlease enter a, s, or d\033[0m" >&3
                ;;
        esac
    done
    return 0
}

# Initialize global variables
_jarvis_last_command=""
_jarvis_last_status=0
_jarvis_last_output=""
_jarvis_last_error=""
_jarvis_session_dir="${JARVIS_SESSION_DIR}/$$"
_jarvis_command_count=0

# Cleanup function for session files
_jarvis_cleanup_sessions() {
    local pids
    pids=($(ls "$JARVIS_SESSION_DIR" 2>/dev/null | grep '^session_' | cut -d'_' -f2))
    for pid in "${pids[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            _jarvis_debug "debug" "Cleaning up session for dead process: $pid"
            rm -rf "${JARVIS_SESSION_DIR}/session_${pid}"
        fi
    done
}

# Initialize Jarvis
_jarvis_init() {
    # Set up command tracking
    _jarvis_last_command=""
    _jarvis_last_status=0
    _jarvis_last_output=""
    _jarvis_last_error=""
    _jarvis_session_dir="${JARVIS_SESSION_DIR}/$$"
    _jarvis_command_count=0
    
    # Clean up sessions from dead processes
    _jarvis_cleanup_sessions
    
    # Create session directory for current process
    mkdir -p "$_jarvis_session_dir"
    _jarvis_debug "debug" "Session initialized: $_jarvis_session_dir"
    
    # Set up cleanup on shell exit
    trap '_jarvis_debug "debug" "Cleaning up Jarvis session"; rm -rf "$_jarvis_session_dir"' EXIT
}

# Define the @jarvis command function
@jarvis() {
    _jarvis_debug "debug" "Received command: @jarvis $*"
    _jarvis_command_count=$((_jarvis_command_count + 1))
    
    # Create command-specific directory
    local cmd_dir="${_jarvis_session_dir}/${_jarvis_command_count}"
    _jarvis_debug "trace" "Creating session directory: $cmd_dir"
    mkdir -p "$cmd_dir"
    
    # Save input command
    echo "@jarvis $*" > "${cmd_dir}/input"
    _jarvis_debug "trace" "Saved input command: @jarvis $* to ${cmd_dir}/input"
    
    # Process through AI handler
    _jarvis_process_custom_query "$*" > "${cmd_dir}/ai_output"
    local ai_ret=$?
    _jarvis_debug "debug" "AI handler returned: $ai_ret"

    # Get the processed command and any errors
    local processed_cmd
    processed_cmd="$(cat "${cmd_dir}/ai_output")"
    # compare processed_cmd with $*
    _jarvis_debug "trace" "Comparing processed command: $processed_cmd with $JARVIS_NO_CHANGE_RESULT"
    local command=""
    if [[ $ai_ret -ne 0 || "$processed_cmd" == "$JARVIS_NO_CHANGE_RESULT" || "$processed_cmd" == "$*" ]]; then
       _jarvis_debug "trace" "Same command, execute $* directly"
       command="$*"
    else
        _jarvis_debug "trace" "new command suggested, provide options for user to choose from"
        command=$(_jarvis_get_user_command_choice "$processed_cmd" "$*")
        if [[ -z "$command" ]]; then
            if [ -n "$BASH_VERSION" ]; then history -s "$processed_cmd"; elif [ -n "$ZSH_VERSION" ]; then print -s "$processed_cmd"; fi
            return 0
        fi
    fi
    _jarvis_exec_command "$command" "$cmd_dir"
    local cmd_ret=$?
    
    # Check for AI handler failures (this occurs *before* running any shell command)
    if [[ $cmd_ret -ne 0 ]]; then
        local explain
        explain=$(_jarvis_process_command_result "$cmd_ret" "$command" "$(cat ${cmd_dir}/stdout 2>/dev/null)" "$(cat ${cmd_dir}/stderr 2>/dev/null)")
        [[ $? -eq 0 ]] && _jarvis_debug "info" "$explain"
    fi
    
    _jarvis_cleanup_sessions
    return $cmd_ret
}

_jarvis_exec_command() {
    local cmd_to_execute="$1"
    local cmd_dir="$2"
    _jarvis_debug "debug" "Executing command: $cmd_to_execute"
    
    # Save the command that will actually be executed
    echo "$cmd_to_execute" > "${cmd_dir}/executed_command"
    
    # Create temp file for capturing output
    local stdout_file="${cmd_dir}/stdout"
    
    # Use script to capture both interactive and non-interactive command output
    echo "===================CMD EXEC STARTED==================" >&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: BSD script (no -c option, must use a shell for complex commands)
        script -q "$stdout_file" bash -c "$cmd_to_execute"
    else
        # Linux: GNU script
        script -q -c "$cmd_to_execute" "$stdout_file"
    fi
    local cmd_ret=$?
    echo "===================CMD EXEC ENDED: $cmd_ret==================" >&2
    
    # Display captured output to user
    # cat "$stdout_file"
    return $cmd_ret
}

# Initialize
_jarvis_init

# Debug levels:
# Export JARVIS_DEBUG=1 for basic debug info
# Export JARVIS_DEBUG=2 for detailed trace info
# Example: JARVIS_DEBUG=2 @jarvis hello
