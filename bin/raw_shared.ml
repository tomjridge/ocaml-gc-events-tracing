let write_alloc_to_channel =
  let tag = 'A' in
  let buf = Bytes.create 17 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:Memtrace.Trace.Obj_id.t) ~length -> 
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Bytes.set_int64_le buf 9 (Int64.of_int length);
    Stdlib.output_bytes out_ch buf;
    ()

let write_promote_to_channel =
  let tag = 'P' in
  let buf = Bytes.create 9 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:Memtrace.Trace.Obj_id.t) -> 
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Stdlib.output_bytes out_ch buf;
    ()

let write_collect_to_channel = 
  let tag = 'C' in
  let buf = Bytes.create 9 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:Memtrace.Trace.Obj_id.t) -> 
    Bytes.set buf 0 tag;
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Stdlib.output_bytes out_ch buf;
    ()

(* we want to avoid allocation as far as possible, so provide callbacks *)
let read_channel =  
  let tag_buf = Bytes.create 1 in
  let obj_id_buf = Bytes.create 8 in
  let length_buf = Bytes.create 8 in
  fun ~in_ch ~alloc_cb ~collect_cb ~promote_cb () ->
  Stdlib.really_input in_ch tag_buf 0 1; (* throws End_of_file *)
  match Bytes.get tag_buf 0 with
  | 'A' -> 
    (* alloc; read obj_id and length and invoke callback *)
    Stdlib.really_input in_ch obj_id_buf 0 8;
    Stdlib.really_input in_ch length_buf 0 8;
    alloc_cb 
      ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0))
      ~length:(Int64.to_int (Bytes.get_int64_le length_buf 0));
    ()
  | 'P' -> 
    Stdlib.really_input in_ch obj_id_buf 0 8;
    promote_cb ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0));
    ()
  | 'C' -> 
    (* collect; read obj_id and invoke callback *)
    Stdlib.really_input in_ch obj_id_buf 0 8;
    collect_cb 
      ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0));
    ()
  | _ as tag -> failwith (Printf.sprintf "Unrecognized tag: %c" tag)

let _ : 
in_ch:in_channel ->
alloc_cb:(obj_id:int -> length:int -> unit) ->
collect_cb:(obj_id:int -> unit) -> 
promote_cb:(obj_id:int -> unit) -> unit -> unit
 = read_channel


(* NOTE although we try to avoid allocs, the above buffers do indeed alloc, which means
   that we disturb slightly the GC state, which in turn may cause the replay runtime to
   start GC at slightly earlier times than the traced system. FIXME? *)

let iter_channel ~in_ch ~alloc_cb ~collect_cb ~promote_cb () = 
  try 
    while true do
      read_channel ~in_ch ~alloc_cb ~collect_cb ~promote_cb ()
    done
  with End_of_file -> ()
    
