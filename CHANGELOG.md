# Changelog - Bleakfiber's Chat (Forever)

## [1.1.0] - 2026-10-23: Bleakfiber's Chat is now Nullgate's Chat

### Changed
- **New name**: Bleakfiber's Chat is now **Nullgate's Chat**, from **Nullgate Studios**. It is the same addon on the same CurseForge page.
- **A fresh start for the WoW Forever launch**: the addon now lives in the `NullgatesChat-Forever` folder. Settings from the beta are not carried over, so set the addon up again.
- **Remove the old version**: if you copied your old `Interface` folder over, delete the `BleakfibersChat-Forever` folder from `Interface\AddOns`. If the old version is still installed, a message offers to disable it.
- **New slash commands**: `/nchat` (or `/chat`) opens the settings. The old `/bfchat` commands no longer exist, so please update any macros that use them.
- **Chat history**: saved chat history from the beta is not carried over.
- **Shared media names**: the bundled fonts are now listed as **NullgateUI Regular** and **NullgateUI Bold** in addons that use LibSharedMedia.

## [1.0.9] - 2026-10-10

### Fixed
- **EditBox Input History Navigation**: Replaced key intercept logic by hooking `OnArrowPressed` directly on chat edit boxes (in WoW, arrow keys fire `OnArrowPressed`, not `OnKeyDown`). Pre-hooked `OnEnterPressed` to capture commands (e.g. `/silly`) before Blizzard clears them. Set `SetAltArrowKeyMode(false)` across all edit boxes and hooked `ChatEdit_ActivateChat` so that pressing the Up arrow immediately recalls prior messages and slash commands without requiring the Alt key.

## [1.0.8] - 2026-10-10

### Fixed
- **Backdrop Template Nil Error**: Fixed nil value error at `Core.lua:737` (`ApplyFrameBackdrop`) by scoping `BACKDROP_TEMPLATE` at module head and adding defensive mixin checks across all backdrop elements for modern/custom WoW clients.
- **EditBox Up/Down Arrow Command History**: Resolved input history recall failure when pressing Up/Down arrows. Implemented dedicated keystroke tracking across `OnTextChanged` and `OnKeyDown`, real-time session buffer dispatch, and safe cursor navigation with unsubmitted draft restoration. Slash commands (such as `/silly`) and chat messages can now be immediately recalled with the Up arrow.

## [1.0.7] - 2026-10-09

### Fixed
- **Settings Panel & Profiles Layout**: Fixed widget overlapping in the Profiles and settings tabs by executing initial and tab-switch layout passes and wrapping EditBox controls in unified positioning containers.

## [1.0.6] - 2026-10-09

### Added
- **Suite & Master Hub Integration**: Full soft-hook registration with `BleakfibersAddonConfigForever` (`BleakfibersAddonConfig`), including dynamic live settings refresh, profile syncing, and `ADDON_LOADED` auto-detection.
- **Dual-Mode Settings Panel**: Standalone Dark Slate & Gold window with smooth 2-column dynamic reflow (`UI:BuildOptions`) and clean embedding when opened through the Master Hub.
- **Profiles Management**: Non-destructive profile creation, cloning, deletion, and reset.

## [1.0.5] - 2026-10-09

### Added
- **Channel Shortening**: Shortened channel prefixes across all global, group, and guide channels (`[1]`, `[G]`, `[O]`, `[P]`, `[PL]`, `[R]`, `[RL]`, `[I]`, `[IL]`, `[DG]`).
- **Universal Class Coloring**: Class color names across all channels and player hyperlinks backed by dynamic roster and GUID caching.
- **Typography & Fonts**: Full LibSharedMedia font face, size, and outline options applied across chat frames, tabs, and edit boxes.
- **Window Backdrops**: Dark Slate & Gold custom backdrops with adjustable opacity slider for chat windows.
- **Ergonomics & Clutter Control**: Mousewheel scrolling (Shift jumps to top/bottom, Ctrl scrolls 5 lines), screen unclamping, and clean Blizzard button suppression.

## [1.0.4] - 2026-10-09

### Added
- Phase 1 Foundation: Core chat management architecture, link click parsing, whispers in new window by default, and class color names.

## [1.0.3] - 2026-10-09

### Added
- Phase 1 Foundation: Core chat management architecture, link click parsing, whispers in new window by default, and class color names.

All notable changes to **Bleakfiber's Chat - Forever** are documented below.

## [1.0.2] - 2026-10-09: Phase 3 Persistent History & EditBox Modernization

### Added
- **Command History Persistence**: Captured outgoing chat messages and slash commands in SavedVariables across `/reload` and game sessions, cycleable via the Up/Down arrow keys.
- **Consecutive Duplicate & Sensitive Filter**: Automatically skips duplicate identical consecutive commands and suppresses sensitive commands (`/pass`, `/secret`).
- **Zoning Safe History Restoration**: Guarded `PLAYER_ENTERING_WORLD` to restore history only once per game session, preventing duplicate message playback when entering dungeons, portals, or hearthstoning.
- **Stylized Session Dividers**: High-visibility Dark Slate & Gold session divider marking the transition between past session history and live messages.
- **Dark Slate & Gold EditBox Skinning**: Dedicated backdrop frame with border styling, comfortable text insets, and dynamic focus glow effects (`OnEditFocusGained` / `OnEditFocusLost`).
- **Robust EditBox Docking**: Smooth `TOP` or `BOTTOM` anchoring with `OnShow` position locking to prevent default chat frame anchor snapping.
- **Bidirectional Sticky Channels**: Fully toggleable sticky channel memory across `/say`, `/party`, `/raid`, `/guild`, `/officer`, `/whisper`, and numbered channels.
- **Thorough Buffer Clearing**: `/bfchat history clear` completely purges SavedVariables chat history, command history, and in-memory session tables.
- **Expanded Settings UI**: Added controls for Command History buffer size, Up/Down arrow memory toggle, and EditBox skinning toggle.

## [1.0.1] - 2026-10-09: Phase 2 URL Detection & Copy Dialog Enhancements

### Added
- **Bulletproof URL Detection Engine**: Token-based parser supporting web protocols (`http://`, `https://`, `ftp://`), `www.` prefixes, Discord invites (`discord.gg/`), and all top-level domains (`.com`, `.org`, `.net`, `.io`, `.gg`, `.tv`, `.app`, etc.).
- **Smart Punctuation & Parentheses Trimming**: Automatically trims trailing sentence punctuation (`.`, `,`, `!`, `?`, `;`, `:`) and enclosing brackets/quotes, while intelligently preserving balanced parentheses for complex query strings and Wikipedia links.
- **Hyperlink Preservation Pipeline**: Temporarily shields existing game item, spell, quest, and player links (`|H...|h...|h`) before URL parsing, eliminating corrupted nested markup and double replacements.
- **Interactive Shift-Click URL Insertion**: Shift-clicking any URL link in chat automatically inserts the raw URL directly into your active chat edit box (mirroring standard item link behavior).
- **Interactive URL Copy Dialog**: Clean Dark Slate & Gold modal popup with auto-focus, text pre-selection, single-click re-selection (`OnMouseUp`), and instant `Ctrl + C` copy workflow.
- **Full Chat Log Copy Dialog**: Scrollable multi-line dialog with dynamic content height recalculation, mousewheel scrolling, window resizing grip, and "Select All" button.
- **Plain-Text Formatting Cleaner**: Automatically strips chat color codes (`|c...|r`) and textures while formatting hyperlinks into clean text for external pasting.
- **Temporary Window & Whisper Tab Synchronization**: Auto-hooks `FCF_OpenTemporaryWindow` and `FCF_OpenNewWindow` so newly created whisper tabs immediately receive copy buttons, smooth scrolling, typography, and link handlers.
- **UI Customization Options**: Added URL Accent Color picker in General options and Copy Button toggle in Layout & Style settings.

## [1.0.0] - 2026-10-09: Phase 1 Foundation & Architecture

### Added
- **Core Chat Management Architecture (`Core.lua`, `Config.lua`, `UI.lua`)**: High-performance modular architecture engineered for Interface 16001.
- **Whispers in New Window by Default (`whisperWindow = true`)**: Automatic dedicated tab routing for incoming and outgoing whisper messages with notification highlight pulses.
- **Universal Player Class Color Names (`classColorNames = true`)**: Real-time class color resolution across all chat channels, whispers, and raid/party communications.
- **Persistent Chat & Command History**: Circular SavedVariables buffer preserving chat lines across reload and relogs with subtle session divider timestamps.
- **EditBox Modernization & Docking**: Bottom or Top docking options, sticky channel memory, and Dark Slate & Gold backdrop skinning.
- **Dual-Mode Configuration & Master Hub Integration**: Seamless runtime embed into `BleakfibersAddonConfig-Forever` with non-destructive profile capture and dynamic 2-column reflow.
