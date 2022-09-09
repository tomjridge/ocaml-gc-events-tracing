(* Trivial example for testing *)

(* global ref *)
let xs = ref []

let min_count = 1000
let min_size = 11 (* words *)

let maj_size = 22

let num_iters = 100

let main () = 
  for _i = 1 to num_iters do
    for _j = 1 to min_count do
      Array.init min_size (fun _ -> 1234) |> Sys.opaque_identity |> ignore
    done;
    xs := (Array.init maj_size (fun _ -> 1234)) :: !xs;
  done;
  ()

let _ = 
  Printf.printf "min_count:%d min_size:%d maj_size:%d num_iters:%d\n" 
    min_count min_size maj_size num_iters;
  Gc.full_major();   
  Memtrace.trace_if_requested ();
  main ();
  Gc.print_stat Stdlib.stdout;
  ()
