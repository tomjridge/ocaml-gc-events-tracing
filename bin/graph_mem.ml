(* Process a ctf file, allocs and collects; output a running total; unlike
   memtrace-viewer, we ignore time, since this is not preserved in the replay and we want
   to compare graphs *)

let _ = 
  if Array.length Sys.argv <> 2 then (
    Printf.printf "Usage: %s infile" (Sys.argv.(0));
    Stdlib.exit (-1))
  else
    ()

let infile = Sys.argv.(1)

let process trace = 
  (* store running total allocated *)
  let total = ref 0 in
  (* store mapping from obj_id to size of object *)
  let allocs = Hashtbl.create 100 in 
  Memtrace.Trace.Reader.iter trace (fun _time ev -> 
      match ev with
      | Alloc { obj_id; length; _ } -> (
          total := !total + length;
          Hashtbl.add allocs obj_id length;
          Printf.printf "%d\n" !total;
        )
      | Collect obj_id -> 
        let length = Hashtbl.find allocs obj_id in
        Hashtbl.remove allocs obj_id;
        total := !total - length;
        Printf.printf "%d\n" !total;
        ()
      | Promote _ -> 
        ());
  ()
  
let main () = 
  let trace = Memtrace.Trace.Reader.open_ ~filename:infile in
  process trace

let _ = main ()
