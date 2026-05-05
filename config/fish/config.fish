# ── Conda (macOS only) ────────────────────────────────────────────────────────
# Guarded because the path is macOS-specific and won't exist on Linux.
if test -f /Users/brian/opt/anaconda3/bin/conda
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    eval /Users/brian/opt/anaconda3/bin/conda "shell.fish" "hook" $argv | source
    # <<< conda initialize <<<
end

# ── Abbreviations ─────────────────────────────────────────────────────────────
# Abbreviations expand in-place when you press space or enter,
# so you always see the full command before it runs.

# Git
abbr -a gs  git status
abbr -a gl  git lg
abbr -a gp  git push
abbr -a gpl git pull
abbr -a gc  git commit
abbr -a gco git checkout
abbr -a gd  git diff
abbr -a ga  git add

# Navigation
abbr -a ..  cd ..
abbr -a ... cd ../..
