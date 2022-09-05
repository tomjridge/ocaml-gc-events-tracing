(** Similar to [replay_raw.exe], but with pre-allocation of the array where objects are
    stashed, in order to avoid additional allocations during the trace *)

let replay in_ch max_obj_id = 
  (* set up an array of pointers to a dummy object; we place objects in the array when the
     trace says they are created, and remove them when the trace says they are
     collected *)
  let dummy_elt = Array.make 0 1234 in
  let allocs = Array.init (1+max_obj_id) (fun _ -> ref dummy_elt) in
  (* perform a full GC, to try to move GC to a state that is as close to the "initial
     state" for the SUT *)
  let _ = Gc.full_major () in 
  let alloc_cb ~obj_id ~length = 
    (* Printf.printf "alloc_cb called %d %d\n" obj_id length; *)
    let obj = Base.Array.init length ~f:(fun _ -> 1234) in
    allocs.(obj_id) := obj;
    ()
  in
  let collect_cb ~obj_id = 
    (* Printf.printf "collect_cb called %d\n" obj_id; *)
    allocs.(obj_id) := dummy_elt
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
  (* second argument is the max obj_id; FIXME if the pre-allocation approach works well,
     consider changing the raw trace format so that the first int is the max obj_id *)
  let max_obj_id = Sys.argv.(2) |> int_of_string in
  replay in_ch max_obj_id;
  Stdlib.close_in_noerr in_ch;
  ()

let _ = main ()
