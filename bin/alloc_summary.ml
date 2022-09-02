(* Parse a CTF file and print a basic summary of the number and size of allocs, as well as
   their distribution. *)

open Memtrace

let summarize trace = 
  (* store the number of allocs, keyed by size, in a hashtbl *)
  let allocs = Hashtbl.create 20 in 
  Trace.Reader.iter trace (fun _time ev -> 
      match ev with
      | Alloc { obj_id=_; length; _ } -> (
          Hashtbl.find_opt allocs length |> function
          | None -> Hashtbl.add allocs length 1
          | Some x -> Hashtbl.replace allocs length (x+1)
        )
      | Collect _ -> 
        ()
      | Promote _ -> 
        ());
  allocs

let print allocs = 
  let kvs = Hashtbl.to_seq allocs |> List.of_seq |> List.sort (fun (k1,_) (k2,_) -> if k1 < k2 then -1 else +1) in
  Printf.printf {|
Object allocations:
size count
==== =====
|};
  kvs |> List.iter (fun (size,count) -> Printf.printf "%d %d\n" size count);
  ()  

let main () = 
  let trace = Trace.Reader.open_ ~filename:Sys.argv.(1) in
  summarize trace |> print;
  Trace.Reader.close trace;
  ()

let _ = main ()

