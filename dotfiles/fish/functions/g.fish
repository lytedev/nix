function g --wraps=jj --description "Shorthand for jj (or git status with no args)"
	if test (count $argv) -gt 0
		jj $argv
	else
		jj status
	end
end
