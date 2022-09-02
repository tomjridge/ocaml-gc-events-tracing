(** Similar to [replay.exe], but with raw traces *)

let replay in_ch = 
  let allocs = Hashtbl.create 20 in
  let alloc_cb ~obj_id ~length = 
    (* Printf.printf "alloc_cb called %d %d\n" obj_id length; *)
    let obj = Base.Array.init length ~f:(fun _ -> 1234) in
    Hashtbl.add allocs obj_id obj;
    ()
  in
  let collect_cb ~obj_id = 
    (* Printf.printf "collect_cb called %d\n" obj_id; *)
    Hashtbl.remove allocs obj_id
  in
  try
    while true do
      Raw_shared.read_channel ~in_ch ~alloc_cb ~collect_cb
    done
  with End_of_file -> ()

let main () = 
  Memtrace.trace_if_requested ();
  (* first argument is the path to the .ctf file *)
  let in_ch = Stdlib.open_in_bin Sys.argv.(1) in
  replay in_ch;
  Stdlib.close_in_noerr in_ch;
  ()

let _ = main ()
