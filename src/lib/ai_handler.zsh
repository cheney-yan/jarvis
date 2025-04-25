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
    
    # Set up direct terminal output
    exec 3>/dev/tty
    
    # Set a timeout for the Python script (30 seconds)
    local result
    _jarvis_start_spinner "Thinking..."
    result=$(timeout --kill-after=5 30 python3 "${JARVIS_HOME}/lib/python/llm_handler.py" process --query "$query" 2>&1)
    local py_status=$?
    _jarvis_stop_spinner
    
    # Parse debug info first
    _jarvis_debug "debug" "Processing query using llm: $query" >&3
    
    # Check for timeout
    if [[ $py_status -eq 124 || $py_status -eq 137 ]]; then
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
    local parsed_result
    parsed_result=$(echo "$result" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    if data["success"]:
        print(json.dumps({
            "success": True,
            "is_command": data.get("is_command", False),
            "original": data.get("original", ""),
            "refined": data.get("refined", ""),
            "explanation": data.get("explanation", "")
        }))
    else:
        print(json.dumps({
            "success": False,
            "error": data.get("error", "Unknown error")
        }))
except Exception as e:
    print(json.dumps({"success": False, "error": str(e)}))
')
    
    local success=$(echo "$parsed_result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["success"])')
    if [[ $success == "True" ]]; then
        # Get all fields from the response
        local is_command=$(echo "$parsed_result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["is_command"])')
        local original=$(echo "$parsed_result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["original"])')
        local refined=$(echo "$parsed_result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["refined"])')
        local explanation=$(echo "$parsed_result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["explanation"])')
        
        # Show the explanation
        echo "$explanation" >&2
        
        # If it's already a valid command and no refinement needed
        if [[ $is_command == "True" && "$original" == "$refined" ]]; then
            echo "$original"
            return 0
        fi
        
        # Already have terminal output set up
        
        # Show options with highlighting
        echo "\n\033[1mPlease choose an action:\033[0m" >&3
        echo "\033[1;32m1)\033[0m Use refined command: \033[0;32m${refined[*]}\033[0m" >&3
        echo "\033[1;33m2)\033[0m Use original input: \033[0;34m${original[*]}\033[0m" >&3
        echo "\033[1;31m3)\033[0m Cancel" >&3
        
        # Get user choice with explicit flush
        local choice=""
        while true; do
            echo -n "\033[1mEnter your choice (1-3):\033[0m " >&3
            command stty echo  # Ensure echo is on
            read -r choice </dev/tty  # Read directly from terminal
            
            # Skip empty or whitespace-only input
            [[ -z "${choice// /}" ]] && continue
            
            case "$choice" in
                1)
                    exec 3>&-  # Close terminal fd
                    echo "$refined"
                    return 0
                    ;;
                2)
                    exec 3>&-  # Close terminal fd
                    echo "$original"
                    return 0
                    ;;
                3)
                    exec 3>&-  # Close terminal fd
                    return 1
                    ;;
                *)
                    # Invalid input, clear and try again
                    echo -ne "\r\033[K" >&3  # Clear the line
                    echo "\033[31mPlease enter 1, 2, or 3\033[0m" >&3
                    ;;
            esac
        done
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
