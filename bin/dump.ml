(* dump a trace; handles ctf, and raw formats *)

let _ = 
  if Array.length Sys.argv <> 3 then (
    Printf.printf "Usage: %s version infile" (Sys.argv.(0));
    Stdlib.exit (-1))
  else
    ()

let version = Sys.argv.(1) |> function
  | "ctf" -> `Ctf
  | "raw" -> `Raw
  | "lookahead" -> `Lookahead
  | x -> failwith (Printf.sprintf "Unrecognized version %s" x)

let infile = Sys.argv.(2)

module Ctf_callbacks = struct
  let alloc_cb ~obj_id ~length = 
    Printf.printf "A %d %d\n" obj_id length

  let promote_cb ~obj_id = 
    Printf.printf "P %d\n" obj_id

  let collect_cb ~obj_id = 
    Printf.printf "C %d\n" obj_id
end

module Lookahead_callbacks = struct
  let alloc_maj_cb ~obj_id ~length = 
    Printf.printf "A %d %d\n" obj_id length

  let alloc_min_cb ~obj_id ~length = 
    Printf.printf "a %d %d\n" obj_id length

  let promote_cb ~obj_id = 
    Printf.printf "P %d\n" obj_id

  let collect_maj_cb ~obj_id = 
    Printf.printf "C %d\n" obj_id

  let collect_min_cb ~obj_id = 
    Printf.printf "c %d\n" obj_id
end

let main () = 
  match version with
  | `Ctf -> (
    let trace = Memtrace.Trace.Reader.open_ ~filename:infile in
    Memtrace.Trace.Reader.iter trace (fun _time ev -> 
        let open Ctf_callbacks in
        match ev with
        | Alloc { obj_id; length; _ } -> 
          alloc_cb ~obj_id:(obj_id:>int) ~length;
          ()
        | Collect obj_id ->
          collect_cb ~obj_id:(obj_id:>int);
          ()
        | Promote obj_id -> 
          promote_cb ~obj_id:(obj_id:>int);
          ()
      );
    Memtrace.Trace.Reader.close trace;
    ())
  | `Raw -> (
      let open Ctf_callbacks in
      let in_ch = Stdlib.open_in_bin infile in
      Raw_shared.iter_channel ~in_ch ~alloc_cb ~collect_cb ~promote_cb ();
      ()
    )
  | `Lookahead -> (
      let open Lookahead_callbacks in
      let in_ch = Stdlib.open_in_bin infile in
      Ondisk_format_with_lookahead.iter_channel 
        ~in_ch
        ~alloc_min_cb:alloc_min_cb
        ~alloc_maj_cb:alloc_maj_cb
        ~collect_min_cb:collect_min_cb
        ~collect_maj_cb:collect_maj_cb
        ~promote_cb
        ()
      )

let _ = main ()
