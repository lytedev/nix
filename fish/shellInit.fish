# paths
if not set --query NICE_HOME
	set --export --universal NICE_HOME $HOME

	# if HOME ends with a dir called .home, assume that NICE_HOME is HOME's parent dir
	test (basename $HOME) = .home \
		&& set --export --universal NICE_HOME (realpath $HOME/..)
end

set --export --universal XDG_CONFIG_HOME $HOME/.config
set --export --universal XDG_CACHE_HOME $HOME/.cache
set --export --universal XDG_DATA_HOME $HOME/.local/share
set --export --universal XDG_STATE_HOME $HOME/.local/state
set --export --universal XDG_DESKTOP_DIR $HOME/desktop
set --export --universal XDG_PUBLICSHARE_DIR $HOME/public
set --export --universal XDG_TEMPLATES_DIR $HOME/templates
set --export --universal XDG_DOCUMENTS_DIR $NICE_HOME/doc
set --export --universal XDG_DOWNLOAD_DIR $NICE_HOME/dl
set --export --universal XDG_MUSIC_DIR $NICE_HOME/music
set --export --universal XDG_PICTURES_DIR $NICE_HOME/img
set --export --universal XDG_VIDEOS_DIR $NICE_HOME/video
set --export --universal XDG_GAMES_DIR $NICE_HOME/games

set --export --universal NOTES_PATH $NICE_HOME/doc/notes
set --export --universal SCROTS_PATH $NICE_HOME/img/scrots
set --export --universal USER_LOGS_PATH $NICE_HOME/doc/logs

set --export --universal CDPATH $NICE_HOME

# vars
set --export --universal LS_COLORS 'ow=01;36;40'
set --export --universal EXA_COLORS '*=0'

set --export --universal ERL_AFLAGS "-kernel shell_history enabled -kernel shell_history_file_bytes 1024000"

set --export --universal BROWSER firefox

set --export --universal SOPS_AGE_KEY_FILE "$XDG_CONFIG_HOME/sops/age/keys.txt"

set --export --universal SKIM_ALT_C_COMMAND "fd --hidden --type directory"
set --export --universal SKIM_CTRL_T_COMMAND "fd --hidden"

# colors
set -U fish_color_normal normal # default color
set -U fish_color_command white # base command being run (>ls< -la)
set -U fish_color_param white # command's parameters
set -U fish_color_end green # command delimiter/separators (; and &)
set -U fish_color_error red # color of errors
set -U fish_color_escape yellow # color of escape codes (\n, \x2d, etc.)
set -U fish_color_operator blue # expansion operators (~, *)
set -U fish_color_quote yellow
set -U fish_color_redirection blue # redirection operators (|, >, etc.)
set -U fish_color_cancel 333 brblack # sigint at prompt (^C)
set -U fish_color_autosuggestion 666 brblack # as-you-type suggestions
set -U fish_color_match blue # matching parens and the like
set -U fish_color_search_match white\x1e\x2d\x2dbackground\x3d333 # selected pager item
set -U fish_color_selection blue # vi mode visual selection (only fg)
set -U fish_color_valid_path yellow # if an argument is a valid path (only -u?)
set -U fish_color_comment 666 brblack # comments like this one!

set -U fish_pager_color_completion white # main color for pager
set -U fish_pager_color_description magenta # color for meta description
set -U fish_pager_color_prefix blue # the string being completed
set -U fish_pager_color_progress white\x1e\x2d\x2dbackground\x3d333 # status indicator at the bottom
# set -U fish_pager_color_secondary \x2d\x2dbackground\x3d181818 # alternating rows

function has_command --wraps=command --description "Exits non-zero if the given command cannot be found"
	command --quiet --search $argv[1]
end

if has_command rtx
	rtx activate fish | source
end

for dir in ~/.cargo/bin ~/.nimble/bin ~/.local/bin
	fish_add_path $dir
end
