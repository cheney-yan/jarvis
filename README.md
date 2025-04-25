# Jarvis - AI-Powered ZSH Plugin

Jarvis is an intelligent command-line assistant that enhances your shell experience with AI-powered features.

## Features

- Natural language command processing with '@jarvis' prefix (configurable)
- Automatic command suggestions and corrections
- Post-execution analysis and explanations
- Integration with MCP for advanced AI capabilities

## Installation

1. Clone the repository:
```bash
git clone https://github.com/cheney-yan/jarvis.git ~/.jarvis
```

2. Add to your `.zshrc`:
```bash
source ~/.jarvis/src/jarvis.plugin.zsh
```

## Usage

- `@jarvis find the largest file` - Get help finding large files
- `@jarvis ?` - Explain what just happened
- `@jarvis why` - Explain why the last command failed

## Development

1. Clone the repository
2. Install dependencies
3. Run tests: `zsh tests/test_commands.zsh`

## License

MIT License
