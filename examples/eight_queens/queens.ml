(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*               Pierre Weis, projet Cristal, INRIA Rocquencourt       *)
(*                                                                     *)
(*  Copyright 2001 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  only by permission.                                                *)
(*                                                                     *)
(***********************************************************************)

(*                         E I G H T   Q U E E N S

 The Eight Queens Program.

 How to set n queens on a chessboard of size n such that none
 can catch one each other.

 The program computes and prints the set of solutions
 (without removing symmetrical solutions).

 Program first compiled in ML V6.2 in 1987.

 Interesting exercise: change the program such as to be able to compute
 solutions for sizes greater than a few dozens.

*)

(* 1. Resolution of the n queens problem. *)

open List;;

let rec interval n m =
 if n > m then [] else n :: interval (n + 1) m;;

let filter_append p l l0 = 
  let rec filter = function
    | [] -> l0
    | h :: t -> if p h then h :: filter t else filter t in
   filter l;;

let rec concmap f = function
  | [] -> []
  | h :: t -> f h (concmap f t);;

let rec safe x d  = function
  | [] -> true
  | h :: t ->
     x <> h && x <> h + d && x <> h - d && safe x (d + 1) t;;

let ok = function
  | [] -> true
  | h :: t -> safe h 1 t;;

let find_solutions size =
 let line = interval 1 size in
 let rec gen n size =
   if n = 0 then [[]] else
   concmap 
    (fun b -> filter_append ok (map (fun q -> q :: b) line))
    (gen (n - 1) size) in
 gen size size;;

(* 2. Printing results. *)

let print_solutions size solutions =
 let sol_num = ref 1 in
 iter
   (fun chess ->
     Printf.printf "\nSolution number %i\n" !sol_num;
     sol_num := !sol_num + 1;
     iter
       (fun line ->
         let count = ref 1 in
         while !count <= size do
           if !count = line then print_string "Q " else print_string "- ";
           count := !count + 1
         done;
         print_newline ())
       chess)
   solutions;;

let print_result size =
 let solutions = find_solutions size in
 let sol_num = List.length solutions in
 Printf.printf "The %i queens problem has %i solutions.\n" size sol_num;
 print_newline ();
 let pr = "y" in
   (* print_string "Do you want to see the solutions <n/y> ? "; read_line () in *)
 if pr = "y" then print_solutions size solutions;;

(* 3. Main program. *)

let queens () =
 let size = 8
   (* print_string "Chess boards's size ? "; read_int ()  *)
 in
 print_result size;;

if !Sys.interactive then () else (
  Memtrace.trace_if_requested ();
  queens ());;
