SHELL:=bash

graph_mem:
	dune build bin/
#	dune exec -- bin/graph_mem.exe queens.ctf | gnuplot -p -e "plot '-'"
#	MEMTRACE=replay_queens.v3.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay_raw_v3.exe queens.raw_lookahead 40063 # replay raw and record memtrace
#	dune exec -- bin/graph_mem.exe replay_queens.v3.ctf | gnuplot -p -e "plot '-'" 
#	dune exec -- bin/translate_with_promote_lookahead.exe replay_queens.v3.ctf replay_queens.v3.lookahead # convert replay_queens.v3.ctf to lookahead
#	dune exec -- bin/dump.exe lookahead replay_queens.v3.lookahead > replay_queens.v3.lookahead.dump
	dune exec -- bin/check_lookahead.exe replay_queens.v3.lookahead
#	dune exec -- bin/dump.exe ctf replay_queens.v3.ctf > replay_queens.v3.ctf.dump


view-lookahead:
	dune build bin/
	dune exec -- bin/translate_with_promote_lookahead.exe queens.ctf queens.lookahead
	dune exec -- bin/dump.exe lookahead queens.lookahead > queens.lookahead.dump

check-lookahead:
	dune build bin/
	dune exec -- bin/check_lookahead.exe queens.lookahead

dump:
	dune build bin/
	dune exec -- bin/dump.exe ctf queens.ctf > queens.ctf.dump
	dune exec -- bin/dump.exe raw queens.raw > queens.raw.dump # FIXME only one line output
	grep --invert-match '^P' queens.ctf.dump > tmp.txt # like queens.ctf.dump, but no promotes
	diff -q tmp.txt queens.raw.dump # should be identical, except for promotes
	dune exec -- bin/dump.exe lookahead queens.raw_lookahead > queens_lookahead.dump
	diff -q queens.raw.dump queens_lookahead.dump # should be identical
	dune exec -- bin/dump.exe ctf replay_queens.v3.ctf > replay_queens.v3.ctf.dump
	grep --invert-match '^P' replay_queens.v3.ctf.dump > tmp2.txt # queens.raw.dump obj_id 0 corresponds to tmp2.txt obj_id 40070; 40063 to 80133 (- 80133 40063) = 40070; so at least the pattern of allocations in replay_queens.v3.ctf is as queens.ctf, modulo initial 40069 allocs


translate-with-promote-lookahead:
	dune build bin/translate_with_promote_lookahead.exe
	OCAMLRUNPARAM=b dune exec -- bin/translate_with_promote_lookahead.exe queens.ctf queens.raw_lookahead
	dune build bin/replay_raw_v3.exe
	MEMTRACE=replay_queens.v3.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay_raw_v3.exe queens.raw_lookahead 40063 # replay raw and record memtrace
# now check memtrace-viewer for replay_queens.v3.ctf, and compare with queens


all-replay-queens_v2:
	dune exec -- bin/translate_memtrace_to_raw.exe queens.ctf queens.raw # translate to raw; print max obj_id as side effect
	MEMTRACE=replay_queens.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay_raw_v2.exe queens.raw 40063 # replay raw and record memtrace
	dune exec -- bin/alloc_summary.exe queens.ctf
	dune exec -- bin/alloc_summary.exe replay_queens.ctf
# now check memtrace-viewer for replay_queens, and compare with queens


all-replay-queens:
	dune exec -- bin/translate_memtrace_to_raw.exe queens.ctf queens.raw # translate to raw
	MEMTRACE=replay_queens.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay_raw.exe queens.raw # replay raw and record memtrace
	dune exec -- bin/alloc_summary.exe queens.ctf
	dune exec -- bin/alloc_summary.exe replay_queens.ctf
# now check memtrace-viewer for replay_queens, and compare with queens


all-summarize:
	dune build bin/alloc_summary.exe
	dune exec -- bin/alloc_summary.exe ctf/js_of_ocaml-queue.ctf
	dune exec -- bin/alloc_summary.exe ./replay_raw.ctf

all-replay_raw_queue: 
	dune build examples/memtrace_custom_analysis/lifetimes_of_objects.exe
	dune exec -- bin/translate_memtrace_to_raw.exe ctf/js_of_ocaml-queue.ctf js_of_ocaml-queue.raw # translate js_of_ocaml-queue.ctf to raw format
	rm -f replay_raw.ctf
	MEMTRACE=replay_raw.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay_raw.exe js_of_ocaml-queue.raw # replay js_of_ocaml-queue.raw events
	echo # now we have the replayed allocs, we want to visually compare them to the original
	dune exec examples/memtrace_custom_analysis/lifetimes_of_objects.exe replay_raw.ctf > tmp1.pairs # replayed events, lifetimes
	cat tmp1.pairs | gnuplot -p -e "plot '-'" # gnuplot1.pdf
	dune exec examples/memtrace_custom_analysis/lifetimes_of_objects.exe ctf/js_of_ocaml-queue.ctf > tmp2.pairs # original events, lifetimes
	cat tmp2.pairs | gnuplot -p -e "plot '-'" # gnuplot2.pdf


all-replay_raw: 
	dune build bin/replay.exe
	dune build bin/translate_memtrace_to_raw.exe
	dune exec -- bin/translate_memtrace_to_raw.exe simple.ctf simple.raw
	dune build bin/replay_raw.exe
	rm -f replay_raw.ctf
	MEMTRACE=replay_raw.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay_raw.exe simple.raw
	./dump_trace.exe replay_raw.ctf > replay_raw.dump_trace

# replay the allocations from simple.exe
replay_simple:
	OCAMLRUNPARAM=b MEMTRACE=replayed.ctf MEMTRACE_RATE=1.0 dune exec -- bin/replay.exe simple.ctf
	./dump_trace.exe replayed.ctf > replayed.dump_trace

run_simple:
	MEMTRACE=simple.ctf MEMTRACE_RATE=1.0 dune exec examples/simple/simple.exe
	./dump_trace.exe simple.ctf > simple.dump_trace

replay:
	dune exec bin-replay/replay.exe

queens-all:
	dune clean
	OCAMLPARAM="_,inline=0" dune build --verbose examples/eight_queens/queens.exe
	MEMTRACE=queens.ctf MEMTRACE_RATE=1.0 dune exec examples/eight_queens/queens.exe

make_lifetimes_of_queued: 
	dune exec examples/memtrace_custom_analysis/lifetimes_of_queued_objects.exe examples/memtrace_custom_analysis/js_of_ocaml-queue.ctf > lifetimes_of_queued.pairs # output alloc-time lifetime pairs

all2:
	dune build examples/memtrace_custom_analysis/lifetimes_of_queued_objects.exe
	dune exec examples/memtrace_custom_analysis/lifetimes_of_queued_objects.exe examples/memtrace_custom_analysis/js_of_ocaml-queue.ctf > out.tmp # output alloc-time lifetime pairs
	cat out.tmp | gnuplot -p -e "plot '-'" # to make the graph

dump-queens:
	./dump_trace.exe queens.ctf > queens.dump_trace # 570M
# format: (alloc: time (alloc|alloc_major) obj_id src nsamples len=length common_prefix backtrace?) (collect: time obj_id collect) (promote: time obj_id promote)
