# ocaml-gc-events-tracing

Our overall goal with the code in this repository is to be able to profile different GC strategies in order to compare GC performance. 

**OCaml's GC: next-fit and best-fit:** Traditionally, OCaml's default GC implemented the next-fit strategy. There was a first-fit strategy implemented in 2008 (?) but this was largely unused. In 4.10.0 (Feb. 2020) a best-fit allocator was introduced as an option. For some (or even many) workloads, best-fit was found to be superior to next-fit (see [article from Stephen Dolan](https://blog.janestreet.com/memory-allocator-showdown/) for more information). In 4.13.0 (Sept. 2021) OCaml's default strategy was changed from next-fit to best-fit.

The upcoming OCaml 5 will ship with a form of next-fit adapted to multicore (also includes other improvements? FIXME). (FIXME Why next-fit rather than best-fit? Let's assume this was done because next-fit was easier to adapt to multicore.) It makes sense to consider porting best-fit to multicore. However, there is some doubt that the performance difference between next-fit and best-fit that was observed previously, will still hold for OCaml 5. (FIXME Why? Because of improvements to next-fit in OCaml 5? Because of the way OCaml 5 works, which mitigates the benefits of best-fit?). At this stage we would like to know whether or not a "best-fit GC for OCaml 5 multicore" is worth implementing (since the effort involved is likely large).

Let's assume that the next-fit that ships with OCaml 5 (call it next-fit5) is an improvement on next-fit in 4.14 and previously. The article by Stephen Dolan linked above compares the performance of next-fit and best-fit (presumably for some version of OCaml pre-4.14, but the comparison presumably still holds at 4.14). One thing we could do is to repeat the performance analysis for next-fit and best-fit (for 4.14) and then compare further with next-fit5. If next-fit5 improves on next-fit, and is comparable to best-fit in performance, then we probably don't need to reimplement best-fit for multicore OCaml.

FIXME a wrinkle here is that OCaml 5 has only next-fit5 as GC strategy; thus, we would seemingly be comparing OCaml 5 next-fit with 4.14 next-fit and 4.14 best-fit, which is not an apples-to-apples comparison. For example, it is possible that other changes in OCaml 5 impact the performance of next-fit5 to make it seem "better than 4.14 best-fit", and so be used to justify not implementing best-fit5, when in fact these other changes would similarly improve best-fit5. The problem is that we are trying to assess the potential performance of a putative best-fit5 without having the actual implementation. And anyway, a best-fit5 implementation may itself not show the same improvement in performance as shown in the Dolan article (perhaps the multicore adaptations mean that a putative best-fit5 no longer improves on next-fit5). 

---

Putting these concerns aside, the concrete task is to write a routine to serialize OCaml's [Gc.Memprof](https://v2.ocaml.org/api/Gc.Memprof.html) events to a file (a "trace file"), in order to facilitate performance comparisons between different GC implementations. FIXME how will such a tool be used to compare different GC implementations? FIXME exactly how will such a tool help to assess whether to implement a best-fit adapted for multicore?

In addition, we want a small program that consumes the trace and simulates the behaviour of the traced program. (FIXME how exactly does it do this? If it sees an alloc it simulates the same; for a dealloc it some how loses the ref to a previously alloc'ed block?)



## Memtrace and memtrace-viewer

Memtrace https://github.com/janestreet/memtrace is a "streaming client for OCaml's memprof". By setting an envvar, and inserting a single "start profiling" instruction into a "main" function in your OCaml application, memtrace will log all Memprof events to a trace file. This trace file can then be viewed by memtrace-viewer https://github.com/janestreet/memtrace_viewer. The trace file uses the "ctf" (Common Trace Format) file format, so is potentially also viewable using other tools. The viewer is described in a blog post https://blog.janestreet.com/finding-memory-leaks-with-memtrace/; the interface runs in a browser and looks basic, but the functionality is fairly sophisticated.



## Replaying a memtrace

We can use memtrace to record Gc.Memprof events (allocation on minor/major heap; promotion; collection from minor/major heap). We can then simulate (to a very rough extent) the memory behaviour, by reading the memtrace file: If we see an `Alloc` we can allocate an int array of the appropriate size, and stash this object in a hashtable, indexed by object id; if we see a `Collect` of a given object id, we can remove that object from the hashtable (thereby making it unreachable), and hope that GC (in the simulating runtime) collects the object in a timely manner. 

This approach is implemented in the `bin-replay/replay.exe` tool. 

We would, of course, want to validate that the simulated behaviour really does match the traced behaviour (at least as far as GC is concerned). A simple approach would be to attempt to memtrace the simulating program (i.e., `replay.exe`). However, memtrace itself performs a significant amount of allocation and deallocation while reading and iterating over the trace. The resulting "memtrace of the simulated memtrace" would include all these memtrace-internal memory events. In effect, we are no longer simulating _only_ the original traced behaviour, but instead have all the memtrace overhead.

One point of view is that we are only doing this to validate that replay is correctly simulating the original traced behaviour. So if we filter out all the allocs and deallocs due to memtrace, and ignore timings, we should get the "simulated behaviour without the memtrace overhead", which should be enough to confirm that `replay.exe` is working properly.

Another approach would be to avoid the use of memtrace when running replay. We might instead use a much simpler file format, which could be mmap'ed or read sequentially without any memtrace overhead. Then _that_ could be memtraced (since the overhead from memtrace iterating through the trace would not be present).



## Raw traces

The file `bin/translate_memtrace_to_raw.ml` contains a program that translates a memtrace file (Common Trace Format) to a simpler "raw" trace. The aim is to be able to replay the raw trace whilst avoiding all the allocations that occur when replaying a memtrace.

**Simple example:** The file `examples/simple/simple.ml` is a simple test program that does some allocations of int arrays, sized from 0 to 10. We use memtrace to create `simple.ctf`. The file `simple.ctf` is then translated to `simple.raw` using `translate_memtrace_to_raw.exe`. Note there is also a `simple.dump_trace` which is a human-readable version of `simple.ctf`. Finally, we use `bin/replay_raw.exe` to replay a raw trace. We use memtrace to trace this *replay*, and store the results in `replay_raw.ctf`. Again, the human-readable contents is in `replay_raw.dump_trace`.



## Comments on `replay_raw`

The file `replay_raw.ctf` is a trace of memory events when using `replay_raw.exe` to simulate the trace of `simple.exe`. How close does it get to simulating the original events?

* `replay_raw.exe` does some allocations when reading the trace file, and other allocations (eg creating the hashtable), when it starts. This makes the replay not a faithful reconstruction of the original events. (init-allocs)
* During the main loop of `replay_raw.exe`, there are calls to array.init (to simulate allocs); the resulting objects are then stored in a hashtable indexed by obj_id, to prevent them being collected immediately. This insertion into the hashtable causes extra allocations, and again makes the replay not a faithful reconstruction of the original events. (hashtbl-add-allocs)
* Consider `simple.ml`: After the objects are allocated by `simple.ml`, a GC is called; the objects are all reachable so none are collected, and instead they are all promoted to the major heap. The objects are then freed, and GC is called again. This time, all the objects are collected. In the replay, no collections happen, because all that is recorded is object allocations and deallocations. Allocations are simulated by allocating an appropriately sized array and keeping a global reference to it. Deallocations are simulated by just dropping the reference to the object, and expecting GC to collect the object. But if GC never runs, we won't see the collection in the replay. 

The problem is that memtrace records allocs, promotions and collects, but does not explicitly record where GC occurs, or what type of GC occurs. In the case of `simple.exe` we allocate very little, so the GC never kicks in and we never see the collects that were due to an explicit call to `Gc.full_major` in `simple.exe`.

**Scenarios where `replay_raw` performs well:** Let's ignore (init-allocs) and (hashtbl-add-allocs). Then `replay_raw.exe` allocates objects of the correct size in the correct order. It then unlinks these objects in the correct order. If a full GC runs, we expect this set of objects to be collected. If a GC slice runs, then maybe some objects that were collected in one slice in the SUT (the run of `simple.exe`), instead get collected in a later slice in the replay (because, for example, our simple replay code doesn't ensure that the objects are traversed by the GC in the same order that they were in the SUT). But statistically, we sort-of expect things to match up. We could confirm this by replaying another scenario, where lots of objects are allocated and deallocated, and GC kicks in automatically (not via explicit calls, as currently in `simple.exe`). In fact, we could use eg the js_of_ocaml-queue example to test this.

**Attempt to confirm behaviour of `replay_raw`, using `js_of_ocaml-queue.ctf` example:** The results are in gnuplot1.pdf and gnuplot2.pdf. Visually, these look completely different.

<img src="README.assets/Screenshot_20220902_123120.png" alt="Screenshot_20220902_123120" style="zoom: 33%;" />

The topmost image is the original (including all objects, not just the queue-related objects as in Maurer's article). The one below is the simulation. The second graph seems to have many less lifetimes, presumably because the simulation is executing very quickly, and so multiple objects correspond to a single (x,y) lifetime coordinate.

Beyond that, in the top graph we see some banding - downward right bands, mostly short, before the final long band. In the bottom graph, there is some banding, but qualitatively this is completely different. 

Since our replay ignores times completely, we expect the replay to diverge from the original. But here there seems to be no real correspondence at all.

---

One obvious problem is that the `js_of_ocaml-queue.ctf` trace was collected in a completely different environment, and there is no reason to expect that GC during replay even uses the same algorithm as that used when the trace was recorded. So at the very least, we need to use a trace generated in the same environment as we use for the replay.

---

Before we do this, we can run some other checks on the replay and compare it to the original. So far we compared object lifetimes. We can instead compare the overall total used memory over time. memtrace-viewer can do this. For `js_of_ocaml-queue.ctf` we have:

<img src="README.assets/Screenshot_20220902_143338.png" alt="Screenshot_20220902_143338" style="zoom: 50%;" />

For the replay we have:

<img src="README.assets/Screenshot_20220902_143517.png" alt="Screenshot_20220902_143517" style="zoom:50%;" />

Which reveals that even the very basic allocation pattern doesn't match, nor the totals, not anything else. What is going on? We can write a simple script to summarize the allocations, giving the count of the number of allocations for each size. For `js_of_ocaml-queue.ctf` we get: 

```
size count
==== =====
1 159
2 225
3 62
4 168
5 265
6 19
7 14
8 1
9 5
12 2
14 1
32 1
39 1
64 1
465818 4
474300 11
474311 11
480135 2
604763 1
```

And for `replay_raw.ctf` we get: 

```
size count
==== =====
1 159
2 226
3 1016
4 172
5 265
6 21
7 14
8 1
9 5
12 2
14 1
32 2
39 1
64 3
128 2
8203 1
465818 4
474300 11
474311 11
480135 2
604763 1
```

These are actually pretty similar. The replay has a few more allocs at various sizes:

```
1	0
2	1
3	954
4	4
5	0
6	2
7	0
8	0
9	0
12	0
14	0
32	1
39	0
64	2
128	2
8203 1
```

In particular, the allocations of size 3 are likely due to (hashtbl-add-allocs). Other than this the allocations seem to match.