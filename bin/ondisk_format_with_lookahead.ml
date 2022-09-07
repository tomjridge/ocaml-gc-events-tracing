let write_min_alloc_to_channel =
  let tag = 'a' in
  let buf = Bytes.create 17 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:int) ~length -> 
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Bytes.set_int64_le buf 9 (Int64.of_int length);
    Stdlib.output_bytes out_ch buf;
    ()

let write_maj_alloc_to_channel =
  let tag = 'A' in
  let buf = Bytes.create 17 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:int) ~length -> 
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Bytes.set_int64_le buf 9 (Int64.of_int length);
    Stdlib.output_bytes out_ch buf;
    ()

let write_promote_to_channel =
  let tag = 'P' in
  let buf = Bytes.create 9 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:int) -> 
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Stdlib.output_bytes out_ch buf;
    ()

let write_min_collect_to_channel = 
  let tag = 'c' in
  let buf = Bytes.create 9 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:int) -> 
    Bytes.set buf 0 tag;
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Stdlib.output_bytes out_ch buf;
    ()
    
let write_maj_collect_to_channel = 
  let tag = 'C' in
  let buf = Bytes.create 9 in
  Bytes.set buf 0 tag;
  fun ~out_ch ~(obj_id:int) -> 
    Bytes.set buf 0 tag;
    Bytes.set_int64_le buf 1 (Int64.of_int (obj_id :> int));
    Stdlib.output_bytes out_ch buf;
    ()

let read_channel =  
  let tag_buf = Bytes.create 1 in
  let obj_id_buf = Bytes.create 8 in
  let length_buf = Bytes.create 8 in
  fun ~in_ch ~alloc_min_cb ~alloc_maj_cb ~collect_min_cb ~collect_maj_cb ~promote_cb () ->
  Stdlib.really_input in_ch tag_buf 0 1; (* throws End_of_file *)
  match Bytes.get tag_buf 0 with
  | 'a' -> 
    (* alloc; read obj_id and length and invoke callback *)
    Stdlib.really_input in_ch obj_id_buf 0 8;
    Stdlib.really_input in_ch length_buf 0 8;
    alloc_min_cb 
      ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0))
      ~length:(Int64.to_int (Bytes.get_int64_le length_buf 0));
    ()
  | 'A' -> 
    (* alloc; read obj_id and length and invoke callback *)
    Stdlib.really_input in_ch obj_id_buf 0 8;
    Stdlib.really_input in_ch length_buf 0 8;
    alloc_maj_cb 
      ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0))
      ~length:(Int64.to_int (Bytes.get_int64_le length_buf 0));
    ()
  | 'P' -> 
    Stdlib.really_input in_ch obj_id_buf 0 8;
    promote_cb 
      ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0));
    
  | 'c' -> 
    (* collect; read obj_id and invoke callback *)
    Stdlib.really_input in_ch obj_id_buf 0 8;
    collect_min_cb 
      ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0));
    ()
  | 'C' -> 
    (* collect; read obj_id and invoke callback *)
    Stdlib.really_input in_ch obj_id_buf 0 8;
    collect_maj_cb 
      ~obj_id:(Int64.to_int (Bytes.get_int64_le obj_id_buf 0));
    ()
  | _ as tag -> failwith (Printf.sprintf "Unrecognized tag: %c" tag)

let _ : 
in_ch:in_channel ->
alloc_min_cb:(obj_id:int -> length:int -> unit) ->
alloc_maj_cb:(obj_id:int -> length:int -> unit) ->
collect_min_cb:(obj_id:int -> unit) ->
collect_maj_cb:(obj_id:int -> unit) ->
promote_cb:(obj_id:int -> unit) -> unit -> unit
 = read_channel

let iter_channel ~in_ch ~alloc_min_cb ~alloc_maj_cb ~collect_min_cb ~collect_maj_cb ~promote_cb () = 
  try 
    while true do
      read_channel ~in_ch ~alloc_min_cb ~alloc_maj_cb ~collect_min_cb ~collect_maj_cb ~promote_cb ()
    done
  with End_of_file -> ()
