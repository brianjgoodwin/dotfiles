#!/usr/bin/env bash
# audit-remote.sh -- compare remote server dotfiles against this repo
# Usage: ./audit-remote.sh user@ip
#
# For each tracked file:
#   - missing on server  → offer to skip or note for setup.sh to create
#   - matches repo       → report clean
#   - differs            → show summary, offer to view diff, then choose:
#                          (r) keep repo version  (s) keep server version  (k) skip

set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()    { echo -e "${GREEN}[match]${NC} $1"; }
warn()   { echo -e "${YELLOW}[differs]${NC} $1"; }
missing(){ echo -e "${CYAN}[missing]${NC} $1"; }
info()   { echo -e "${BOLD}$1${NC}"; }

if [ -z "$1" ]; then
    echo "Usage: $0 user@ip"
    exit 1
fi

REMOTE="$1"

# Verify SSH connection before proceeding
echo ""
info "Connecting to $REMOTE..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE" "echo ok" &>/dev/null; then
    echo -e "${RED}[error]${NC} Cannot connect to $REMOTE -- check your SSH config and try again"
    exit 1
fi
echo -e "${GREEN}Connected.${NC}"
echo ""

# ── File map: local repo path → remote absolute path ─────────────────────────
# Format: "local_relative_path|remote_absolute_path"
FILES=(
    "claude/agents/code-reviewer.md|~/.claude/agents/code-reviewer.md"
    "claude/agents/kirby-consultant.md|~/.claude/agents/kirby-consultant.md"
    "claude/agents/project-manager.md|~/.claude/agents/project-manager.md"
    "claude/agents/project-planner.md|~/.claude/agents/project-planner.md"
    "claude/agents/security-code-reviewer.md|~/.claude/agents/security-code-reviewer.md"
    "claude/agents/user-story-writer.md|~/.claude/agents/user-story-writer.md"
    "claude/settings.json|~/.claude/settings.json"
    "gitconfig|~/.gitconfig"
    "nanorc|~/.nanorc"
    "config/fish/config.fish|~/.config/fish/config.fish"
    "config/fish/conf.d/atuin.env.fish|~/.config/fish/conf.d/atuin.env.fish"
    "config/atuin/config.toml|~/.config/atuin/config.toml"
    "config/micro/bindings.json|~/.config/micro/bindings.json"
    "config/wtf/config.yml|~/.config/wtf/config.yml"
)

# Track outcomes for end summary
MATCHED=()
DIFFERED=()
MISSING=()
PULLED=()   # server version pulled into repo
SKIPPED=()

# ── Audit loop ────────────────────────────────────────────────────────────────
for entry in "${FILES[@]}"; do
    local_rel="${entry%%|*}"
    remote_path="${entry##*|}"
    local_abs="$DOTFILES/$local_rel"

    # Check if file exists on remote
    exists=$(ssh "$REMOTE" "[ -f $remote_path ] && echo yes || echo no")

    if [ "$exists" = "no" ]; then
        missing "$local_rel (not present on server)"
        MISSING+=("$local_rel")
        continue
    fi

    # Fetch remote content and diff against local
    remote_content=$(ssh "$REMOTE" "cat $remote_path")
    local_content=$(cat "$local_abs")

    if [ "$remote_content" = "$local_content" ]; then
        log "$local_rel"
        MATCHED+=("$local_rel")
        continue
    fi

    # Files differ -- show summary
    diff_stat=$(diff <(echo "$local_content") <(echo "$remote_content") | grep -c "^[<>]" || true)
    warn "$local_rel  ($diff_stat changed lines)"
    DIFFERED+=("$local_rel")

    # Offer to view diff
    echo -n "   View diff? [y/n] "
    read -r view_diff
    if [[ "$view_diff" =~ ^[Yy]$ ]]; then
        echo ""
        diff --color=always \
            --label "repo ($local_rel)" \
            --label "server ($remote_path)" \
            <(echo "$local_content") \
            <(echo "$remote_content") || true
        echo ""
    fi

    # Decision
    echo    "   What do you want to do?"
    echo    "   (r) keep repo version -- server will get this on next setup.sh run"
    echo    "   (s) keep server version -- pull into repo now"
    echo    "   (k) skip -- decide later"
    echo -n "   Choice [r/s/k]: "
    read -r choice

    case "$choice" in
        r|R)
            echo -e "   ${GREEN}Repo version will win on next setup.sh run.${NC}"
            ;;
        s|S)
            # Pull server version into repo
            ssh "$REMOTE" "cat $remote_path" > "$local_abs"
            git -C "$DOTFILES" add "$local_abs"
            echo -e "   ${GREEN}Server version pulled into repo. Staged for commit.${NC}"
            PULLED+=("$local_rel")
            ;;
        *)
            echo -e "   ${YELLOW}Skipped.${NC}"
            SKIPPED+=("$local_rel")
            ;;
    esac

    echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
info "── Audit complete ──────────────────────────────────"
echo ""

[ ${#MATCHED[@]}  -gt 0 ] && echo -e "${GREEN}Matched (${#MATCHED[@]}):${NC}  ${MATCHED[*]}"
[ ${#MISSING[@]}  -gt 0 ] && echo -e "${CYAN}Missing on server (${#MISSING[@]}):${NC}  ${MISSING[*]}"
[ ${#DIFFERED[@]} -gt 0 ] && echo -e "${YELLOW}Differed (${#DIFFERED[@]}):${NC}  ${DIFFERED[*]}"
[ ${#PULLED[@]}   -gt 0 ] && echo -e "${GREEN}Pulled from server (${#PULLED[@]}):${NC}  ${PULLED[*]}"
[ ${#SKIPPED[@]}  -gt 0 ] && echo -e "${YELLOW}Skipped (${#SKIPPED[@]}):${NC}  ${SKIPPED[*]}"

echo ""

# Offer to commit if anything was pulled
if [ ${#PULLED[@]} -gt 0 ]; then
    echo -n "Commit pulled changes now? [y/n] "
    read -r do_commit
    if [[ "$do_commit" =~ ^[Yy]$ ]]; then
        pulled_list=$(IFS=", "; echo "${PULLED[*]}")
        git -C "$DOTFILES" commit -m "$(cat <<EOF
Pull server versions of differing dotfiles

Files updated from $REMOTE: $pulled_list

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
        echo -e "${GREEN}Committed.${NC}"
    else
        echo "Changes staged but not committed. Run 'git commit' when ready."
    fi
fi

# Remind about missing files
if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "Missing files will be created on the server when you run:"
    echo "  ./setup.sh"
    echo "from the cloned repo on the server."
fi

echo ""
