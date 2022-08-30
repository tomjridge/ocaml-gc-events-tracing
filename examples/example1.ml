(* This example taken from https://github.com/ocaml/ocaml/pull/8731 ; it is a
   near-worst-case for Statmemprof profiling overhead. *)


let samples = ref 0

let rec recur n f = match n with 0 -> f () | n -> recur (n-1) f + 1

let () =
  Gc.Memprof.start { sampling_rate = 0.01; callstack_size = 10;
                     callback = fun _ -> incr samples; None };

  for i = 1 to 10_000_000 do
    let d = recur 20 (fun () ->
      Array.make 20 0 |> ignore; ref 42 |> Sys.opaque_identity |> ignore; 0) in
    assert (d = 20)
  done;

  Printf.printf "%d\n" !samples
