#!/usr/bin/env zsh

# Configure paths
JARVIS_HOME="${0:A:h}"
JARVIS_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/jarvis"
JARVIS_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/jarvis"
JARVIS_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/jarvis"
JARVIS_SESSION_DIR="${JARVIS_STATE_HOME}/sessions"

# Create necessary directories
mkdir -p "$JARVIS_DATA_HOME" "$JARVIS_CACHE_HOME" "$JARVIS_STATE_HOME" "$JARVIS_SESSION_DIR"

# Source dependencies
source "${JARVIS_HOME}/lib/utils.zsh"      # Load utilities first for spinner
source "${JARVIS_HOME}/lib/preprocess.zsh"
source "${JARVIS_HOME}/lib/postprocess.zsh"
source "${JARVIS_HOME}/lib/ai_handler.zsh"

# Define the @jarvis command function
function @jarvis() {
    _jarvis_debug "debug" "Received command: @jarvis $*"
    (( _jarvis_command_count++ ))
    
    # Create command-specific directory
    local cmd_dir="${_jarvis_session_dir}/${_jarvis_command_count}"
    mkdir -p "$cmd_dir"
    
    # Save input command
    echo "@jarvis $*" > "${cmd_dir}/input"
    
    # Process through AI handler
    _jarvis_handle_ai_command "@jarvis $*" > "${cmd_dir}/ai_output" 2> "${cmd_dir}/ai_error"
    local ai_ret=$?
    
    # Get the processed command and any errors
    local processed_cmd="$(cat "${cmd_dir}/ai_output")"
    _jarvis_last_error="$(cat "${cmd_dir}/ai_error")"
    
    _jarvis_debug "trace" "AI handler returned: $ai_ret"
    
    # Check for AI handler failures
    if [[ $ai_ret -ne 0 ]]; then
        echo "[JARVIS: AI handler failed]" >&2
        [[ -n "$_jarvis_last_error" ]] && echo "$_jarvis_last_error" >&2
        return $ai_ret
    fi
    
    # If the user chose to cancel or no command was selected
    if [[ -z "$processed_cmd" ]]; then
        echo "[JARVIS: Operation cancelled]" >&2
        return 1
    fi
    
    # Extract just the command from the output
    if ! echo "$processed_cmd" | python3 -c 'import json,sys; json.load(sys.stdin)' &>/dev/null; then
        # If the output is not JSON, use it directly (old format compatibility)
        cmd_to_execute="$processed_cmd"
    else
        # Get the selected command from the JSON response
        cmd_to_execute=$(echo "$processed_cmd" | python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
    if data["success"]: print(data.get("refined",data.get("original","")))
except: print("")')
    fi
    
    _jarvis_debug "debug" "Executing command: $cmd_to_execute"
    
    # Save the command that will actually be executed
    echo "$cmd_to_execute" > "${cmd_dir}/executed_command"
    
    # Add both original and transformed commands to history
    print -s "@jarvis $*"  # Original command
    print -s "$cmd_to_execute"  # Transformed command
    
    # Create temp files for capturing output
    local stdout_file="${cmd_dir}/stdout"
    local stderr_file="${cmd_dir}/stderr"
    
    # Execute the processed command with output redirection
    if [[ "$cmd_to_execute" =~ [\|\&\;\<\>\(\)] ]]; then
        # Use eval for commands with shell operators
        eval "$cmd_to_execute" > "$stdout_file" 2> "$stderr_file"
    else
        # Execute simple commands directly
        eval "$cmd_to_execute" > "$stdout_file" 2> "$stderr_file"
    fi
    local cmd_ret=$?
    
    # Display stdout and stderr to user
    cat "$stdout_file"
    
    # If command failed or stderr is not empty, show error info
    if [[ $cmd_ret -ne 0 || -s "$stderr_file" ]]; then
        echo "[JARVIS: Command failed with status $cmd_ret]" >&2
        if [[ -s "$stderr_file" ]]; then
            cat "$stderr_file" >&2
        fi
        return 0
    fi
    
    # Save status code
    echo "$ai_status" > "${cmd_dir}/status"
    
    # Store outputs for processing
    _jarvis_last_output="$(cat "${cmd_dir}/stdout" 2>/dev/null)"
    [[ -s "${cmd_dir}/stderr" ]] && _jarvis_last_error="${_jarvis_last_error}\n$(cat "${cmd_dir}/stderr" 2>/dev/null)"
    
    _jarvis_debug "trace" "Command execution returned: $ai_status"
    _jarvis_debug "trace" "Output: $_jarvis_last_output"
    [[ -n "$_jarvis_last_error" ]] && _jarvis_debug "trace" "Error: $_jarvis_last_error"
    
    # Output the command result to the terminal
    [[ -n "$_jarvis_last_output" ]] && echo "$_jarvis_last_output"
    
    # Run cleanup
    _jarvis_cleanup_sessions
    
    return $ai_status
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

# Pre-command processing
_jarvis_preexec() {
    local cmd="$1"
    _jarvis_last_command="$cmd"
    _jarvis_debug "trace" "Pre-command: $cmd"
}

# Post-command processing
_jarvis_precmd() {
    _jarvis_last_status=$?
    _jarvis_debug "trace" "Post-command status: $_jarvis_last_status"
    if [[ -n "$_jarvis_last_command" ]]; then
        _jarvis_debug "debug" "Processing command result: $_jarvis_last_command"
        _jarvis_process_command_result
    fi
}

# Add hooks
autoload -Uz add-zsh-hook
add-zsh-hook preexec _jarvis_preexec
add-zsh-hook precmd _jarvis_precmd

# Initialize
_jarvis_init

# Debug levels:
# Export JARVIS_DEBUG=1 for basic debug info
# Export JARVIS_DEBUG=2 for detailed trace info
# Example: JARVIS_DEBUG=2 @jarvis hello
