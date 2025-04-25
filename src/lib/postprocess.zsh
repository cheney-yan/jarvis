#!/usr/bin/env zsh

# Process command result after execution
_jarvis_process_command_result() {
    # We already have the command in _jarvis_last_command
    # and the status in _jarvis_last_status
    # No need to use fc to get them
    
    _jarvis_debug "debug" "Processing command: $_jarvis_last_command with status: $_jarvis_last_status"
    
    # Get command output and error
    _jarvis_last_output="$(cat "${_jarvis_session_dir}/${_jarvis_command_count}/stdout" 2>/dev/null)"
    _jarvis_last_error="$(cat "${_jarvis_session_dir}/${_jarvis_command_count}/stderr" 2>/dev/null)"
    _jarvis_last_status="$(cat "${_jarvis_session_dir}/${_jarvis_command_count}/status" 2>/dev/null)"
    
    # Store command execution data
    _jarvis_store_command_data
}

# Store command execution data for later analysis
_jarvis_store_command_data() {
    # Get the executed command
    local executed_cmd="$(cat "${_jarvis_session_dir}/${_jarvis_command_count}/executed_command" 2>/dev/null)"
    
    # Format command data as JSON
    local cmd_data="{
        \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
        \"input\": \"$_jarvis_last_command\",
        \"executed\": \"$executed_cmd\",
        \"status\": $_jarvis_last_status,
        \"output\": \"$_jarvis_last_output\",
        \"error\": \"$_jarvis_last_error\"
    }"
    
    # Save to current command's metadata file
    echo "$cmd_data" > "${_jarvis_session_dir}/${_jarvis_command_count}/metadata.json"
    _jarvis_debug "trace" "Command data stored in session directory: ${_jarvis_session_dir}/${_jarvis_command_count}"
}
