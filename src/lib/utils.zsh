#!/usr/bin/env zsh

# Spinner process ID
typeset -g _jarvis_spinner_pid

# Start a spinner
_jarvis_start_spinner() {
    local msg="$1"
    # Define spinner characters
    local -a spinner_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    
    # Open direct terminal connection
    exec 4>/dev/tty
    
    # Ensure we're in a terminal
    [[ -t 1 ]] || { exec 4>&-; return; }
    
    # Function to cleanup spinner
    _jarvis_cleanup_spinner() {
        [[ -n "$_jarvis_spinner_pid" ]] && kill $_jarvis_spinner_pid &>/dev/null
        _jarvis_spinner_pid=""
        tput cnorm >&4 # Show cursor
        echo -ne "\r\033[K" >&4 # Clear line
        exec 4>&- # Close terminal connection
    }
    
    # Start spinner in background
    (
        local i=0
        tput civis >&4 # Hide cursor
        while true; do
            echo -ne "\r\033[K${spinner_chars[$((i % 10 + 1))]} $msg" >&4
            sleep 0.1
            ((i++))
        done
    ) &
    
    _jarvis_spinner_pid=$!
    
    # Ensure cleanup on exit or interrupt
    trap _jarvis_cleanup_spinner EXIT INT TERM
}

# Stop the spinner
_jarvis_stop_spinner() {
    [[ -n "$_jarvis_spinner_pid" ]] && kill $_jarvis_spinner_pid &>/dev/null
    _jarvis_spinner_pid=""
    # Open direct terminal connection
    exec 4>/dev/tty
    tput cnorm >&4 # Show cursor
    echo -ne "\r\033[K" >&4 # Clear line
    exec 4>&- # Close terminal connection
}

# Utility functions for Jarvis

# Get trigger prefix from config or use default
_jarvis_get_trigger_prefix() {
    local config_file="${JARVIS_HOME}/mcp/config.json"
    if [[ -f "$config_file" ]]; then
        local prefix=$(cat "$config_file" | grep -o '"trigger_prefix":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        echo "${prefix:-@jarvis}"
    else
        echo "@jarvis"
    fi
}

# Check if command matches trigger pattern
_jarvis_is_ai_command() {
    local cmd="$1"
    local trigger=$(_jarvis_get_trigger_prefix)
    [[ "$cmd" =~ ^$trigger ]]
}

# Safe command execution with error handling
_jarvis_safe_exec() {
    local cmd="$1"
    local output
    local status
    
    output="$(eval "$cmd" 2>&1)"
    status=$?
    
    echo "$output"
    return $status
}

# Load MCP configuration
_jarvis_load_mcp_config() {
    local config_file="${JARVIS_HOME}/mcp/config.json"
    if [[ -f "$config_file" ]]; then
        # TODO: Implement MCP configuration loading
        return 0
    fi
    return 1
}

# Format command output for display
_jarvis_format_output() {
    local output="$1"
    local max_lines=${2:-10}
    
    echo "$output" | head -n "$max_lines"
}

# Debug logging
_jarvis_debug() {
    local level="$1"
    local msg="$2"
    local color_reset="\033[0m"
    local color_debug="\033[36m"  # Cyan for debug
    local color_trace="\033[35m"  # Magenta for trace
    local color_info="\033[32m"   # Green for info
    # Debug-level log for function entry
    if [[ -n "$JARVIS_DEBUG" ]]; then
        case "$level" in
            "info")
                echo "${color_info}[JARVIS INFO]${color_reset} $msg" >&2
                ;;
            "debug")
                [[ "$JARVIS_DEBUG" =~ ^[1-9]$ ]] && echo "${color_debug}[JARVIS DEBUG]${color_reset} $msg" >&2
                ;;
            "trace")
                [[ "$JARVIS_DEBUG" -ge 2 ]] && echo "${color_trace}[JARVIS TRACE]${color_reset} $msg" >&2
                ;;
        esac
    fi
}

