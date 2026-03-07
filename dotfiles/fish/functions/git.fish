function git --wraps=git --description 'Nudge toward jj when available'
    if command -q jj; and test -d .jj
        echo "use jj (jujutsu) instead of git, silly! (override with 'command git ...')" >&2
        return 1
    end
    command git $argv
end
