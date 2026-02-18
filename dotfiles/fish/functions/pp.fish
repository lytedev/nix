function pp
    if test (count $argv) -gt 0
        while true; ping -O -i 1 -w 5 -c 10000000 $argv; sleep 1; end
    else
        while true; ping -O -i 1 -w 5 -c 10000000 1.1.1.1; sleep 1; end
    end
end
