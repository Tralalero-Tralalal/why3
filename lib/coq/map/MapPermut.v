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
Require map.Map.
Require map.Occ.

(* Why3 assumption *)
Definition permut {a:Type} {a_WT:WhyType a} (m1:Numbers.BinNums.Z -> a)
    (m2:Numbers.BinNums.Z -> a) (l:Numbers.BinNums.Z) (u:Numbers.BinNums.Z) :
    Prop :=
  forall (v:a), ((map.Occ.occ v m1 l u) = (map.Occ.occ v m2 l u)).

(* Why3 goal *)
Lemma permut_trans {a:Type} {a_WT:WhyType a} :
  forall (a1:Numbers.BinNums.Z -> a) (a2:Numbers.BinNums.Z -> a)
    (a3:Numbers.BinNums.Z -> a),
  forall (l:Numbers.BinNums.Z) (u:Numbers.BinNums.Z), permut a1 a2 l u ->
  permut a2 a3 l u -> permut a1 a3 l u.
Proof.
intros a1 a2 a3 l u h1 h2.
unfold permut in *.
intros. transitivity (Occ.occ v a2 l u); auto.
Qed.

(* Why3 goal *)
Lemma permut_exists {a:Type} {a_WT:WhyType a} :
  forall (a1:Numbers.BinNums.Z -> a) (a2:Numbers.BinNums.Z -> a)
    (l:Numbers.BinNums.Z) (u:Numbers.BinNums.Z) (i:Numbers.BinNums.Z),
  permut a1 a2 l u -> (l <= i)%Z /\ (i < u)%Z ->
  exists j:Numbers.BinNums.Z, ((l <= j)%Z /\ (j < u)%Z) /\ ((a1 j) = (a2 i)).
Proof.
intros a1 a2 l u i h1 Hi.
pose (v := a2 i).
assert (0 < map.Occ.occ v a2 l u)%Z.
  apply map.Occ.occ_pos. assumption.
rewrite <- h1 in H.
generalize (map.Occ.occ_exists v a1 l u H).
intros (j, (hj1,hj2)).
exists j; intuition.
Qed.

