function lag --wraps=g --description "List all files then run g (jj/git)"
	lA
	g $argv
end
