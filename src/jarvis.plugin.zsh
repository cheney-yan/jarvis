#!/usr/bin/env zsh

# Configure paths
JARVIS_HOME="${0:A:h}"
JARVIS_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/jarvis"
JARVIS_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/jarvis"
JARVIS_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/jarvis"
JARVIS_SESSION_DIR="${JARVIS_STATE_HOME}/sessions"
JARVIS_NO_CHANGE_RESULT="-NO-CHANGE-NEEDED-"

# Create necessary directories
mkdir -p "$JARVIS_DATA_HOME" "$JARVIS_CACHE_HOME" "$JARVIS_STATE_HOME" "$JARVIS_SESSION_DIR"

# Source dependencies
source "${JARVIS_HOME}/lib/utils.zsh"      # Load utilities first for spinner
source "${JARVIS_HOME}/lib/ai_handler.zsh"

# Define the @jarvis command function
function @jarvis() {
    _jarvis_debug "debug" "Received command: @jarvis $*"
    (( _jarvis_command_count++ ))
    
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
    local processed_cmd="$(cat "${cmd_dir}/ai_output")"
    # compare processed_cmd with $*
    _jarvis_debug "trace" "Comparing processed command: $processed_cmd with $JARVIS_NO_CHANGE_RESULT"
    if [[ $ai_ret -ne 0 || ( "$processed_cmd" = "$JARVIS_NO_CHANGE_RESULT" || "$processed_cmd" = "$*" ) ]]; then
       _jarvis_debug "trace" "Same command, execute $* directly"
       command="$*"
    else
        _jarvis_debug "trace" "new command suggested, provide options for user to choose from"
        command=$(_jarvis_get_user_command_choice "$processed_cmd" "$*")
        if [[ "$command" = "" ]]; then
            print -s "$processed_cmd"
            return 0
        fi
    fi
    _jarvis_exec_command "$command" "$cmd_dir"
    cmd_ret=$?
    

    # Check for AI handler failures (this occurs *before* running any shell command)
    if [[ $cmd_ret -ne 0 ]]; then
        explain=$(_jarvis_process_command_result "$cmd_ret" "$command" "$(cat ${cmd_dir}/stdout 2>/dev/null)" "$(cat ${cmd_dir}/stder 2> /dev/null)")
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
        script -q "$stdout_file" zsh -c "$cmd_to_execute"
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

# Cleanup function for session files
_jarvis_cleanup_sessions() {
    local pids=($(ls "$JARVIS_SESSION_DIR" 2>/dev/null | grep '^session_' | cut -d'_' -f2))
    for pid in $pids; do
        if ! kill -0 "$pid" 2>/dev/null; then
            _jarvis_debug "debug" "Cleaning up session for dead process: $pid"
            rm -rf "${JARVIS_SESSION_DIR}/session_${pid}"
        fi
    done
}

# Initialize Jarvis
_jarvis_init() {
    # Set up command tracking
    typeset -g _jarvis_last_command=""
    typeset -g _jarvis_last_status=0
    typeset -g _jarvis_last_output=""
    typeset -g _jarvis_last_error=""
    typeset -g _jarvis_session_dir="${JARVIS_SESSION_DIR}/$$"
    typeset -g _jarvis_command_count=0
    
    # Clean up sessions from dead processes
    _jarvis_cleanup_sessions
    
    # Create session directory for current process
    mkdir -p "$_jarvis_session_dir"
    _jarvis_debug "debug" "Session initialized: $_jarvis_session_dir"
    
    # Set up cleanup on shell exit
    trap '_jarvis_debug "debug" "Cleaning up Jarvis session"; rm -rf "$_jarvis_session_dir"' EXIT
}


# Initialize
_jarvis_init

# Debug levels:
# Export JARVIS_DEBUG=1 for basic debug info
# Export JARVIS_DEBUG=2 for detailed trace info
# Example: JARVIS_DEBUG=2 @jarvis hello
