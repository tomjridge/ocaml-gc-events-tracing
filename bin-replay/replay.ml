(** [./replay.exe path.ctf] load a CTF file from a memtrace trace of an OCaml program, and
    attempt to simulate the allocations and deallocs. *)


open Memtrace
open Base

let replay trace = 
  let allocs = Trace.Obj_id.Tbl.create 20 in
  Trace.Reader.iter trace (fun _time ev -> 
      match ev with
      | Alloc { obj_id; length; _ } -> (
          
        )
      | Collect id -> ()
      | Promote _ -> ())

let _main = 
  (* first argument is the path to the .ctf file *)
  let trace = Trace.Reader.open_ ~filename:(Sys.get_argv ()).(1) in
  replay trace



