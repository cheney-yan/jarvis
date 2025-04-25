# Jarvis - AI-Powered Shell Assistant

Jarvis is an intelligent, AI-powered command-line assistant that enhances your shell (Zsh, Bash, etc.) experience with natural language command processing, automatic suggestions, and post-execution explanations.

## Features

- Natural language command processing with `@jarvis` prefix (configurable)
- Automatic command suggestions, corrections, and explanations
- Post-execution analysis and error troubleshooting using AI
- Integration with MCP for advanced AI capabilities
- Works by sourcing a single file—no plugin system required
- Python/llm backend for command understanding and explanation

## Quickstart

1. **Clone the repository:**
   ```bash
   git clone https://github.com/cheney-yan/jarvis.git ~/.jarvis
   ```

2. **Source Jarvis in your shell config (Zsh, Bash, etc.):**
   ```bash
   # Add to ~/.zshrc or ~/.bashrc or source directly in your terminal
   source ~/.jarvis/src/jarvis.plugin.zsh
   ```
   Jarvis does not require Zsh plugin hooks—just source the file to enable.

3. **Install Python dependencies:**
   - Requires Python 3 and the `llm` package (`pip install llm`)

## Usage

- `@jarvis find the largest file` — Get help finding large files
- `@jarvis ?` — Explain what just happened
- `@jarvis why` — Explain why the last command failed
- Jarvis will suggest, refine, and explain commands as you work

## Development

1. Clone the repository
2. Install dependencies (`pip install llm`)
3. Run tests: `zsh tests/test_commands.zsh`

## License

MIT License
