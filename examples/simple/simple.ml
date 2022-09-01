(* very simple program that allocates some arrays and calls GC *)

let xs = ref []

let main () = 
  (* alloc some small arrays *)
  for i = 0 to 10 do
    xs := (Array.init i (fun _ -> 1234)) :: !xs;
  done;
  (* call GC *)
  Stdlib.Gc.full_major ();
  (* the above should force the arrays to the major heap *)
  xs := [];
  (* now the arrays are free to be collected *)
  Stdlib.Gc.full_major ();
  ()

let _ = 
  Memtrace.trace_if_requested ();
  main ()
