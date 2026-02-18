function ltl --description "Print the path of the most recently modified file in a directory"
	set d $argv[1] .
	set -l l ""
	for f in $d[1]/*
		if test -z $l; set l $f; continue; end
		if command test $f -nt $l; and test ! -d $f
			set l $f
		end
	end
	echo $l
end
