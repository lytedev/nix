function c --description "Jump to NICE_HOME and optionally into a subdirectory"
	if count $argv > /dev/null
		cd $NICE_HOME && d $argv
	else
		d $NICE_HOME
	end
end
