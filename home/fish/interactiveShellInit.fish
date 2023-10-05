# prompt
function get_hostname
	if test (uname) = Linux || test (uname) = Darwin
		has_command hostname && hostname | cut -d. -f1 || cat /etc/hostname
	else
		# assume bsd
		hostname | head -n 1 | cut -d. -f1
	end
end

function fish_greeting
	_prompt_prefix
	printf "%s\n" (date)
end

function preprocess_pwd
	test (pwd) = / && echo "/" && return 1
	test (pwd) = $NICE_HOME && echo "~" && return 0
	pwd \
		| cut -c2- \
		| gawk '{n=split($0,p,"/");for(i=1;i<=n;i++){if(i==n){printf "/%s",p[i]}else{printf "/%.3s",p[i]}}}'
end

function _maybe_sudo_prefix
	if set -q SUDO_USER
		set_color -b yellow black
		printf " SUDO "
		set_color -b normal normal
		printf " "
	end
end

function _maybe_aws_profile
	if set -q AWS_PROFILE && test $AWS_PROFILE = prd
		printf " "
		set_color -b yellow black
		printf " AWS_PROFILE=prd "
		set_color -b normal normal
	end
end

function _user_and_host
	if test $argv[1] -eq 0
		set_color -b normal blue
	else
		set_color -b normal red
	end
	printf "%s@%s" $USER (get_hostname)
end

function _cur_work_dir
	set_color -b normal magenta
	printf " %s" (preprocess_pwd)
end

function _last_cmd_duration
	set_color -b normal green
	set -q CMD_DURATION && printf " %dms" $CMD_DURATION
end

function _maybe_jobs_summary
	if jobs -q
		set_color -b normal cyan
		printf " &%d" (jobs -p | wc -l)
	end
end

function _user_prompt
	printf "\n"
	set_color brblack
	if test (id -u) -eq 0
		printf '# '
	else
		printf '$ '
	end
	set_color -b normal normal
end

function _maybe_git_summary
	set_color -b normal yellow
	set cur_sha (git rev-parse --short HEAD 2>/dev/null)
	if test $status = 0
		set num_changes (git status --porcelain | wc -l | string trim)
		if test $num_changes = 0
			set num_changes "✔"
		else
			set num_changes "+$num_changes"
		end
		printf " %s %s %s" (git branch --show-current) $cur_sha $num_changes
	end
end

function _prompt_marker
	# printf "%b133;A%b" "\x1b\x5d" "\x1b\x5c"
end

function _prompt_continuation_marker
	# printf "%b133;A;k=s%b" "\x1b\x5d" "\x1b\x5c"
end

function cmd_marker --on-variable _
	# printf "%b133;C%b" "\x1b\x5d" "\x1b\x5c"
end

function _prompt_prefix
	set_color -b normal brblack
	printf "# "
end

function fish_prompt
	set last_cmd_status $status
	_prompt_marker
	_prompt_prefix
	_maybe_sudo_prefix
	_user_and_host $last_cmd_status
	_cur_work_dir
	_maybe_git_summary
	_maybe_aws_profile
	_last_cmd_duration
	_maybe_jobs_summary
	_user_prompt
end

function fish_mode_prompt; end
function fish_right_prompt; end

# key bindings
fish_vi_key_bindings

set --universal fish_cursor_default block
set --universal fish_cursor_insert line
set --universal fish_cursor_block block
fish_vi_cursor
set --universal fish_vi_force_cursor 1

bind --mode insert --sets-mode default jk repaint
bind --mode insert --sets-mode default jK repaint
bind --mode insert --sets-mode default Jk repaint
bind --mode insert --sets-mode default JK repaint
bind --mode insert --sets-mode default jj repaint
bind --mode insert --sets-mode default jJ repaint
bind --mode insert --sets-mode default Jj repaint
bind --mode insert --sets-mode default JJ repaint

bind -M insert \cg skim-cd-widget

bind -M insert \cp up-or-search
bind -M insert \cn down-or-search
bind -M insert \ce end-of-line
bind -M insert \ca beginning-of-line

bind -M insert \cv edit_command_buffer
bind -M default \cv edit_command_buffer

test $PWD = $HOME && begin
	cd $NICE_HOME || cd
end
