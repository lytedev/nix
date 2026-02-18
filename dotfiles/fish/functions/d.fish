function d --description "Quickly jump to NICE_HOME (or given relative or absolute path) and list files."
	if count $argv > /dev/null
		cd $argv
	else
		cd $NICE_HOME
	end
	la
end
