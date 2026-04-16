# Changelog

All notable changes to Model Matchmaker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-04-05

### Added
- Auto-switch: automatic model switching via keyboard automation
- Toggle command: `~/.cursor/hooks/toggle-auto-switch.sh on|off`
- Terminal-based keyboard automation for Cmd+/ interaction
- Automatic message resubmission after model switch

### Fixed
- Focus stealing during auto-switch activation
- Timing reliability for model dropdown interaction
- Keystroke simulation improvements (switched from key codes to direct keystrokes)
- Terminal window close timing to prevent focus issues

### Changed
- Character typing speed: 0.05s → 0.15s between keystrokes for better reliability
- Removed unnecessary Down arrow navigation
- Simplified activation flow to prevent focus conflicts

## [1.0.0] - 2026-03-XX

### Added
- Initial release
- Prompt classification (Haiku/Sonnet/Opus)
- Step-down/step-up recommendations
- Override with `!` prefix
- Local hook integration for Cursor and Claude Code
