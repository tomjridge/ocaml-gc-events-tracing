(** A basic sanity check for lookahead format traces:
    - if we see a minor alloc, we check there is no promote before the min collect
    - if we see a major alloc, we check there is a promote before the maj collect
*)

let _ = 
  if Array.length Sys.argv <> 2 then (
    Printf.printf "Usage: %s infile" (Sys.argv.(0));
    Stdlib.exit (-1))
  else
    ()

let infile = Sys.argv.(1)

let main () =
  let minors = Hashtbl.create 100 in
  let majors = Hashtbl.create 100 in
  let c1,c2,c3,c4,c5 = ref 0, ref 0, ref 0, ref 0, ref 0 in
  let alloc_min_cb ~obj_id ~length = 
    ignore(length);
    Hashtbl.add minors obj_id ();
    incr c1      
  in
  let alloc_maj_cb ~obj_id ~length = 
    ignore(length);
    Hashtbl.add majors obj_id ();
    incr c2
  in
  let collect_min_cb ~obj_id = 
    let present = Hashtbl.mem minors obj_id in
    (if not present then 
       failwith (Printf.sprintf "Minor collect on object, obj not present: %d" obj_id));
    Hashtbl.remove minors obj_id;
    incr c3
  in
  let collect_maj_cb ~obj_id = 
    let present = Hashtbl.mem majors obj_id in
    (if not present then 
       failwith (Printf.sprintf "Major collect on object, obj not present: %d" obj_id));
    Hashtbl.remove majors obj_id;
    incr c4      
  in
  let promote_cb ~obj_id = 
    (if Hashtbl.mem minors obj_id then 
       failwith (Printf.sprintf "Promote on minor object: %d" obj_id));
    let present = Hashtbl.mem majors obj_id in
    (if not present then 
       failwith (Printf.sprintf "Promote on object, obj not present: %d" obj_id));
    ();
    incr c5
  in
  let in_ch = Stdlib.open_in_bin infile in
  Ondisk_format_with_lookahead.iter_channel 
    ~in_ch
    ~alloc_min_cb
    ~alloc_maj_cb
    ~collect_min_cb
    ~collect_maj_cb
    ~promote_cb
    ();
  Printf.printf "Trace checked OK; counters: a:%d A:%d c:%d C:%d P:%d"
    !c1 !c2 !c3 !c4 !c5

let _ = main ()

