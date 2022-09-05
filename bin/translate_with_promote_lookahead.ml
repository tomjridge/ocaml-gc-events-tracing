(** [translate_with_promote_lookahead infile outfile] translates from a memtrace ctf file
    to a "raw" format. Compared to [translate_memtrace_to_raw], for each alloc, we look
    ahead in the trace to see whether the object is promoted. In the replay, this allows
    us to distinguish allocs on the minor heap from allocs on the major heap. *)
open Memtrace

let _ = 
  if Array.length Sys.argv <> 3 then (
    Printf.printf "Usage: %s infile outfile" (Sys.argv.(0));
    Stdlib.exit (-1))
  else
    ()

(* assume 64 bit arch *)
let _ = assert(Sys.word_size = 64) 

let infile = Sys.argv.(1)
let outfile = Sys.argv.(2)

open Ondisk_format_with_lookahead

(* 

We have a stream of Alloc, Promote, Collect events. A Promote(obj_id) indicates that the
object was promoted to the major heap.

We want a stream of Alloc_min, Alloc_maj, Collect_min (which will be ignored), Collect_maj
events. We need to work out, for a particular Alloc, if the object is ever promoted or
not.

We store events in a queue until we know whether the corresponding object is ever promoted.

For a given obj_id, the state might be:

1. alloc'ed, no promote or collect seen
2. alloc'ed, promote seen
3. alloc'ed, no promote seen, collect seen
4. alloc'ed, promote seen, collect seen

When we see a Collect in the queue, and we know the state of the object, then we can
output the event and forget about the object altogether.

 *)

type obj_promoted_state = Unknown | Not_promoted | Promoted

type queue_event = 
  | Alloc of int * int (* obj_id * length *)
  | Collect_min of int 
  | Collect_maj of int

let main () = 
  let trace = Memtrace.Trace.Reader.open_ ~filename:infile in
  let out_ch = Stdlib.open_out_bin outfile in
  let max_oid = ref 0 in
  let q = Queue.create () in
  let map = Hashtbl.create 100 in
  let rec output_from_queue_if_known () = 
    if not (Queue.is_empty q) then 
      Queue.pop q |> function
      | Alloc((obj_id:int),length) -> (
          let pr = Hashtbl.find map obj_id in
          match pr with
          | Unknown -> () (* can't output - don't know if promoted or not *)
          | Not_promoted -> 
            write_min_alloc_to_channel ~out_ch ~obj_id ~length;
            output_from_queue_if_known ()                    
          | Promoted -> 
            write_maj_alloc_to_channel ~out_ch ~obj_id ~length;
            output_from_queue_if_known ())
      | Collect_min(obj_id) -> 
        write_min_collect_to_channel ~out_ch ~obj_id;        
        Hashtbl.remove map obj_id;
        output_from_queue_if_known ()
      | Collect_maj(obj_id) -> 
        write_maj_collect_to_channel ~out_ch ~obj_id;
        Hashtbl.remove map obj_id;
        output_from_queue_if_known ()
  in
  Trace.Reader.iter trace (fun _time ev -> 
      match ev with
      | Alloc { obj_id; length; _ } -> 
        (* add to queue and map *)
        let obj_id = (obj_id :> int) in
        Queue.add (Alloc(obj_id,length)) q;
        Hashtbl.add map obj_id Unknown;        
        max_oid := max !max_oid (obj_id :> int);
        ()
      | Promote obj_id -> 
        let obj_id = (obj_id :> int) in
        Hashtbl.replace map obj_id Promoted;
        output_from_queue_if_known ();
        ()
      | Collect obj_id -> 
        let obj_id = (obj_id :> int) in
        let pr = Hashtbl.find map obj_id in
        Hashtbl.remove map obj_id;
        match pr with
        | Unknown | Not_promoted -> 
          Queue.add (Collect_min(obj_id)) q;
          output_from_queue_if_known ()          
        | Promoted -> 
          Queue.add (Collect_maj(obj_id)) q;
          output_from_queue_if_known ()
    );
  (* we reached the end of the trace, but there may still be pending events in the
     queue *)
  q |> Queue.iter 
    (function
      | Alloc (obj_id,_) | Collect_min(obj_id) | Collect_maj(obj_id) -> 
        Hashtbl.replace map obj_id Not_promoted);
  output_from_queue_if_known (); (* should output all remaining in queue *)
  Stdlib.close_out_noerr out_ch;
  Printf.printf "Max obj_id: %d\n" !max_oid;
  ()

let _ = main ()
