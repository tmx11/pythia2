# Pythia - AI Copilot for Delphi IDE

A VS Code Copilot-style AI chat assistant plugin for Embarcadero Delphi 12.

## Features

- **Integrated Chat Window**: VS Code-style chat interface accessible via `Tools > Pythia AI Chat` or `Ctrl+Shift+P`
- **Multiple AI Models**: Support for OpenAI (GPT-4, GPT-3.5) and Anthropic (Claude 3.5 Sonnet, Claude 3 Opus)
- **Delphi Expert**: Trained to help with Delphi programming questions, code review, and debugging
- **Persistent Configuration**: API keys stored securely in user's AppData folder

## Installation

1. Open `pythia.dproj` in Delphi 12
2. Build the package (Project > Build pythia)
3. Install the package (Component > Install Packages > Add > select compiled BPL)
4. Restart Delphi IDE

## Configuration

1. After installation, open **Tools > Pythia AI Chat**
2. Click **Settings** button
3. Enter your API keys:
   - OpenAI API key from https://platform.openai.com/api-keys
   - Anthropic API key from https://console.anthropic.com/settings/keys

Configuration is stored in: `%APPDATA%\Pythia\pythia.ini`

## Usage

### Opening the Chat Window
- Menu: **Tools > Pythia AI Chat**
- Keyboard: **Ctrl+Shift+P**

### Using the Chat
1. Select your preferred AI model from the dropdown
2. Type your question or request in the input box
3. Press **Send** button or **Ctrl+Enter**
4. View the AI response in the chat window

### Example Prompts
- "How do I implement a thread-safe singleton in Delphi?"
- "Review this code for memory leaks"
- "What's the best way to parse JSON in Delphi?"
- "Convert this code to use generics"

## Project Structure

```
pythia2/
├── Source/
│   ├── Pythia.Register.pas      # IDE plugin registration
│   ├── Pythia.ChatForm.pas/.dfm # Chat UI form
│   ├── Pythia.AI.Client.pas     # AI API client
│   └── Pythia.Config.pas        # Configuration manager
├── pythia.dpk                   # Package source
└── pythia.dproj                 # Project file
```

## Requirements

- Embarcadero Delphi 12 (Athens)
- Windows 32-bit or 64-bit
- Internet connection for AI API calls
- Valid API key(s) for OpenAI and/or Anthropic

## Development

To modify or extend Pythia:

1. Clone/open the project in Delphi 12
2. Make your changes to the source files
3. Rebuild the package
4. Uninstall old version from IDE if needed
5. Install the new version

## API Costs

Both OpenAI and Anthropic charge per API usage. Monitor your usage:
- OpenAI: https://platform.openai.com/usage
- Anthropic: https://console.anthropic.com/settings/usage

## Troubleshooting

**Chat window doesn't appear**
- Ensure package is properly installed
- Check IDE's Package list (Component > Install Packages)
- Restart Delphi IDE

**API errors**
- Verify API keys are correct in Settings
- Check internet connection
- Ensure you have API credits remaining

**Build errors**
- Verify Delphi 12 is properly installed
- Check all source files are present
- Clean and rebuild the project

## License

[Your License Here]

## Contributing

Contributions welcome! Please submit pull requests or open issues for bugs/features.

## Roadmap

- [ ] Settings dialog with API key management
- [ ] Code context awareness (send selected editor code)
- [ ] Syntax highlighting in chat responses
- [ ] Export chat history
- [ ] Custom system prompts
- [ ] Inline code suggestions
- [ ] Integration with IDE code editor

## Credits

Created by [Your Name]

Inspired by GitHub Copilot Chat in VS Code.
