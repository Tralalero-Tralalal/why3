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
Require int.Int.
Require list.List.
Require list.Length.
Require list.Nth.
Require option.Option.

Require Import Lia.

(* Why3 goal *)
Lemma nth_none_1 {a:Type} {a_WT:WhyType a} :
  forall (l:Init.Datatypes.list a) (i:Numbers.BinNums.Z), (i < 0%Z)%Z ->
  ((list.Nth.nth i l) = Init.Datatypes.None).
Proof.
intros l.
induction l as [|h q].
easy.
intros i H.
simpl.
generalize (Zeq_bool_if i 0).
case Zeq_bool.
intros H'.
now rewrite H' in H.
intros _.
apply IHq.
lia.
Qed.

(* Why3 goal *)
Lemma nth_none_2 {a:Type} {a_WT:WhyType a} :
  forall (l:Init.Datatypes.list a) (i:Numbers.BinNums.Z),
  ((list.Length.length l) <= i)%Z ->
  ((list.Nth.nth i l) = Init.Datatypes.None).
Proof.
intros l.
induction l as [|h q].
easy.
intros i H.
unfold Length.length in H.
fold Length.length in H.
simpl.
generalize (Zeq_bool_if i 0).
case Zeq_bool.
intros H'.
rewrite H' in H.
exfalso.
generalize (Length.Length_nonnegative q).
lia.
intros _.
apply IHq.
lia.
Qed.

(* Why3 goal *)
Lemma nth_none_3 {a:Type} {a_WT:WhyType a} :
  forall (l:Init.Datatypes.list a) (i:Numbers.BinNums.Z),
  ((list.Nth.nth i l) = Init.Datatypes.None) ->
  (i < 0%Z)%Z \/ ((list.Length.length l) <= i)%Z.
Proof.
intros l.
induction l as [|h q].
intros i _.
simpl.
lia.
intros i.
simpl (Nth.nth i (h :: q)).
change (Length.length (h :: q)) with (1 + Length.length q)%Z.
generalize (Zeq_bool_if i 0).
case Zeq_bool.
easy.
intros Hi H.
specialize (IHq _ H).
lia.
Qed.

