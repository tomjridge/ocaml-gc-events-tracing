SHELL:=bash

all: 
	dune build bin/replay.exe
	dune build bin/translate_memtrace_to_raw.exe
	dune exec -- bin/translate_memtrace_to_raw.exe simple.ctf simple.raw
	dune build bin/replay_raw.exe
	rm -f replay_raw.ctf
	MEMTRACE=replay_raw.ctf dune exec -- bin/replay_raw.exe simple.raw
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
