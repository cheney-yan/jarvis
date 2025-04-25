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
    _jarvis_debug "debug" "Processing query using llm: $query"
    
    # Set a timeout for the Python script (30 seconds)
    local result
    result=$(timeout 30 python3 "${JARVIS_HOME}/lib/python/llm_handler.py" process --query "$query" 2>&1)
    local py_status=$?
    
    # Check for timeout
    if [[ $py_status -eq 124 ]]; then
        echo "Query processing timed out after 30 seconds" >&2
        return 1
    fi
    
    if [[ $py_status -ne 0 ]]; then
        echo "Failed to process query: $result" >&2
        return 1
    fi
    
    # Validate JSON response
    if ! echo "$result" | python3 -c 'import json,sys; json.load(sys.stdin)' &>/dev/null; then
        echo "Invalid response from AI handler: $result" >&2
        return 1
    fi
    
    # Parse JSON response
    local success=$(echo "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["success"])')
    if [[ $success == "True" ]]; then
        local command=$(echo "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["command"])')
        if [[ -z "$command" ]]; then
            echo "Error: Empty command returned" >&2
            return 1
        fi
        echo "$command"
    else
        local error=$(echo "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["error"])')
        echo "Error processing query: $error" >&2
        return 1
    fi
}

# Explain last command execution
_jarvis_explain_last_command() {
    _jarvis_debug "debug" "Explaining last command using llm"
    
    # Call Python script for explanation
    local result
    result=$(python3 "${JARVIS_HOME}/lib/python/llm_handler.py" explain \
        --command "$_jarvis_last_command" \
        --status "$_jarvis_last_status" \
        --output "$_jarvis_last_output" \
        --error "$_jarvis_last_error")
    local py_status=$?
    
    if [[ $py_status -ne 0 ]]; then
        echo "Failed to explain command" >&2
        return 1
    fi
    
    # Parse JSON response
    local success=$(echo $result | python3 -c 'import json,sys; print(json.load(sys.stdin)["success"])')
    if [[ $success == "True" ]]; then
        local explanation=$(echo $result | python3 -c 'import json,sys; print(json.load(sys.stdin)["explanation"])')
        echo "$explanation"
    else
        local error=$(echo $result | python3 -c 'import json,sys; print(json.load(sys.stdin)["error"])')
        echo "Error explaining command: $error" >&2
        return 1
    fi
}

# Explain command failure
_jarvis_explain_failure() {
    if [[ $_jarvis_last_status -ne 0 ]]; then
        _jarvis_debug "debug" "Explaining failure using llm"
        
        # Call Python script for failure analysis
        local result
        result=$(python3 "${JARVIS_HOME}/lib/python/llm_handler.py" failure \
            --command "$_jarvis_last_command" \
            --status "$_jarvis_last_status" \
            --error "$_jarvis_last_error")
        local py_status=$?
        
        if [[ $py_status -ne 0 ]]; then
            echo "Failed to analyze failure" >&2
            return 1
        fi
        
        # Parse JSON response
        local success=$(echo $result | python3 -c 'import json,sys; print(json.load(sys.stdin)["success"])')
        if [[ $success == "True" ]]; then
            local explanation=$(echo $result | python3 -c 'import json,sys; print(json.load(sys.stdin)["explanation"])')
            echo "$explanation"
        else
            local error=$(echo $result | python3 -c 'import json,sys; print(json.load(sys.stdin)["error"])')
            echo "Error analyzing failure: $error" >&2
            return 1
        fi
    fi
}
