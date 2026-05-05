#!/usr/bin/env bash
# setup.sh -- create symlinks from dotfiles repo to their expected locations
# Safe to run multiple times; backs up any existing files before replacing them.

set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${GREEN}[ok]${NC} $1"; }
warn()   { echo -e "${YELLOW}[warn]${NC} $1"; }
skip()   { echo -e "${YELLOW}[skip]${NC} $1"; }
backup() { echo -e "${YELLOW}[backup]${NC} $1"; }

# Create a symlink. If target already exists and is not already the correct
# symlink, back it up first.
link() {
    local src="$1"   # file in dotfiles repo (absolute)
    local dst="$2"   # destination path (where the symlink should live)

    if [ ! -e "$src" ]; then
        skip "$src does not exist, skipping"
        return
    fi

    # Already the correct symlink -- nothing to do
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        log "$dst already linked"
        return
    fi

    # Something else exists at dst -- back it up
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        backup "moved existing $dst to $BACKUP_DIR/"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dst")"

    ln -s "$src" "$dst"
    log "linked $dst -> $src"
}

echo ""
echo "Setting up dotfiles from $DOTFILES"
echo "Machine: $(uname -s) / $(hostname)"
echo ""

# ── Claude ────────────────────────────────────────────────────────────────────
# Link agents dir and settings.json individually so ~/.claude/ itself
# (which contains machine-specific state) is never replaced wholesale.

echo "── Claude ──"
mkdir -p "$HOME/.claude"
link "$DOTFILES/claude/agents"        "$HOME/.claude/agents"
link "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
echo ""

# ── Git ───────────────────────────────────────────────────────────────────────
echo "── Git ──"
link "$DOTFILES/gitconfig"        "$HOME/.gitconfig"
link "$DOTFILES/gitignore_global" "$HOME/.gitignore_global"
echo ""

# ── Nano ──────────────────────────────────────────────────────────────────────
echo "── Nano ──"
link "$DOTFILES/nanorc" "$HOME/.nanorc"
echo ""

# ── Fish ──────────────────────────────────────────────────────────────────────
echo "── Fish ──"
if command -v fish &>/dev/null; then
    mkdir -p "$HOME/.config/fish/conf.d"
    link "$DOTFILES/config/fish/config.fish"         "$HOME/.config/fish/config.fish"
    link "$DOTFILES/config/fish/conf.d/atuin.env.fish" "$HOME/.config/fish/conf.d/atuin.env.fish"
    warn "config.fish contains macOS-specific conda path -- review on Linux"
else
    skip "fish not installed, skipping fish config"
fi
echo ""

# ── Atuin ─────────────────────────────────────────────────────────────────────
echo "── Atuin ──"
if command -v atuin &>/dev/null; then
    mkdir -p "$HOME/.config/atuin"
    link "$DOTFILES/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
else
    skip "atuin not installed, skipping atuin config"
fi
echo ""

# ── Micro ─────────────────────────────────────────────────────────────────────
echo "── Micro ──"
if command -v micro &>/dev/null; then
    mkdir -p "$HOME/.config/micro"
    link "$DOTFILES/config/micro/bindings.json" "$HOME/.config/micro/bindings.json"
else
    skip "micro not installed, skipping micro config"
fi
echo ""

# ── WTF Terminal Dashboard ────────────────────────────────────────────────────
echo "── WTF ──"
if command -v wtfutil &>/dev/null || command -v wtf &>/dev/null; then
    mkdir -p "$HOME/.config/wtf"
    link "$DOTFILES/config/wtf/config.yml" "$HOME/.config/wtf/config.yml"
    warn "wtf config.yml may contain macOS-specific widget paths -- review on Linux"
else
    skip "wtf not installed, skipping wtf config"
fi
echo ""

echo "Done. If anything was backed up, find it in $BACKUP_DIR"
echo ""
