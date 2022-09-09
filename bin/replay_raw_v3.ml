(** Similar to [replay_raw_v2.exe], but using {Ondisk_format_with_lookahead}. *)

let _ = assert(Sys.word_size = 64)

let dummy_elt = Array.make 0 1234 
let allocs = ref (Array.init 0 (fun _ -> ref dummy_elt))

let replay in_ch max_obj_id = 
  (* set up an array of pointers to a dummy object; we place objects in the array when the
     trace says they are created, and remove them when the trace says they are
     collected *)
  (* let dummy_elt = Array.make 0 1234 in *)
  let _ = allocs := Array.init (1+max_obj_id) (fun _ -> ref dummy_elt) in
  (* perform a full GC, to try to move GC to a state that is as close to the "initial
     state" for the SUT *)
  let _ = Gc.full_major () in 
  let alloc_min_cb ~obj_id ~length = 
    ignore(obj_id);
    (* let obj = Array.init length (fun _ -> 1234) in *)
    let obj = Bytes.make (8 * length) (* length is measured in words *) '?' in
    (* NOTE don't stash in allocs... obj was collected from minor heap *)
    ignore(obj);
    ()
  in
  let alloc_maj_cb ~obj_id ~length = 
    let obj = Array.init length (fun _ -> 1234) in
    !allocs.(obj_id) := obj;
    ()
  in
  let collect_min_cb ~obj_id = 
    ignore(obj_id);
    ()
  in
  let collect_maj_cb ~obj_id = 
    !allocs.(obj_id) := dummy_elt
  in
  let promote_cb ~obj_id = 
    ignore(obj_id);
    ()
  in
  try
    while true do
      Ondisk_format_with_lookahead.read_channel 
        ~in_ch ~alloc_min_cb ~alloc_maj_cb ~collect_min_cb ~collect_maj_cb ~promote_cb ()
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
