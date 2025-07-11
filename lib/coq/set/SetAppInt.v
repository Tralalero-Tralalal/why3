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
Require set.FsetInt.
Require set.SetApp.

(* Why3 goal *)
Definition set : Type.
Proof.
exact (Fset.fset Z).
Defined.

(* Why3 goal *)
Definition to_fset : set -> set.Fset.fset Numbers.BinNums.Z.
Proof.
exact (fun x => x).
Defined.

(* Why3 goal *)
Definition mk : set.Fset.fset Numbers.BinNums.Z -> set.
Proof.
exact (fun x => x).
Defined.

(* Why3 goal *)
Lemma mk'spec :
  forall (s:set.Fset.fset Numbers.BinNums.Z), ((to_fset (mk s)) = s).
Proof.
trivial.
Qed.

(* Why3 goal *)
Definition choose : set -> Numbers.BinNums.Z.
Proof.
exact Fset.pick.
Defined.

(* Why3 goal *)
Lemma choose'spec :
  forall (s:set), ~ set.Fset.is_empty (to_fset s) ->
  set.Fset.mem (choose s) (to_fset s).
Proof.
apply Fset.pick_def.
Qed.

(* Why3 goal *)
Definition t : Type.
Proof.
exact unit.
Defined.

(* Why3 goal *)
Definition initial : t -> set.
Proof.
intro x.
exact Fset.empty.
Defined.

(* Why3 goal *)
Definition visited : t -> set.
Proof.
intro x.
exact Fset.empty.
Defined.

(* Why3 goal *)
Lemma t'invariant :
  forall (self:t),
  set.Fset.subset (to_fset (visited self)) (to_fset (initial self)).
Proof.
intros self.
unfold Fset.subset, to_fset, visited, initial.
auto.
Qed.

