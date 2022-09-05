(** [translate_memtrace_to_raw infile outfile] translates from a memtrace ctf file to a
    "raw" format. The raw format can be read directly, without incurring allocations and
    deallocations (which is the case when using memtrace to read a trace). This means that
    we can apply memtrace to the [./replay.exe] trace replayer, in order to confirm that
    the memory behaviour is similar to the originally traced program. *)
open Memtrace

let _ = 
  if Array.length Sys.argv <> 3 then (
    Printf.printf "Usage: %s infile outfile" (Sys.argv.(0));
    Stdlib.exit (-1))
  else
    ()

(* assume 64 bit arch *)
let _ = assert(Sys.word_size = 64) 

let infile = Sys.argv.(1)
let outfile = Sys.argv.(2)

open Raw_shared

let main () = 
  let trace = Memtrace.Trace.Reader.open_ ~filename:infile in
  let out_ch = Stdlib.open_out_bin outfile in
  let max_oid = ref 0 in
  Trace.Reader.iter trace (fun _time ev -> 
      match ev with
      | Alloc { obj_id; length; _ } -> 
        write_alloc_to_channel ~out_ch ~obj_id ~length;
        max_oid := max !max_oid (obj_id :> int);
        ()
      | Collect obj_id -> 
        write_collect_to_channel ~out_ch ~obj_id;
        ()
      | Promote _ -> () (* ignore promotes for raw files *) 
    );
  Stdlib.close_out_noerr out_ch;
  Printf.printf "Max obj_id: %d\n" !max_oid;
  ()

let _ = main ()
