SHELL:=bash


trivial:
	dune build examples/trivial
#	dune exec examples/trivial/trivial.exe
	MEMTRACE=trivial.ctf MEMTRACE_RATE=1.0 dune exec -- examples/trivial/trivial.exe
	dune exec -- bin/graph_mem.exe trivial.ctf | gnuplot -p -e "plot '-'" 
	dune exec -- bin/dump.exe ctf trivial.ctf > trivial.ctf.dump
	dune exec -- bin/translate_with_promote_lookahead.exe trivial.ctf trivial.lookahead
	dune exec -- bin/dump.exe lookahead trivial.lookahead > trivial.lookahead.dump



old-working:
	dune build bin/
	echo Plotting allocs for original queens.ctf
	cp ctf/queens.ctf .
	dune exec -- bin/graph_mem.exe queens.ctf | gnuplot -p -e "plot '-'" 
	echo Converting to queens.lookahead \(also .dump\)
	dune exec -- bin/translate_with_promote_lookahead.exe queens.ctf queens.lookahead
	dune exec -- bin/dump.exe lookahead queens.lookahead > queens.lookahead.dump
	echo Replaying lookahead, memtrace results in replay.ctf
	MEMTRACE=replay.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay_raw_v3.exe queens.lookahead 40063
	echo Plotting allocs for replay.ctf
	dune exec -- bin/graph_mem.exe replay.ctf | gnuplot -p -e "plot '-'" 
	dune exec -- bin/translate_with_promote_lookahead.exe replay.ctf replay.lookahead
	dune exec -- bin/dump.exe lookahead replay.lookahead > replay.lookahead.dump

