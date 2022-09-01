(** [./replay.exe path.ctf] loads a CTF file from a memtrace trace of an OCaml program,
    and attempts to simulate the allocations and deallocs. [replay.exe] is itself
    instrumented with memtrace, and we can record the memtrace to a file in the usual way
    via the [MEMTRACE] envvar. *)

(* NOTE: simulating GC invocations: At the moment the ctf trace records allocs, promotes
   and deallocs. There is no explicit indication that a particular GC stage has
   occurred. But from the events we can deduce some obvious things:

- promote occurs during a minor GC
- dealloc_minor is from a minor GC
- dealloc_major is from a major GC

Given that these events occur in blocks, we can presumably partly infer when GC operations
took place. The operations (from Stdlib.Gc API) are: 

- minor; major_slice; major; full_major; compact

*)

open Memtrace
open Base

(** [replay trace] iterates through the trace; for [Alloc] events, an array is created of
    the given length, and stashed in a hashtbl; for [Collect] events, the object is
    removed from the hashtbl. This "replay" ignores the timings of allocations and
    deallocations, but preserves the order of allocations and hopefully the order of
    deallocations (assuming replay is run with the same GC strategy). *)
let replay trace = 
  let allocs = Trace.Obj_id.Tbl.create 20 in
  Trace.Reader.iter trace (fun _time ev -> 
      match ev with
      | Alloc { obj_id; length; _ } -> (
          let obj = Array.init length ~f:(fun _ -> 1234) in
          Trace.Obj_id.Tbl.add allocs obj_id obj;
          ()
        )
      | Collect obj_id -> 
        Trace.Obj_id.Tbl.remove allocs obj_id
      | Promote _ -> 
        (* FIXME do we want to do anything here? *)
        ())

let _main = 
  Memtrace.trace_if_requested ();
  (* first argument is the path to the .ctf file *)
  let trace = Trace.Reader.open_ ~filename:(Sys.get_argv ()).(1) in
  replay trace



