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