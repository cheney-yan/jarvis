#!/usr/bin/env zsh

# Handle AI command processing
_jarvis_handle_ai_command() {
    local cmd="$1"
    local trigger=$(_jarvis_get_trigger_prefix)
    local query="${cmd#$trigger }"
    
    case "$query" in
        "?"|"what"|"what happened")
            _jarvis_explain_last_command
            ;;
        "why"|"why failed")
            _jarvis_explain_failure
            ;;
        *)
            _jarvis_process_custom_query "$query"
            ;;
    esac
}

# Process custom AI queries
_jarvis_process_custom_query() {
    local query="$1"
    # TODO: Implement MCP integration for query processing
    echo "Processing query: $query" >&2  # Debug output to stderr
    echo "$query"  # Return the command to execute
}

# Explain last command execution
_jarvis_explain_last_command() {
    # TODO: Implement MCP integration for command explanation
    echo "Last command: $_jarvis_last_command"
    echo "Status: $_jarvis_last_status"
}

# Explain command failure
_jarvis_explain_failure() {
    if [[ $_jarvis_last_status -ne 0 ]]; then
        # TODO: Implement MCP integration for failure analysis
        echo "Command failed with status: $_jarvis_last_status"
        echo "Error output: $_jarvis_last_error"
    fi
}
