# WYSIWYG Markdown Editor Project

## Overview
This project implements a native iOS WYSIWYG markdown editor using the Lexical-iOS framework. The editor provides real-time markdown editing with rich text formatting while maintaining full markdown compatibility.

## Goals
- Create a production-ready WYSIWYG markdown editor for iOS
- Leverage Lexical-iOS framework for robust text editing foundation
- Provide a clean, type-safe Swift API for easy integration
- Support standard markdown elements (headers, lists, formatting, etc.)
- Maintain native iOS design patterns and accessibility

## Architecture
The component is built with a modular architecture:

### Core Components
- **MarkdownEditor**: Main editor view that wraps LexicalView
- **MarkdownFormattingToolbar**: Formatting controls toolbar
- **Configuration System**: Type-safe configuration and theming
- **Document Model**: Structured markdown document representation

### Key Features
- Real-time WYSIWYG editing
- Markdown export/import
- Configurable themes and typography
- Inline formatting (bold, italic, strikethrough, code)
- Block types (headers, lists, quotes, code blocks)
- Native iOS accessibility support

## Framework References
- **Lexical-iOS**: Located at `../lexical-ios-main/`
  - Core framework documentation in source files
  - Example usage in `Playground/LexicalPlayground/`
  - Markdown plugin at `Plugins/LexicalMarkdown/`

## Development Setup
- **iOS Development**: Use the ios-devloop MCP for building, testing, and simulator interaction
- **Build Commands**: Leverage ios-devloop for compilation and app launching
- **Testing**: Use ios-devloop for simulator testing and debugging

## Implementation Plan
1. **Core Setup**: Basic editor component with Lexical integration
2. **Configuration**: Theme system and feature configuration
3. **Formatting**: Inline and block formatting controls
4. **Toolbar**: User interface for formatting controls
5. **Export/Import**: Markdown conversion capabilities
6. **Demo Integration**: Example usage in demo app

## Testing Commands
- Build: Use `mcp__ios-devloop__build`
- Launch: Use `mcp__ios-devloop__launch_app`
- Debug: Use `mcp__ios-devloop__debug_*` tools as needed

## Current Status
Starting implementation of core components based on the technical specification.