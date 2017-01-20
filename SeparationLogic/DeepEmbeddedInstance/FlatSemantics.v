Require Import Coq.Logic.Classical_Prop.
Require Import Coq.Classes.RelationClasses.
Require Import Coq.Relations.Relation_Definitions.
Require Import Logic.lib.Coqlib.
Require Import Logic.GeneralLogic.Base.
Require Import Logic.MinimunLogic.Syntax.
Require Import Logic.PropositionalLogic.Syntax.
Require Import Logic.SeparationLogic.Syntax.
Require Import Logic.PropositionalLogic.KripkeModel.
Require Import Logic.SeparationLogic.Model.SeparationAlgebra.
Require Import Logic.SeparationLogic.Model.OrderedSA.
Require Import Logic.PropositionalLogic.Semantics.Kripke.
Require Import Logic.SeparationLogic.Semantics.FlatSemantics.
Require Import Logic.SeparationLogic.DeepEmbeddedInstance.SeparationEmpLanguage.

Local Open Scope logic_base.
Local Open Scope syntax.
Local Open Scope kripke_model.
Import SeparationLogicNotation.
Import KripkeModelFamilyNotation.
Import KripkeModelNotation_Intuitionistic.

Record frame: Type := {
  underlying_set:> Type;
  Krelation: relation underlying_set; (* <= *)
  Krelation_Preorder: PreOrder Krelation;
  R: Relation underlying_set := Krelation;
  kiM: KripkeIntuitionisticModel underlying_set := Krelation_Preorder;
  J: Join underlying_set;
  SA: SeparationAlgebra underlying_set;
  dSA: DownwardsClosedSeparationAlgebra underlying_set;
  uSA: UpwardsClosedSeparationAlgebra underlying_set
}.

Infix "<=" := (Krelation _): TheKripkeSemantics.

Local Open Scope TheKripkeSemantics.

Definition sem (f: frame) := sig (fun s: Ensemble f => forall x y, x <= y -> s x -> s y).

Program Definition sem_and {F: frame} (X: sem F) (Y: sem F): sem F :=
  fun x: F => X x /\ Y x.
Next Obligation.
  split.
  + eapply (proj2_sig X); eauto.
  + eapply (proj2_sig Y); eauto.
Qed.

Program Definition sem_or {F: frame} (X: sem F) (Y: sem F): sem F :=
  fun x: F => X x \/ Y x.
Next Obligation.
  destruct H0; [left | right].
  + eapply (proj2_sig X); eauto.
  + eapply (proj2_sig Y); eauto.
Qed.

Program Definition sem_imp {F: frame} (X: sem F) (Y: sem F): sem F :=
  fun x: F =>
    forall y: F, x <= y -> X y -> Y y.
Next Obligation.
  revert H2; apply H0.
  pose proof @PreOrder_Transitive _ _ (Korder_preorder F).
  transitivity y; auto.
Qed.

Program Definition sem_true {F: frame}: sem F :=
  fun x: F => True.

Program Definition sem_false {F: frame}: sem F :=
  fun x: F => False.

Program Definition sem_sepcon {F: frame} (X: sem F) (Y: sem F): sem F :=
  fun m: F =>
    exists m1 m2, @join _ (J F) m1 m2 m /\ X m1 /\ Y m2.
Next Obligation.
  rename H0 into y1, H1 into y2.
  destruct (@join_Korder_up _ _ _ (uSA F) _ _ _ _ H2 H) as [x1 [x2 [? [? ?]]]].
  exists x1, x2.
  split; [| split]; auto.
  + eapply (proj2_sig X); eauto.
  + eapply (proj2_sig Y); eauto.
Qed.

Program Definition sem_wand {F: frame} (X: sem F) (Y: sem F): sem F :=
  fun m: F =>
    forall m1 m2, @join _ (J F) m m1 m2 -> X m1 -> Y m2.
Next Obligation.
  destruct (@join_Korder_down _ _ _ (dSA F) _ _ _ _ m1 H1 H) as [m [? ?]].
  + reflexivity.
  + eapply (proj2_sig Y); [eauto |].
    eapply H0; eauto.
Qed.

Program Definition sem_emp {F: frame}: sem F :=
  fun m: F => @increasing _ (kiM F) (J F) m.
Next Obligation.
  unfold increasing in *.
  intros.
  destruct (@join_Korder_down _ _ _ (dSA F) _ _ _ _ n H1 H) as [m' [? ?]].
  + reflexivity.
  + specialize (H0 _ _ H2).
    etransitivity; eauto.
Qed.

Definition denotation {Var: Type} (F: frame) (eval_emp: sem F) (eval: Var -> sem F): expr Var -> sem F :=
  fix denotation (x: expr Var): sem F:=
  match x with
  | andp y z => sem_and (denotation y) (denotation z)
  | orp y z => sem_or (denotation y) (denotation z)
  | impp y z => sem_imp (denotation y) (denotation z)
  | sepcon y z => sem_sepcon (denotation y) (denotation z)
  | wand y z => sem_wand (denotation y) (denotation z)
  | emp => eval_emp
  | falsep => sem_false
  | varp p => eval p
  end.

Section KripkeSemantics.
Context (Var: Type).

Record Kmodel : Type := {
  underlying_frame :> frame;
  Kemp: sem underlying_frame;
  Kvar: Var -> sem underlying_frame
}.

Record model: Type := {
  underlying_model :> Kmodel;
  elm: underlying_model
}.

Instance L: Language := UnitarySeparationLanguage.L Var.
Instance MD: Model := Build_Model model.

Instance kMD: KripkeModel MD :=
  Build_KripkeModel _
    Kmodel
    (fun M => M)
    (fun M m => Build_model M m).

Existing Instances kiM J SA dSA uSA.

Instance SM: Semantics L MD :=
  Build_Semantics L MD
   (fun M x => proj1_sig (denotation M (Kemp M) (Kvar M) x) (elm M)).

Instance kiSM (M: Kmodel): KripkeIntuitionisticSemantics L MD M SM.
Proof.
  apply Build_KripkeIntuitionisticSemantics.
  + hnf; simpl; intros.
    eapply (proj2_sig (denotation M (Kemp M) (Kvar M) x)); eauto.
  + split; auto.
  + split; auto.
  + split; auto.
  + intros; simpl. auto.
Defined.

Instance fsSM (M: Kmodel): FlatSemantics.FlatSemantics L MD M SM.
Proof.
  apply FlatSemantics.Build_FlatSemantics.
  + intros.
    simpl; reflexivity.
  + intros.
    simpl; reflexivity.
Defined.

(*
Instance UsSM (M: Kmodel): UnitalSemantics L MD M SM.
Proof.
  hnf; intros.
  simpl; reflexivity.
Defined.
*)

Definition Kmodel_Identity: Kmodel -> Prop := fun M =>
  IdentityKripkeIntuitionisticModel (Kworlds M).

Definition Kmodel_NoBranch: Kmodel -> Prop := fun M =>
  NoBranchKripkeIntuitionisticModel (Kworlds M).

Definition Kmodel_BranchJoin: Kmodel -> Prop := fun M =>
  BranchJoinKripkeIntuitionisticModel (Kworlds M).

(* TODO: the name should be nonpositive *)
Definition Kmodel_GarbageCollect: Kmodel -> Prop := fun M =>
  GarbageCollectSeparationAlgebra (Kworlds M).

Definition Kmodel_Unital: Kmodel -> Prop := fun M =>
  (forall m: Kworlds M, proj1_sig (Kemp M) m <-> proj1_sig sem_emp m) /\
  UnitalSeparationAlgebra (Kworlds M).

Definition Kmodel_Residual: Kmodel -> Prop := fun M =>
  ResidualSeparationAlgebra (Kworlds M).


Require Import Logic.SeparationLogic.SoundCompleteParameter.

Record Kmodel_ParClass (PAR: SA_Parameter) (M: Kmodel): Prop := {
  SA_ID: ID PAR = true -> IdentityKripkeIntuitionisticModel (Kworlds M);
  SA_NB: NB PAR = true -> NoBranchKripkeIntuitionisticModel (Kworlds M);
  SA_BJ: BJ PAR = true -> BranchJoinKripkeIntuitionisticModel (Kworlds M);
  SA_GC: GC PAR = true -> GarbageCollectSeparationAlgebra (Kworlds M);
  SA_Uni: Uni PAR = true -> UnitalSeparationAlgebra (Kworlds M)
}.

End KripkeSemantics.
End FlatSemanticsModel.