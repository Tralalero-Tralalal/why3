(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2025 --  Inria - CNRS - Paris-Saclay University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(********************************************************************)

(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require HighOrd.
Require int.Int.
Require set.Fset.

(* Why3 goal *)
Definition t : Type.
Proof.
(* Example bool *)
apply bool.
Defined.

(* Why3 goal *)
Definition p : set.Fset.fset t -> Prop.
Proof.
intros f.
apply True.
Defined.

(* Why3 goal *)
Lemma Induction :
  (forall (s:set.Fset.fset t), set.Fset.is_empty s -> p s) ->
  (forall (s:set.Fset.fset t), p s -> (forall (t1:t), p (set.Fset.add t1 s))) ->
  forall (s:set.Fset.fset t), p s.
Proof.
intros h1 h2 s.
(* TODO make something interesting *)
unfold p. constructor.
Qed.

