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
source "${JARVIS_HOME}/lib/utils.zsh"
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
    
    # Get the processed command
    local processed_cmd="$(cat "${cmd_dir}/ai_output")"
    _jarvis_last_error="$(cat "${cmd_dir}/ai_error")"
    
    _jarvis_debug "trace" "AI handler returned: $ai_ret"
    _jarvis_debug "debug" "Executing command: $processed_cmd"
    
    # Execute the processed command
    eval "$processed_cmd" > "${cmd_dir}/stdout" 2> "${cmd_dir}/stderr"
    local cmd_ret=$?
    fc -P    # Restore original history file
    
    # Save status code
    echo "$cmd_ret" > "${cmd_dir}/status"
    
    # Store outputs for processing
    _jarvis_last_output="$(cat "${cmd_dir}/stdout" 2>/dev/null)"
    [[ -s "${cmd_dir}/stderr" ]] && _jarvis_last_error="${_jarvis_last_error}\n$(cat "${cmd_dir}/stderr" 2>/dev/null)"
    
    _jarvis_debug "trace" "Command execution returned: $cmd_ret"
    _jarvis_debug "trace" "Output: $_jarvis_last_output"
    [[ -n "$_jarvis_last_error" ]] && _jarvis_debug "trace" "Error: $_jarvis_last_error"
    
    # Output the command result to the terminal
    [[ -n "$_jarvis_last_output" ]] && echo "$_jarvis_last_output"
    
    # Run cleanup
    _jarvis_cleanup_sessions
    
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
    typeset -g _jarvis_session_dir="${JARVIS_SESSION_DIR}/session_$$"
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
