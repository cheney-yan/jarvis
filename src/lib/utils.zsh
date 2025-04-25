#!/usr/bin/env zsh

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
    
    if [[ -n "$JARVIS_DEBUG" ]]; then
        case "$level" in
            "debug")
                [[ "$JARVIS_DEBUG" =~ ^[1-9]$ ]] && echo "${color_debug}[JARVIS DEBUG]${color_reset} $msg" >&2
                ;;
            "trace")
                [[ "$JARVIS_DEBUG" -ge 2 ]] && echo "${color_trace}[JARVIS TRACE]${color_reset} $msg" >&2
                ;;
        esac
    fi
}
