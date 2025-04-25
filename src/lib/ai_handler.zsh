#!/usr/bin/env zsh


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
    if [[ $llm_status -eq 124 || $llm_status -eq 137 ]]; then
        echo "Query processing timed out after 30 seconds" >&2
        return $llm_status
    fi
    if [[ $llm_status -ne 0 ]]; then
        echo "Failed to process query: $result" >&2
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
    local system_prompt='You are a shell command result analyzer. You gives clear and short suggestions on failed commands. Given command, "'$2'", the command status_code is '$1', output "'$3'" and error "'$4'". Please provide suggestions of what happened, how can I refine my command to fix the issue.'
    _jarvis_debug "trace" "Using model: $model_name, no change response: $no_change_response, system prompt: $system_prompt"
    # Call llm grok directly to process the query
    local result
    result=$(llm -m "$model_name" -s "$system_prompt" "$query" 2>&1)
    local llm_status=$?

    _jarvis_debug "debug" "LLM response: $result"

    # Check for timeout or failure
    if [[ $llm_status -eq 124 || $llm_status -eq 137 ]]; then
        echo "Query processing timed out after 30 seconds" >&2
        return $llm_status
    fi
    if [[ $llm_status -ne 0 ]]; then
        echo "Failed to process query: $result" >&2
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
    echo "\033[1m👋 Please choose an action:\033[0m" >&3
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
