#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "================================"
echo "  Terminal IDE Installer"
echo "  Helix + Zellij + Yazi"
echo "================================"
echo

info "Installing packages..."
if command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm helix zellij yazi zsh git curl python-lsp-server ruff python-debugpy
elif command -v apt &>/dev/null; then
    sudo apt update
    sudo apt install -y zsh git curl
    sudo snap install helix --classic 2>/dev/null || warn "Install helix manually: https://helix-editor.com"
    sudo snap install zellij --classic 2>/dev/null || warn "Install zellij manually: https://zellij.dev"
    warn "Install yazi manually: https://yazi-rs.github.io/docs/installation"
    pip3 install --user python-lsp-server ruff debugpy 2>/dev/null
elif command -v dnf &>/dev/null; then
    sudo dnf install -y zsh git curl helix zellij
    warn "Install yazi manually: https://yazi-rs.github.io/docs/installation"
    pip3 install --user python-lsp-server ruff debugpy 2>/dev/null
else
    warn "Unknown package manager. Install manually: helix, zellij, yazi, zsh, pylsp, ruff, debugpy"
fi

# ── Oh My Zsh ──
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    info "Oh My Zsh already installed"
fi

# zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    info "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    info "Installing zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Set default shell to zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Setting zsh as default shell..."
    chsh -s "$(which zsh)" 2>/dev/null || warn "Run manually: chsh -s \$(which zsh)"
fi

missing=()
for cmd in helix zellij yazi; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if [ ${#missing[@]} -gt 0 ]; then
    warn "Still missing: ${missing[*]}"
    echo
fi

info "Creating directories..."
mkdir -p "$HOME/.config/helix"
mkdir -p "$HOME/.config/zellij/layouts"
mkdir -p "$HOME/.config/yazi"
mkdir -p "$HOME/.local/bin"

# ── Zsh config ──
info "Writing .zshrc..."
cat > "$HOME/.zshrc" << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="helix"

alias ide='cd "${1:-.}" && zellij --layout ide'
alias ll='ls -la'
alias gs='git status'
alias gp='git push'
alias gc='git commit'
ZSHRC

# ── Helix config ──
info "Writing Helix config..."
cat > "$HOME/.config/helix/config.toml" << HELIX_CONF
theme = "catppuccin_mocha"

[editor]
line-number = "relative"
cursorline = true
color-modes = true
auto-save = { after-delay.enable = true, after-delay.timeout = 1000 }
bufferline = "always"
auto-format = true

[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"

[editor.lsp]
display-messages = true
display-inlay-hints = true

[editor.indent-guides]
render = true
character = "│"

[keys.normal]
"C-r" = ":sh \$HOME/.local/bin/hx-run %{buffer_name}"
"F5" = ":sh \$HOME/.local/bin/hx-debug %{buffer_name}"
"C-f" = "search"
"C-z" = "undo"
"C-y" = "redo"
"C-x" = ["select_mode", "extend_to_line_bounds", "delete_selection", "normal_mode"]
"C-c" = ["select_mode", "extend_to_line_bounds", "yank", "normal_mode"]
"C-v" = "paste_before"
"C-a" = "select_all"
"C-s" = ":write"
"S-tab" = ":buffer-previous"
"tab" = ":buffer-next"
"C-w" = ":buffer-close"
"A-:" = "command_mode"

[keys.insert]
"C-r" = ["normal_mode", ":sh \$HOME/.local/bin/hx-run %{buffer_name}"]
"F5" = ["normal_mode", ":sh \$HOME/.local/bin/hx-debug %{buffer_name}"]
"C-f" = ["normal_mode", "search"]
"C-z" = "undo"
"C-y" = "redo"
"C-x" = ["normal_mode", "select_mode", "extend_to_line_bounds", "delete_selection", "insert_mode"]
"C-c" = ["normal_mode", "select_mode", "extend_to_line_bounds", "yank", "insert_mode"]
"C-v" = "paste_before"
"C-a" = ["normal_mode", "select_all"]
"C-s" = [":write"]
"A-:" = ["normal_mode", "command_mode"]

[keys.select]
"C-c" = "yank"
"C-x" = "delete_selection"
"C-v" = "paste_before"

[editor.statusline]
left = ["mode", "spinner", "diagnostics"]
center = ["file-name", "file-modification-indicator"]
right = ["selections", "position", "file-encoding"]
HELIX_CONF

cat > "$HOME/.config/helix/languages.toml" << 'HELIX_LANG'
[[language]]
name = "python"
language-servers = ["pylsp", "ruff"]
formatter = { command = "ruff", args = ["format", "-"] }
auto-format = true

[language.debugger]
name = "debugpy"
transport = "stdio"
command = "python3"
args = ["-m", "debugpy.adapter"]

[[language.debugger.templates]]
name = "source"
request = "launch"
completion = [{ name = "entrypoint", completion = "filename", default = "." }]

[language.debugger.templates.args]
program = "{0}"
console = "integratedTerminal"

[language-server.pylsp]
command = "pylsp"

[language-server.pylsp.config.pylsp.plugins]
ruff = { enabled = false }
pyflakes = { enabled = false }
pycodestyle = { enabled = false }
mccabe = { enabled = false }
autopep8 = { enabled = false }
yapf = { enabled = false }
jedi_completion = { enabled = true, fuzzy = true }
jedi_hover = { enabled = true }
jedi_references = { enabled = true }
jedi_signature_help = { enabled = true }
jedi_symbols = { enabled = true }

[language-server.ruff]
command = "ruff"
args = ["server"]
HELIX_LANG

# ── Zellij config ──
info "Writing Zellij config..."
cat > "$HOME/.config/zellij/config.kdl" << 'ZELLIJ_CONF'
keybinds clear-defaults=true {
    locked {
        bind "Ctrl g" { SwitchToMode "normal"; }
    }
    pane {
        bind "left" { MoveFocus "left"; }
        bind "down" { MoveFocus "down"; }
        bind "up" { MoveFocus "up"; }
        bind "right" { MoveFocus "right"; }
        bind "c" { SwitchToMode "renamepane"; PaneNameInput 0; }
        bind "d" { NewPane "down"; SwitchToMode "normal"; }
        bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "normal"; }
        bind "f" { ToggleFocusFullscreen; SwitchToMode "normal"; }
        bind "h" { MoveFocus "left"; }
        bind "i" { TogglePanePinned; SwitchToMode "normal"; }
        bind "j" { MoveFocus "down"; }
        bind "k" { MoveFocus "up"; }
        bind "l" { MoveFocus "right"; }
        bind "n" { NewPane; SwitchToMode "normal"; }
        bind "p" { SwitchFocus; }
        bind "Ctrl p" { SwitchToMode "normal"; }
        bind "r" { NewPane "right"; SwitchToMode "normal"; }
        bind "s" { NewPane "stacked"; SwitchToMode "normal"; }
        bind "w" { ToggleFloatingPanes; SwitchToMode "normal"; }
        bind "z" { TogglePaneFrames; SwitchToMode "normal"; }
    }
    tab {
        bind "left" { GoToPreviousTab; }
        bind "down" { GoToNextTab; }
        bind "up" { GoToPreviousTab; }
        bind "right" { GoToNextTab; }
        bind "1" { GoToTab 1; SwitchToMode "normal"; }
        bind "2" { GoToTab 2; SwitchToMode "normal"; }
        bind "3" { GoToTab 3; SwitchToMode "normal"; }
        bind "4" { GoToTab 4; SwitchToMode "normal"; }
        bind "5" { GoToTab 5; SwitchToMode "normal"; }
        bind "6" { GoToTab 6; SwitchToMode "normal"; }
        bind "7" { GoToTab 7; SwitchToMode "normal"; }
        bind "8" { GoToTab 8; SwitchToMode "normal"; }
        bind "9" { GoToTab 9; SwitchToMode "normal"; }
        bind "[" { BreakPaneLeft; SwitchToMode "normal"; }
        bind "]" { BreakPaneRight; SwitchToMode "normal"; }
        bind "b" { BreakPane; SwitchToMode "normal"; }
        bind "h" { GoToPreviousTab; }
        bind "j" { GoToNextTab; }
        bind "k" { GoToPreviousTab; }
        bind "l" { GoToNextTab; }
        bind "n" { NewTab; SwitchToMode "normal"; }
        bind "r" { SwitchToMode "renametab"; TabNameInput 0; }
        bind "s" { ToggleActiveSyncTab; SwitchToMode "normal"; }
        bind "Ctrl t" { SwitchToMode "normal"; }
        bind "x" { CloseTab; SwitchToMode "normal"; }
        bind "tab" { ToggleTab; }
    }
    resize {
        bind "left" { Resize "Increase left"; }
        bind "down" { Resize "Increase down"; }
        bind "up" { Resize "Increase up"; }
        bind "right" { Resize "Increase right"; }
        bind "+" { Resize "Increase"; }
        bind "-" { Resize "Decrease"; }
        bind "=" { Resize "Increase"; }
        bind "H" { Resize "Decrease left"; }
        bind "J" { Resize "Decrease down"; }
        bind "K" { Resize "Decrease up"; }
        bind "L" { Resize "Decrease right"; }
        bind "h" { Resize "Increase left"; }
        bind "j" { Resize "Increase down"; }
        bind "k" { Resize "Increase up"; }
        bind "l" { Resize "Increase right"; }
        bind "Ctrl n" { SwitchToMode "normal"; }
    }
    move {
        bind "left" { MovePane "left"; }
        bind "down" { MovePane "down"; }
        bind "up" { MovePane "up"; }
        bind "right" { MovePane "right"; }
        bind "h" { MovePane "left"; }
        bind "Ctrl h" { SwitchToMode "normal"; }
        bind "j" { MovePane "down"; }
        bind "k" { MovePane "up"; }
        bind "l" { MovePane "right"; }
        bind "n" { MovePane; }
        bind "p" { MovePaneBackwards; }
        bind "tab" { MovePane; }
    }
    scroll {
        bind "e" { EditScrollback; SwitchToMode "normal"; }
        bind "s" { SwitchToMode "entersearch"; SearchInput 0; }
    }
    search {
        bind "c" { SearchToggleOption "CaseSensitivity"; }
        bind "n" { Search "down"; }
        bind "o" { SearchToggleOption "WholeWord"; }
        bind "p" { Search "up"; }
        bind "w" { SearchToggleOption "Wrap"; }
    }
    session {
        bind "a" {
            LaunchOrFocusPlugin "zellij:about" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "c" {
            LaunchOrFocusPlugin "configuration" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "Ctrl o" { SwitchToMode "normal"; }
        bind "p" {
            LaunchOrFocusPlugin "plugin-manager" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "s" {
            LaunchOrFocusPlugin "zellij:share" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "w" {
            LaunchOrFocusPlugin "session-manager" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
    }
    shared_except "locked" {
        bind "Alt left" { MoveFocusOrTab "left"; }
        bind "Alt down" { MoveFocus "down"; }
        bind "Alt up" { MoveFocus "up"; }
        bind "Alt right" { MoveFocusOrTab "right"; }
        bind "Alt +" { Resize "Increase"; }
        bind "Alt -" { Resize "Decrease"; }
        bind "Alt =" { Resize "Increase"; }
        bind "Alt [" { PreviousSwapLayout; }
        bind "Alt ]" { NextSwapLayout; }
        bind "Alt f" { ToggleFloatingPanes; }
        bind "Alt t" { NewPane "stacked"; }
        bind "Ctrl g" { SwitchToMode "locked"; }
        bind "Alt h" { MoveFocusOrTab "left"; }
        bind "Alt i" { MoveTab "left"; }
        bind "Alt j" { MoveFocus "down"; }
        bind "Alt k" { MoveFocus "up"; }
        bind "Alt l" { MoveFocusOrTab "right"; }
        bind "Alt n" { NewPane; }
        bind "Alt o" { MoveTab "right"; }
        bind "Alt p" { TogglePaneInGroup; }
        bind "Alt Shift p" { ToggleGroupMarking; }
        bind "Ctrl q" { Quit; }
    }
    shared_except "locked" "move" {
        bind "Ctrl h" { SwitchToMode "move"; }
    }
    shared_except "locked" "session" {
        bind "Ctrl o" { SwitchToMode "session"; }
    }
    shared_except "locked" "scroll" "search" "tmux" {
        bind "Ctrl b" { SwitchToMode "tmux"; }
    }
    shared_except "locked" "scroll" "search" {
        bind "Ctrl s" { SwitchToMode "scroll"; }
    }
    shared_except "locked" "tab" {
        bind "Ctrl t" { SwitchToMode "tab"; }
    }
    shared_except "locked" "pane" {
        bind "Ctrl p" { SwitchToMode "pane"; }
    }
    shared_except "locked" "resize" {
        bind "Ctrl n" { SwitchToMode "resize"; }
    }
    shared_except "normal" "locked" "entersearch" {
        bind "enter" { SwitchToMode "normal"; }
    }
    shared_except "normal" "locked" "entersearch" "renametab" "renamepane" {
        bind "esc" { SwitchToMode "normal"; }
    }
    shared_among "pane" "tmux" {
        bind "x" { CloseFocus; SwitchToMode "normal"; }
    }
    shared_among "scroll" "search" {
        bind "PageDown" { PageScrollDown; }
        bind "PageUp" { PageScrollUp; }
        bind "left" { PageScrollUp; }
        bind "down" { ScrollDown; }
        bind "up" { ScrollUp; }
        bind "right" { PageScrollDown; }
        bind "Ctrl b" { PageScrollUp; }
        bind "Ctrl c" { ScrollToBottom; SwitchToMode "normal"; }
        bind "d" { HalfPageScrollDown; }
        bind "Ctrl f" { PageScrollDown; }
        bind "h" { PageScrollUp; }
        bind "j" { ScrollDown; }
        bind "k" { ScrollUp; }
        bind "l" { PageScrollDown; }
        bind "Ctrl s" { SwitchToMode "normal"; }
        bind "u" { HalfPageScrollUp; }
    }
    entersearch {
        bind "Ctrl c" { SwitchToMode "scroll"; }
        bind "esc" { SwitchToMode "scroll"; }
        bind "enter" { SwitchToMode "search"; }
    }
    renametab {
        bind "esc" { UndoRenameTab; SwitchToMode "tab"; }
    }
    shared_among "renametab" "renamepane" {
        bind "Ctrl c" { SwitchToMode "normal"; }
    }
    renamepane {
        bind "esc" { UndoRenamePane; SwitchToMode "pane"; }
    }
    shared_among "session" "tmux" {
        bind "d" { Detach; }
    }
    tmux {
        bind "left" { MoveFocus "left"; SwitchToMode "normal"; }
        bind "down" { MoveFocus "down"; SwitchToMode "normal"; }
        bind "up" { MoveFocus "up"; SwitchToMode "normal"; }
        bind "right" { MoveFocus "right"; SwitchToMode "normal"; }
        bind "space" { NextSwapLayout; }
        bind "\"" { NewPane "down"; SwitchToMode "normal"; }
        bind "%" { NewPane "right"; SwitchToMode "normal"; }
        bind "," { SwitchToMode "renametab"; }
        bind "[" { SwitchToMode "scroll"; }
        bind "Ctrl b" { Write 2; SwitchToMode "normal"; }
        bind "c" { NewTab; SwitchToMode "normal"; }
        bind "h" { MoveFocus "left"; SwitchToMode "normal"; }
        bind "j" { MoveFocus "down"; SwitchToMode "normal"; }
        bind "k" { MoveFocus "up"; SwitchToMode "normal"; }
        bind "l" { MoveFocus "right"; SwitchToMode "normal"; }
        bind "n" { GoToNextTab; SwitchToMode "normal"; }
        bind "o" { FocusNextPane; }
        bind "p" { GoToPreviousTab; SwitchToMode "normal"; }
        bind "z" { ToggleFocusFullscreen; SwitchToMode "normal"; }
    }
}

plugins {
    about location="zellij:about"
    compact-bar location="zellij:compact-bar"
    configuration location="zellij:configuration"
    filepicker location="zellij:strider" {
        cwd "/"
    }
    plugin-manager location="zellij:plugin-manager"
    session-manager location="zellij:session-manager"
    status-bar location="zellij:status-bar"
    strider location="zellij:strider"
    tab-bar location="zellij:tab-bar"
    welcome-screen location="zellij:session-manager" {
        welcome_screen true
    }
}

load_plugins {
}

theme "catppuccin-mocha"
pane_frames true
default_shell "zsh"
ZELLIJ_CONF

cat > "$HOME/.config/zellij/layouts/ide.kdl" << 'ZELLIJ_LAYOUT'
layout {
    pane size=1 borderless=true {
        plugin location="zellij:tab-bar"
    }

    pane split_direction="vertical" {
        pane size="20%" {
            command "yazi"
        }
        pane split_direction="horizontal" {
            pane {
                command "helix"
                focus true
            }
            pane stacked=true size="30%" {
                pane
            }
        }
    }

    pane size=2 borderless=true {
        plugin location="zellij:status-bar"
    }
}
ZELLIJ_LAYOUT

# ── Yazi config ──
info "Writing Yazi config..."
cat > "$HOME/.config/yazi/yazi.toml" << YAZI_CONF
[mgr]
ratio        = [0, 1, 0]
show_hidden  = false
show_symlink = true
sort_by      = "natural"
mouse_events = [ "click", "scroll" ]

[preview]
max_width  = 0
max_height = 0

[opener]
edit = [
    { run = '\$HOME/.local/bin/hx-open %s', orphan = true, desc = "Open in Helix", for = "unix" }
]

[open]
rules = [
    { url = "*", use = "edit" },
]
YAZI_CONF

cat > "$HOME/.config/yazi/keymap.toml" << YAZI_KEYS
[[mgr.prepend_keymap]]
on   = "<Enter>"
run  = "open"
desc = "Open file / Enter dir"

[[mgr.prepend_keymap]]
on   = "l"
run  = "open"
desc = "Open file / Enter dir"

[[mgr.prepend_keymap]]
on   = "o"
run  = "shell --orphan -- \$HOME/.local/bin/hx-open %h"
desc = "Open in Helix"

[[mgr.prepend_keymap]]
on   = "t"
run  = "shell --orphan -- \$HOME/.local/bin/term-cd %d"
desc = "cd terminal to current dir"

[[mgr.prepend_keymap]]
on   = "["
run  = "back"
desc = "Go back"

[[mgr.prepend_keymap]]
on   = "]"
run  = "forward"
desc = "Go forward"

[[mgr.prepend_keymap]]
on   = "<Backspace>"
run  = "back"
desc = "Go back"

[[mgr.prepend_keymap]]
on   = "H"
run  = "back"
desc = "Go back"

[[mgr.prepend_keymap]]
on   = "L"
run  = "forward"
desc = "Go forward"
YAZI_KEYS

# ── Scripts ──
info "Writing scripts..."

cat > "$HOME/.local/bin/hx-open" << 'SCRIPT'
#!/bin/zsh
[ -z "$1" ] && exit 1
abs="$(realpath "$1" 2>/dev/null || echo "$1")"

zellij action move-focus right
zellij action move-focus up

if pgrep -x helix > /dev/null 2>&1; then
    zellij action write-chars $'\x1b:open '"$abs"$'\r'
else
    zellij action write-chars "helix '${abs}'"$'\r'
fi
SCRIPT

cat > "$HOME/.local/bin/hx-run" << 'SCRIPT'
#!/bin/zsh
[ -z "$1" ] && exit 1
abs="$(realpath "$1" 2>/dev/null || echo "$1")"
project_dir="$(pwd)"

if [ -f ".ide/run.sh" ]; then
    cmd="cd '${project_dir}' && zsh .ide/run.sh"
else
    ext="${abs##*.}"
    case "$ext" in
        py)  cmd="cd '${project_dir}' && python3 '${abs}'" ;;
        sh)  cmd="cd '${project_dir}' && zsh '${abs}'" ;;
        rs)  cmd="cd '${project_dir}' && cargo run" ;;
        js)  cmd="cd '${project_dir}' && node '${abs}'" ;;
        ts)  cmd="cd '${project_dir}' && npx ts-node '${abs}'" ;;
        go)  cmd="cd '${project_dir}' && go run '${abs}'" ;;
        *)   cmd="cd '${project_dir}' && '${abs}'" ;;
    esac
fi

zellij action move-focus down
zellij action write-chars "$cmd"$'\r'
SCRIPT

cat > "$HOME/.local/bin/hx-debug" << 'SCRIPT'
#!/bin/zsh
[ -z "$1" ] && exit 1
abs="$(realpath "$1" 2>/dev/null || echo "$1")"
project_dir="$(pwd)"

if [ -f ".ide/debug.sh" ]; then
    cmd="cd '${project_dir}' && zsh .ide/debug.sh"
else
    ext="${abs##*.}"
    case "$ext" in
        py)  cmd="cd '${project_dir}' && python3 -m pdb '${abs}'" ;;
        js)  cmd="cd '${project_dir}' && node --inspect-brk '${abs}'" ;;
        *)   cmd="cd '${project_dir}' && '${abs}'" ;;
    esac
fi

zellij action move-focus down
zellij action write-chars "$cmd"$'\r'
SCRIPT

cat > "$HOME/.local/bin/term-cd" << 'SCRIPT'
#!/bin/zsh
dir="${1:-$(pwd)}"

zellij action move-focus right
zellij action move-focus down
zellij action write-chars "cd '${dir}'"$'\r'
SCRIPT

cat > "$HOME/.local/bin/ide" << 'SCRIPT'
#!/bin/zsh
cd "${1:-.}" && zellij --layout ide
SCRIPT

chmod +x "$HOME/.local/bin"/{hx-open,hx-run,hx-debug,term-cd,ide}

echo
info "Installation complete!"
echo
echo "Usage:  ide [directory]"
echo
echo "Hotkeys (Helix):"
echo "  Ctrl+R   Run program (.ide/run.sh or current file)"
echo "  F5       Debug (.ide/debug.sh or current file)"
echo "  Ctrl+S   Save"
echo "  Ctrl+Z   Undo"
echo "  Ctrl+Y   Redo"
echo "  Ctrl+X   Cut line"
echo "  Ctrl+C   Copy line"
echo "  Ctrl+V   Paste"
echo "  Ctrl+A   Select all"
echo "  Ctrl+F   Search"
echo "  Tab      Next buffer"
echo "  Shift+Tab Previous buffer"
echo "  Ctrl+W   Close buffer"
echo
echo "Hotkeys (Zellij):"
echo "  Alt+T    New stacked terminal"
echo "  Alt+H/L  Move focus left/right"
echo "  Alt+J/K  Move focus down/up"
echo "  Ctrl+P   Pane mode"
echo "  Ctrl+T   Tab mode"
echo
echo "Yazi:"
echo "  Enter/l  Open file in Helix"
echo "  t        cd terminal to current dir"
