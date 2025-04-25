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
    
    # Call llm grok directly to process the query
    local result
    _jarvis_start_spinner "Thinking..."
    result=$(llm -m grok-3-latest -s 'You are a shell command processor. Given a user query, output ONLY the refined shell command that should be run. Output nothing else. The output should be a plain text command, single line, returns stripped, no quotes. It can be multiple commands concatenated with () and &&.' "$query" 2>&1)
    local llm_status=$?
    _jarvis_stop_spinner

    _jarvis_debug "debug" "Processing query using llm: $query" >&3

    # Check for timeout or failure
    if [[ $llm_status -eq 124 || $llm_status -eq 137 ]]; then
        echo "Query processing timed out after 30 seconds" >&2
        return 1
    fi
    if [[ $llm_status -ne 0 ]]; then
        echo "Failed to process query: $result" >&2
        return 1
    fi
    
    # Treat $result as the refined command (plain text)
    local refined_cmd="$result"
    local original_cmd="$query"

    # If empty, treat as failure
    if [[ -z "$refined_cmd" ]]; then
        echo "AI handler failed to produce a command." >&2
        return 1
    fi

    # If same, run it directly
    if [[ "$refined_cmd" == "$original_cmd" ]]; then
        exec 3>&-  # Close extra fd
        eval "$original_cmd" < /dev/tty > /dev/tty 2>&1
        return $?
    fi

    # Otherwise, present options to the user
    echo "" >&3
    echo "\033[1mPlease choose an action:\033[0m" >&3
    echo "\033[1;32m1)\033[0m Use refined command: \033[0;32m${refined_cmd}\033[0m" >&3
    echo "\033[1;33m2)\033[0m Use original input: \033[0;34m${original_cmd}\033[0m" >&3
    echo "\033[1;31m3)\033[0m Cancel" >&3

    local choice=""
    while true; do
        echo -n "\033[1mEnter your choice (1-3):\033[0m " >&3
        command stty echo  # Ensure echo is on
        read -r choice </dev/tty  # Read directly from terminal
        [[ -z "${choice// /}" ]] && continue
        case "$choice" in
            1)
                exec 3>&-  # Close terminal fd
                eval "$refined_cmd" < /dev/tty > /dev/tty 2>&1
                return $?
                ;;
            2)
                exec 3>&-  # Close terminal fd
                eval "$original_cmd" < /dev/tty > /dev/tty 2>&1
                return $?
                ;;
            3)
                exec 3>&-  # Close terminal fd
                return 1
                ;;
            *)
                echo -ne "\r\033[K" >&3  # Clear the line
                echo "\033[31mPlease enter 1, 2, or 3\033[0m" >&3
                ;;
        esac
    done
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
