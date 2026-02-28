# copilot-nvim 🤖

A Neovim plugin that brings GitHub Copilot Agent directly into your editor — powered by the official [GitHub Copilot SDK](https://github.com/github/copilot-sdk).

> ⚠️ This plugin is in early development and requires a GitHub Copilot subscription.

---

## Features

| Feature | Keymap | Description |
|---------|--------|-------------|
| **Inline Completions** | `Ctrl+G` | AI code suggestions as ghost text while you type |
| **Chat Sidebar** | `Ctrl+P` | Chat with Copilot about your code |
| **Code Review** | `\r` | Instant code review in a split window |
| **Terminal Agent** | `\a` | Copilot runs shell commands autonomously |

---

## Requirements

- [Neovim](https://neovim.io/) v0.9+
- [Node.js](https://nodejs.org/) v18+
- [GitHub CLI](https://cli.github.com/) v2.0+
- A GitHub account with [Copilot access](https://github.com/features/copilot)

---

## Installation

### 1. Install GitHub CLI and authenticate

```powershell
winget install GitHub.cli
gh auth login
```

### 2. Install gh copilot extension

```bash
gh extension install github/gh-copilot
```

### 3. Clone this plugin

```bash
git clone https://github.com/yourusername/copilot-nvim.git
```

### 4. Install Node.js dependencies

```bash
cd copilot-nvim/node
npm install
```

### 5. Add to your Neovim config

Add this to your `~/.config/nvim/init.lua` (Linux/Mac) or `~/AppData/Local/nvim/init.lua` (Windows):

```lua
vim.opt.runtimepath:append("/path/to/copilot-nvim")

require("copilot-nvim").setup({
  node_bridge = "/path/to/copilot-nvim/node/src/index.ts",
})
```

---

## Usage

### Inline Completions

1. Open any code file
2. Enter insert mode (`i`)
3. Start typing — completions appear automatically after ~1 second
4. Press `Ctrl+G` to manually trigger
5. Press `Tab` to accept, `Esc` to dismiss

### Chat Sidebar

1. Press `Ctrl+P` in normal mode
2. Type your question in the input box
3. Press `Enter` to send
4. Press `q` to close

**Example questions:**
```
How do I reverse a string in Python?
Explain what this function does
How can I optimize this code?
```

### Code Review

1. Open any supported file (`.py`, `.js`, `.ts`, `.lua`, `.go`, `.rs`)
2. Press `\r` to trigger a review
3. OR save the file (`:w`) for automatic review
4. Press `q` to close the review panel

### Terminal Agent

1. Press `\a` to open the agent panel
2. Type a task in the input box
3. Press `Enter` — Copilot will explain what it will do and run the command automatically in the terminal

**Example tasks:**
```
list all files in current directory
create a hello.py file
show me running processes
install the requests library
```

---

## Architecture

```
Neovim (Lua layer)
      ↕  stdio/JSON
Node.js process (TypeScript)
      ↕  JSON-RPC
Copilot CLI (local server)
      ↕  API
GitHub Copilot Agent
```

The plugin uses a **bridge pattern** — a thin Lua layer in Neovim communicates with a Node.js process via stdio. The Node.js process uses the official `@github/copilot-sdk` to talk to the Copilot CLI, which handles authentication and API communication.

---

## Project Structure

```
copilot-nvim/
├── lua/
│   └── copilot-nvim/
│       ├── init.lua          # Core bridge management
│       ├── completions.lua   # Inline completions
│       ├── chat.lua          # Chat sidebar
│       ├── review.lua        # Code review
│       └── agent.lua         # Terminal agent
├── node/
│   ├── src/
│   │   └── index.ts          # Node.js bridge
│   ├── package.json
│   └── tsconfig.json
└── README.md
```

---

## Keymaps Summary

| Mode | Key | Action |
|------|-----|--------|
| Insert | `Ctrl+G` | Trigger completion |
| Insert | `Tab` | Accept completion |
| Insert | `Esc` | Dismiss completion |
| Normal | `Ctrl+P` | Open chat |
| Normal | `\r` | Review code |
| Normal | `\a` | Open agent |
| Normal | `q` | Close any panel |

---

## Getting Copilot Access

**Students (Free):** Apply for the [GitHub Student Developer Pack](https://education.github.com/pack) to get Copilot Pro for free.

**Individual:** Sign up for [Copilot Pro](https://github.com/features/copilot) ($10/month).

---

## Contributing

Contributions are welcome! This plugin is built on top of the brand new [GitHub Copilot SDK](https://github.com/github/copilot-sdk) (currently in technical preview), so there's a lot of room to grow.

Some ideas for contributions:
- Multi-line ghost text completions
- Conversation history in chat
- Diff view for code review
- Support for more file types
- Lazy.nvim / Packer installation support

---

## License

MIT