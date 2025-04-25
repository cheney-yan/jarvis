#!/usr/bin/env zsh

# Source the main plugin
source "${0:A:h}/../src/jarvis.plugin.zsh"

# Test utilities
test_utils() {
    echo "Testing utilities..."
    _jarvis_is_ai_command "@jarvis test" && echo "✓ Command trigger detection works" || echo "✗ Command trigger detection failed"
}

# Test pre-processing
test_preprocessing() {
    echo "Testing pre-processing..."
    local cmd="@jarvis find largest files"
    _jarvis_process_command "$cmd"
}

# Test post-processing
test_postprocessing() {
    echo "Testing post-processing..."
    _jarvis_last_command="ls -la"
    _jarvis_last_status=0
    _jarvis_process_command_result
}

# Test AI handler
test_ai_handler() {
    echo "Testing AI handler..."
    _jarvis_process_custom_query "@jarvis what happened"
}

# Run all tests
main() {
    echo "Running Jarvis tests..."
    test_utils
    test_preprocessing
    test_postprocessing
    test_ai_handler
    echo "Tests completed."
}

main "$@"
