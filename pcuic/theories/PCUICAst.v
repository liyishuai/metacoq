(* Distributed under the terms of the MIT license. *)
From Coq Require Import ssreflect Morphisms.
From MetaCoq.Template Require Export utils Universes BasicAst Environment Reflect.
From MetaCoq.Template Require EnvironmentTyping.
From MetaCoq.PCUIC Require Export PCUICPrimitive.
From Equations Require Import Equations.
(** * AST of the Polymorphic Cumulative Calculus of Inductive Constructions

   This AST is a cleaned-up version of Coq's internal AST better suited for
   reasoning.
   In particular, it has binary applications and all terms are well-formed.
   Casts are absent as well. *)

Declare Scope pcuic.
Delimit Scope pcuic with pcuic.
Open Scope pcuic.

(** DO NOT USE firstorder, since the introduction of Ints and Floats, it became unusuable. *)
Ltac pcuicfo_gen tac :=
  simpl in *; intuition (simpl; intuition tac).

Tactic Notation "pcuicfo" := pcuicfo_gen auto.
Tactic Notation "pcuicfo" tactic(tac) := pcuicfo_gen tac.

(* This allows not relying on lemma names getting a length equality out of some type. *)
Class HasLen (A : Type) (x y : nat) := len : A -> x = y.

(** Note the use of a global reference to avoid capture. *)
Notation length_of t := ltac:(let lemma := constr:(PCUICAst.len t) in exact lemma) (only parsing).


(* Defined here since BasicAst does not have access to universe instances.
  Parameterized by term types as they are not yet defined. *)
Record predicate {term} := mkpredicate {
  pparams : list term; (* The parameters *)
  puinst : Instance.t; (* The universe instance *)
  pcontext : list (context_decl term); (* The predicate context, 
    initially built from params and puinst *)
  preturn : term; (* The return type *) }.
Derive NoConfusion for predicate.
Arguments predicate : clear implicits.
Arguments mkpredicate {_}.

Section map_predicate.
  Context {term term' : Type}.
  Context (uf : Instance.t -> Instance.t).
  Context (paramf preturnf : term -> term').
  
  Definition map_predicate (p : predicate term) :=
    {| pparams := map paramf p.(pparams);
        puinst := uf p.(puinst);
        pcontext := map_context paramf p.(pcontext);
        preturn := preturnf p.(preturn) |}.

  Lemma map_pparams (p : predicate term) :
    map paramf (pparams p) = pparams (map_predicate p).
  Proof. reflexivity. Qed.

  Lemma map_preturn (p : predicate term) :
    preturnf (preturn p) = preturn (map_predicate p).
  Proof. reflexivity. Qed.

  Lemma map_pcontext (p : predicate term) :
    map_context paramf (pcontext p) = pcontext (map_predicate p).
  Proof. reflexivity. Qed.

  Lemma map_puinst (p : predicate term) :
    uf (puinst p) = puinst (map_predicate p).
  Proof. reflexivity. Qed.

End map_predicate.

Definition shiftf {A B} (f : nat -> A -> B) k := (fun k' => f (k' + k)).

Section map_predicate_k.
  Context {term : Type}.
  Context (uf : Instance.t -> Instance.t).
  Context (f : nat -> term -> term).

  Definition map_predicate_k k (p : predicate term) :=
    {| pparams := map (f k) p.(pparams);
        puinst := uf p.(puinst);
        pcontext := mapi_context (shiftf f k) p.(pcontext);
        preturn := f (#|p.(pcontext)| + k) p.(preturn) |}.

  Lemma map_k_pparams k (p : predicate term) :
    map (f k) (pparams p) = pparams (map_predicate_k k p).
  Proof. reflexivity. Qed.

  Lemma map_k_preturn k (p : predicate term) :
    f (#|p.(pcontext)| + k) (preturn p) = preturn (map_predicate_k k p).
  Proof. reflexivity. Qed.

  Lemma map_k_pcontext k (p : predicate term) :
    mapi_context (shiftf f k) (pcontext p) = pcontext (map_predicate_k k p).
  Proof. reflexivity. Qed.

  Lemma map_k_puinst k (p : predicate term) :
    uf (puinst p) = puinst (map_predicate_k k p).
  Proof. reflexivity. Qed.
  
  Definition test_predicate (instp : Instance.t -> bool) (p : term -> bool) 
    (pred : predicate term) :=
    instp pred.(puinst) && forallb p pred.(pparams) && 
    test_context p pred.(pcontext) && p pred.(preturn).

  Definition test_predicate_k (instp : Instance.t -> bool) 
    (p : nat -> term -> bool) k (pred : predicate term) :=
    instp pred.(puinst) && forallb (p k) pred.(pparams) && 
    test_context_k p k pred.(pcontext) && p (#|pred.(pcontext)| + k) pred.(preturn).

End map_predicate_k.

Section Branch.
  Context {term : Type}.
  (* Parameterized by term types as they are not yet defined. *)
  Record branch := mkbranch {
    bcontext : list (context_decl term); 
    (* Context of binders of the branch, including lets. *)
    bbody : term; (* The branch body *) }.
  Derive NoConfusion for branch.

  Definition string_of_branch (f : term -> string) (b : branch) :=
  "([" ^ String.concat "," (map (string_of_name ∘ binder_name ∘ decl_name) (bcontext b)) ^ "], "
  ^ f (bbody b) ^ ")".

  Definition pretty_string_of_branch (f : term -> string) (b : branch) :=
    String.concat " " (map (string_of_name ∘ binder_name ∘ decl_name) (bcontext b)) ^ " => " ^ f (bbody b).
  
  Definition test_branch (p : term -> bool) (b : branch) :=
    test_context p b.(bcontext) && p b.(bbody).

  Definition test_branch_k (p : nat -> term -> bool) k (b : branch) :=
    test_context_k p k b.(bcontext) && p (#|b.(bcontext)| + k) b.(bbody).

End Branch.  
Arguments branch : clear implicits.

Section map_branch.
  Context {term term' : Type}.
  Context (f : term -> term').

  Definition map_branch (b : branch term) :=
  {| bcontext := map_context f b.(bcontext);
      bbody := f b.(bbody) |}.

  Lemma map_bbody (b : branch term) :
    f (bbody b) = bbody (map_branch b).
  Proof. reflexivity. Qed.
  
  Lemma map_bcontext (b : branch term) :
    map_context f (bcontext b) = bcontext (map_branch b).
  Proof. reflexivity. Qed.
End map_branch.

Definition map_branches {term B} (f : term -> B) l := List.map (map_branch f) l.

Section map_branch_k.
  Context {term term' : Type}.
  Context (f : nat -> term -> term').

  Definition map_branch_k k (b : branch term) :=
  {| bcontext := mapi_context (shiftf f k) b.(bcontext);
      bbody := f (#|b.(bcontext)| + k) b.(bbody) |}.

  Lemma map_k_bbody k (b : branch term) :
    f (#|b.(bcontext)| + k) (bbody b) = bbody (map_branch_k k b).
  Proof. reflexivity. Qed.
  
  Lemma map_k_bcontext k (b : branch term) :
    mapi_context (shiftf f k) (bcontext b) = bcontext (map_branch_k k b).
  Proof. reflexivity. Qed.
End map_branch_k.

Notation map_branches_k f k brs :=
  (List.map (map_branch_k f k) brs).

Notation test_branches_k test k brs :=
  (List.forallb (test_branch_k test k) brs).

Inductive term :=
| tRel (n : nat)
| tVar (i : ident) (* For free variables (e.g. in a goal) *)
| tEvar (n : nat) (l : list term)
| tSort (u : Universe.t)
| tProd (na : aname) (A B : term)
| tLambda (na : aname) (A t : term)
| tLetIn (na : aname) (b B t : term) (* let na := b : B in t *)
| tApp (u v : term)
| tConst (k : kername) (ui : Instance.t)
| tInd (ind : inductive) (ui : Instance.t)
| tConstruct (ind : inductive) (n : nat) (ui : Instance.t)
| tCase (indn : case_info) (p : predicate term) (c : term) (brs : list (branch term))
| tProj (p : projection) (c : term)
| tFix (mfix : mfixpoint term) (idx : nat)
| tCoFix (mfix : mfixpoint term) (idx : nat)
(** We use faithful models of primitive type values in PCUIC *)
| tPrim (prim : prim_val term).

Derive NoConfusion for term.

Notation prim_val := (prim_val term).

Fixpoint mkApps t us :=
  match us with
  | nil => t
  | u :: us => mkApps (tApp t u) us
  end.

Definition isApp t :=
  match t with
  | tApp _ _ => true
  | _ => false
  end.

Definition isLambda t :=
  match t with
  | tLambda _ _ _ => true
  | _ => false
  end.

(** ** Entries

  The kernel accepts these inputs and typechecks them to produce
  declarations. Reflects [kernel/entries.mli].
*)

(** *** Constant and axiom entries *)

Record parameter_entry := {
  parameter_entry_type      : term;
  parameter_entry_universes : universes_decl }.

Record definition_entry := {
  definition_entry_type      : term;
  definition_entry_body      : term;
  definition_entry_universes : universes_decl;
  definition_entry_opaque    : bool }.

Inductive constant_entry :=
| ParameterEntry  (p : parameter_entry)
| DefinitionEntry (def : definition_entry).

Derive NoConfusion for parameter_entry definition_entry constant_entry.

(** *** Inductive entries *)

(** This is the representation of mutual inductives.
    nearly copied from [kernel/entries.mli]

  Assume the following definition in concrete syntax:

[[
  Inductive I1 (x1:X1) ... (xn:Xn) : A1 := c11 : T11 | ... | c1n1 : T1n1
  ...
  with      Ip (x1:X1) ... (xn:Xn) : Ap := cp1 : Tp1  ... | cpnp : Tpnp.
]]

  then, in [i]th block, [mind_entry_params] is [xn:Xn;...;x1:X1];
  [mind_entry_arity] is [Ai], defined in context [x1:X1;...;xn:Xn];
  [mind_entry_lc] is [Ti1;...;Tini], defined in context
  [A'1;...;A'p;x1:X1;...;xn:Xn] where [A'i] is [Ai] generalized over
  [x1:X1;...;xn:Xn].
*)

Inductive local_entry :=
| LocalDef : term -> local_entry (* local let binding *)
| LocalAssum : term -> local_entry.

Record one_inductive_entry := {
  mind_entry_typename : ident;
  mind_entry_arity : term;
  mind_entry_template : bool; (* template polymorphism *)
  mind_entry_consnames : list ident;
  mind_entry_lc : list term (* constructor list *) }.

Record mutual_inductive_entry := {
  mind_entry_record    : option (option ident);
  (* Is this mutual inductive defined as a record?
     If so, is it primitive, using binder name [ident]
     for the record in primitive projections ? *)
  mind_entry_finite    : recursivity_kind;
  mind_entry_params    : list (ident * local_entry);
  mind_entry_inds      : list one_inductive_entry;
  mind_entry_universes : universes_decl;
  mind_entry_private   : option bool
  (* Private flag for sealing an inductive definition in an enclosing
     module. Not handled by Template Coq yet. *) }.

Derive NoConfusion for local_entry one_inductive_entry mutual_inductive_entry.

(** Basic operations on the AST: lifting, substitution and tests for variable occurrences. *)

Fixpoint lift n k t : term :=
  match t with
  | tRel i => tRel (if Nat.leb k i then (n + i) else i)
  | tEvar ev args => tEvar ev (List.map (lift n k) args)
  | tLambda na T M => tLambda na (lift n k T) (lift n (S k) M)
  | tApp u v => tApp (lift n k u) (lift n k v)
  | tProd na A B => tProd na (lift n k A) (lift n (S k) B)
  | tLetIn na b t b' => tLetIn na (lift n k b) (lift n k t) (lift n (S k) b')
  | tCase ind p c brs =>
    let p' := map_predicate_k id (lift n) k p in
    let brs' := map_branches_k (lift n) k brs in
    tCase ind p' (lift n k c) brs'
  | tProj p c => tProj p (lift n k c)
  | tFix mfix idx =>
    let k' := List.length mfix + k in
    let mfix' := List.map (map_def (lift n k) (lift n k')) mfix in
    tFix mfix' idx
  | tCoFix mfix idx =>
    let k' := List.length mfix + k in
    let mfix' := List.map (map_def (lift n k) (lift n k')) mfix in
    tCoFix mfix' idx
  | x => x
  end.

Notation lift0 n := (lift n 0).

(** Parallel substitution: it assumes that all terms in the substitution live in the
    same context *)

Fixpoint subst s k u :=
  match u with
  | tRel n =>
    if Nat.leb k n then
      match nth_error s (n - k) with
      | Some b => lift0 k b
      | None => tRel (n - List.length s)
      end
    else tRel n
  | tEvar ev args => tEvar ev (List.map (subst s k) args)
  | tLambda na T M => tLambda na (subst s k T) (subst s (S k) M)
  | tApp u v => tApp (subst s k u) (subst s k v)
  | tProd na A B => tProd na (subst s k A) (subst s (S k) B)
  | tLetIn na b ty b' => tLetIn na (subst s k b) (subst s k ty) (subst s (S k) b')
  | tCase ind p c brs =>
    let p' := map_predicate_k id (subst s) k p in
    let brs' := map_branches_k (subst s) k brs in
    tCase ind p' (subst s k c) brs'
  | tProj p c => tProj p (subst s k c)
  | tFix mfix idx =>
    let k' := List.length mfix + k in
    let mfix' := List.map (map_def (subst s k) (subst s k')) mfix in
    tFix mfix' idx
  | tCoFix mfix idx =>
    let k' := List.length mfix + k in
    let mfix' := List.map (map_def (subst s k) (subst s k')) mfix in
    tCoFix mfix' idx
  | x => x
  end.

(** Substitutes [t1 ; .. ; tn] in u for [Rel 0; .. Rel (n-1)] *in parallel* *)
Notation subst0 t := (subst t 0).
Definition subst1 t k u := subst [t] k u.
Notation subst10 t := (subst1 t 0).
Notation "M { j := N }" := (subst1 N j M) (at level 10, right associativity).

Fixpoint closedn k (t : term) : bool :=
  match t with
  | tRel i => Nat.ltb i k
  | tEvar ev args => List.forallb (closedn k) args
  | tLambda _ T M | tProd _ T M => closedn k T && closedn (S k) M
  | tApp u v => closedn k u && closedn k v
  | tLetIn na b t b' => closedn k b && closedn k t && closedn (S k) b'
  | tCase ind p c brs =>
    let p' := test_predicate_k (fun _ => true) closedn k p in
    let brs' := test_branches_k closedn k brs in
    p' && closedn k c && brs'
  | tProj p c => closedn k c
  | tFix mfix idx =>
    let k' := List.length mfix + k in
    List.forallb (test_def (closedn k) (closedn k')) mfix
  | tCoFix mfix idx =>
    let k' := List.length mfix + k in
    List.forallb (test_def (closedn k) (closedn k')) mfix
  | x => true
  end.

Notation closed t := (closedn 0 t).

Fixpoint noccur_between k n (t : term) : bool :=
  match t with
  | tRel i => Nat.ltb i k || Nat.leb (k + n) i
  | tEvar ev args => List.forallb (noccur_between k n) args
  | tLambda _ T M | tProd _ T M => noccur_between k n T && noccur_between (S k) n M
  | tApp u v => noccur_between k n u && noccur_between k n v
  | tLetIn na b t b' => noccur_between k n b && noccur_between k n t && noccur_between (S k) n b'
  | tCase ind p c brs =>
    let p' := test_predicate_k (fun _ => true) (fun k' => noccur_between k' n) k p in
    let brs' := test_branches_k (fun k => noccur_between k n) k brs in
    p' && noccur_between k n c && brs'
  | tProj p c => noccur_between k n c
  | tFix mfix idx =>
    let k' := List.length mfix + k in
    List.forallb (test_def (noccur_between k n) (noccur_between k' n)) mfix
  | tCoFix mfix idx =>
    let k' := List.length mfix + k in
    List.forallb (test_def (noccur_between k n) (noccur_between k' n)) mfix
  | x => true
  end.
    
(** * Universe substitution

  Substitution of universe levels for universe level variables, used to
  implement universe polymorphism. *)

Instance subst_instance_constr : UnivSubst term :=
  fix subst_instance_constr u c {struct c} : term :=
  match c with
  | tRel _ | tVar _ => c
  | tEvar ev args => tEvar ev (List.map (subst_instance_constr u) args)
  | tSort s => tSort (subst_instance_univ u s)
  | tConst c u' => tConst c (subst_instance_instance u u')
  | tInd i u' => tInd i (subst_instance_instance u u')
  | tConstruct ind k u' => tConstruct ind k (subst_instance_instance u u')
  | tLambda na T M => tLambda na (subst_instance_constr u T) (subst_instance_constr u M)
  | tApp f v => tApp (subst_instance_constr u f) (subst_instance_constr u v)
  | tProd na A B => tProd na (subst_instance_constr u A) (subst_instance_constr u B)
  | tLetIn na b ty b' => tLetIn na (subst_instance_constr u b) (subst_instance_constr u ty)
                                (subst_instance_constr u b')
  | tCase ind p c brs =>
    let p' := map_predicate (subst_instance_instance u) (subst_instance_constr u) (subst_instance_constr u) p in
    let brs' := List.map (map_branch (subst_instance_constr u)) brs in
    tCase ind p' (subst_instance_constr u c) brs'
  | tProj p c => tProj p (subst_instance_constr u c)
  | tFix mfix idx =>
    let mfix' := List.map (map_def (subst_instance_constr u) (subst_instance_constr u)) mfix in
    tFix mfix' idx
  | tCoFix mfix idx =>
    let mfix' := List.map (map_def (subst_instance_constr u) (subst_instance_constr u)) mfix in
    tCoFix mfix' idx
  | tPrim _ => c
  end.

(** Tests that the term is closed over [k] universe variables *)
Fixpoint closedu (k : nat) (t : term) : bool :=
  match t with
  | tSort univ => closedu_universe k univ
  | tInd _ u => closedu_instance k u
  | tConstruct _ _ u => closedu_instance k u
  | tConst _ u => closedu_instance k u
  | tRel i => true
  | tEvar ev args => forallb (closedu k) args
  | tLambda _ T M | tProd _ T M => closedu k T && closedu k M
  | tApp u v => closedu k u && closedu k v
  | tLetIn na b t b' => closedu k b && closedu k t && closedu k b'
  | tCase ind p c brs =>
    let p' := test_predicate (closedu_instance k) (closedu k) p in
    let brs' := forallb (test_branch (closedu k)) brs in
    p' && closedu k c && brs'
  | tProj p c => closedu k c
  | tFix mfix idx =>
    forallb (test_def (closedu k) (closedu k)) mfix
  | tCoFix mfix idx =>
    forallb (test_def (closedu k) (closedu k)) mfix
  | x => true
  end.

Module PCUICTerm <: Term.

  Definition term := term.

  Definition tRel := tRel.
  Definition tSort := tSort.
  Definition tProd := tProd.
  Definition tLambda := tLambda.
  Definition tLetIn := tLetIn.
  Definition tInd := tInd.
  Definition tProj := tProj.
  Definition mkApps := mkApps.

  Definition lift := lift.
  Definition subst := subst.
  Definition closedn := closedn.
  Definition noccur_between := noccur_between.
  Definition subst_instance_constr := subst_instance.
End PCUICTerm.

Ltac unf_term := unfold PCUICTerm.term in *; unfold PCUICTerm.tRel in *;
                 unfold PCUICTerm.tSort in *; unfold PCUICTerm.tProd in *;
                 unfold PCUICTerm.tLambda in *; unfold PCUICTerm.tLetIn in *;
                 unfold PCUICTerm.tInd in *; unfold PCUICTerm.tProj in *;
                 unfold PCUICTerm.lift in *; unfold PCUICTerm.subst in *;
                 unfold PCUICTerm.closedn in *; unfold PCUICTerm.noccur_between in *;
                 unfold PCUICTerm.subst_instance_constr in *.
                 
(* These functors derive the notion of local context and lift substitution, term lifting, 
  the closed predicate to them. *)                 
Module PCUICEnvironment := Environment PCUICTerm.
Export PCUICEnvironment.
(* Do NOT `Include` this module, as this would sadly duplicate the rewrite database... *)

Lemma context_assumptions_mapi_context f (ctx : context) : 
  context_assumptions (mapi_context f ctx) = context_assumptions ctx.
Proof. 
  now rewrite mapi_context_fold; len.
Qed.
Hint Rewrite context_assumptions_mapi_context : len.

Module PCUICEnvTyping := EnvironmentTyping.EnvTyping PCUICTerm PCUICEnvironment.
(** Included in PCUICTyping only *)

Definition lookup_minductive Σ mind :=
  match lookup_env Σ mind with
  | Some (InductiveDecl decl) => Some decl
  | _ => None
  end.

Definition lookup_inductive Σ ind :=
  match lookup_minductive Σ (inductive_mind ind) with
  | Some mdecl => 
    match nth_error mdecl.(ind_bodies) (inductive_ind ind) with
    | Some idecl => Some (mdecl, idecl)
    | None => None
    end
  | None => None
  end.

Definition lookup_constructor Σ ind k :=
  match lookup_inductive Σ ind with
  | Some (mdecl, idecl) => 
    match nth_error idecl.(ind_ctors) k with
    | Some cdecl => Some (mdecl, idecl, cdecl)
    | None => None
    end
  | _ => None
  end.
  
Global Instance context_reflect`(ReflectEq term) : 
  ReflectEq (list (BasicAst.context_decl term)) := _.

Local Ltac finish :=
  let h := fresh "h" in
  right ;
  match goal with
  | e : ?t <> ?u |- _ =>
    intro h ; apply e ; now inversion h
  end.

Local Ltac fcase c :=
  let e := fresh "e" in
  case c ; intro e ; [ subst ; try (left ; reflexivity) | finish ].

Definition string_of_predicate {term} (f : term -> string) (p : predicate term) :=
  "(" ^ "(" ^ String.concat "," (map f (pparams p)) ^ ")" 
  ^ "," ^ string_of_universe_instance (puinst p)
  ^ ",(" ^ String.concat "," (map (string_of_name ∘ binder_name ∘ decl_name) (pcontext p)) ^ ")"
  ^ "," ^ f (preturn p) ^ ")".

Definition eqb_predicate_gen (eqb_univ_instance : Instance.t -> Instance.t -> bool)
  (eqdecl : context_decl -> context_decl -> bool)
  (eqterm : term -> term -> bool) (p p' : predicate term) :=
  forallb2 eqterm p.(pparams) p'.(pparams) &&
  eqb_univ_instance p.(puinst) p'.(puinst) &&
  forallb2 eqdecl p.(pcontext) p'.(pcontext) &&
  eqterm p.(preturn) p'.(preturn).

(** Syntactic equality *)

Definition eqb_predicate (eqterm : term -> term -> bool) (p p' : predicate term) :=
  eqb_predicate_gen eqb (eqb_context_decl eqterm) eqterm p p'.
  
(** Theory of [map] variants on branches and predicates. *)

(* The [map] rewrite database gathers all the map composition rewrite lemmas
  on these types. *)
Hint Rewrite map_map_compose @compose_map_def map_length : map.
Hint Rewrite @forallb_map : map.

Lemma map_predicate_map_predicate
      {term term' term''}
      (finst finst' : Instance.t -> Instance.t)
      (f g : term' -> term'')
      (f' g' : term -> term')
      (p : predicate term) :
  map_predicate finst f g (map_predicate finst' f' g' p) =
  map_predicate (finst ∘ finst') (f ∘ f') (g ∘ g') p.
Proof.
  unfold map_predicate. destruct p; cbn.
  f_equal.
  apply map_map.
  rewrite map_map.
  apply map_ext => x.
  now rewrite compose_map_decl.
Qed.

Lemma map_predicate_id x : map_predicate (@id _) (@id term) (@id term) x = id x.
Proof.
  unfold map_predicate; destruct x; cbn; unfold id.
  f_equal. apply map_id.
  now rewrite map_decl_id map_id.
Qed.
Hint Rewrite @map_predicate_id : map.

Definition ondecl {A} (P : A -> Type) (d : BasicAst.context_decl A) :=
  P d.(decl_type) × option_default P d.(decl_body) unit. 
  
Notation onctx P := (All (ondecl P)).

Definition onctx_k (P : nat -> term -> Type) k (ctx : context) :=
  Alli (fun i d => ondecl (P (Nat.pred #|ctx| - i + k)) d) 0 ctx.

Lemma ondeclP {P : term -> Type} {p : term -> bool} {d : context_decl} :
  (forall x, reflectT (P x) (p x)) ->
  reflectT (ondecl P d) (test_decl p d).
Proof.
  intros hr.
  rewrite /ondecl /test_decl; destruct d; cbn.
  destruct (hr decl_type) => //;
  destruct (reflect_option_default hr decl_body) => /= //; now constructor.
Qed.

Lemma onctxP {p : term -> bool} {ctx : context} :
  reflectT (onctx p ctx) (test_context p ctx).
Proof.
  eapply equiv_reflectT.
  - induction 1; simpl; auto. rewrite IHX /= //.
    now move/(ondeclP reflectT_pred): p0.
  - induction ctx.
    * constructor.
    * move => /= /andb_and [Hctx Hd]; constructor; eauto.
      now move/(ondeclP reflectT_pred): Hd.
Qed.
  
Definition tCasePredProp_k
            (P : nat -> term -> Type)
            k (p : predicate term) :=
  All (P k) p.(pparams) × onctx_k P k p.(pcontext) ×
  P (#|p.(pcontext)| + k) p.(preturn).

Definition tCasePredProp {term}
            (Pparams Preturn : term -> Type)
            (p : predicate term) :=
  All Pparams p.(pparams) ×
  onctx Pparams p.(pcontext) ×
  Preturn p.(preturn).

Lemma map_predicate_eq_spec {A B} (finst finst' : Instance.t -> Instance.t) 
  (f f' g g' : A -> B) (p : predicate A) :
  finst (puinst p) = finst' (puinst p) ->
  map f (pparams p) = map g (pparams p) ->
  map_context f (pcontext p) = map_context g (pcontext p) ->
  f' (preturn p) = g' (preturn p) ->
  map_predicate finst f f' p = map_predicate finst' g g' p.
Proof.
  intros. unfold map_predicate; f_equal; auto.
Qed.
Hint Resolve map_predicate_eq_spec : all.

Lemma map_predicate_k_eq_spec {A} (finst finst' : Instance.t -> Instance.t) 
  (f g : nat -> A -> A) k k' (p : predicate A) :
  finst (puinst p) = finst' (puinst p) ->
  map (f k) (pparams p) = map (g k') (pparams p) ->
  mapi_context (shiftf f k) (pcontext p) = mapi_context (shiftf g k') (pcontext p) ->
  shiftf f k #|pcontext p| (preturn p) = shiftf g k' #|pcontext p| (preturn p) ->
  map_predicate_k finst f k p = map_predicate_k finst' g k' p.
Proof.
  intros. unfold map_predicate_k; f_equal; auto.
Qed.
Hint Resolve map_predicate_k_eq_spec : all.

Lemma map_decl_id_spec P f d :
  ondecl P d ->
  (forall x : term, P x -> f x = x) ->
  map_decl f d = d.
Proof.
  intros Hc Hf.
  destruct Hc.
  unfold map_decl; destruct d; cbn in *. f_equal; eauto.
  destruct decl_body; simpl; eauto. f_equal.
  eauto.
Qed.

Lemma map_decl_id_spec_cond P p f d :
  ondecl P d ->
  test_decl p d ->
  (forall x : term, P x -> p x -> f x = x) ->
  map_decl f d = d.
Proof.
  intros [].
  unfold map_decl; destruct d; cbn in *.
  unfold test_decl; simpl. 
  intros [pty pbody]%andb_and. intros Hx.
  f_equal; eauto.
  destruct decl_body; simpl; eauto. f_equal.
  eauto.
Qed.

Lemma map_context_id_spec P f ctx :
  onctx P ctx ->
  (forall x : term, P x -> f x = x) ->
  map_context f ctx = ctx.
Proof.
  intros Hc Hf. induction Hc; simpl; auto.
  rewrite IHHc. f_equal; eapply map_decl_id_spec; eauto. 
Qed.
Hint Resolve map_context_id_spec : all.

Lemma map_context_id_spec_cond P p f ctx :
  onctx P ctx ->
  test_context p ctx ->
  (forall x : term, P x -> p x -> f x = x) ->
  map_context f ctx = ctx.
Proof.
  intros Hc Hc' Hf. induction Hc in Hc' |- *; simpl; auto.
  revert Hc'; simpl; intros [hx hl]%andb_and.
  rewrite IHHc; auto. f_equal. eapply map_decl_id_spec_cond; eauto. 
Qed.
Hint Resolve map_context_id_spec_cond : all.

Lemma map_context_map (f : term -> term) g (ctx : context) :
  map_context f (map g ctx) = map (map_decl f ∘ g) ctx.
Proof.
  induction ctx; simpl; f_equal; auto.
Qed.
Hint Rewrite map_context_map : map.

Lemma map_map_context {A} (f : context_decl -> A) (g : term -> term) (ctx : context) :
  map f (map_context g ctx) = map (f ∘ map_decl g) ctx.
Proof.
  now rewrite /map_context map_map_compose.
Qed.
Hint Rewrite @map_map_context : map.

Lemma map_predicate_id_spec {A} finst (f f' : A -> A) (p : predicate A) :
  finst (puinst p) = puinst p ->
  map f (pparams p) = pparams p ->
  map_context f (pcontext p) = pcontext p ->
  f' (preturn p) = preturn p ->
  map_predicate finst f f' p = p.
Proof.
  unfold map_predicate.
  intros -> -> -> ->; destruct p; auto.
Qed.
Hint Resolve map_predicate_id_spec : all.

Lemma map_predicate_k_id_spec {A} finst (f : nat -> A -> A) k (p : predicate A) :
  finst (puinst p) = puinst p ->
  map (f k) (pparams p) = pparams p ->
  mapi_context (shiftf f k) (pcontext p) = pcontext p ->
  shiftf f k #|p.(pcontext)| (preturn p) = preturn p ->
  map_predicate_k finst f k p = p.
Proof.
  unfold map_predicate_k, shiftf.
  intros -> -> -> ->; destruct p; auto.
Qed.
Hint Resolve map_predicate_k_id_spec : all.

Instance map_predicate_proper {term} : 
  Proper (`=1` ==> `=1` ==> Logic.eq ==> Logic.eq)%signature (@map_predicate term term id).
Proof.
  intros eqf0 eqf1 eqf.
  intros eqf'0 eqf'1 eqf'.
  intros x y ->.
  apply map_predicate_eq_spec; auto.
  now apply map_ext => x.
  now rewrite eqf.
Qed.

Instance map_predicate_proper' {term} f : Proper (`=1` ==> Logic.eq ==> Logic.eq)
  (@map_predicate term term id f).
Proof.
  intros eqf0 eqf1 eqf.
  intros x y ->.
  apply map_predicate_eq_spec; auto.
Qed.

Lemma map_fold_context_k f g ctx : map (map_decl f) (fold_context_k g ctx) = fold_context_k (fun i => f ∘ g i) ctx.
Proof.
  rewrite !fold_context_k_alt map_mapi. 
  apply mapi_ext => i d. now rewrite compose_map_decl.
Qed.
Hint Rewrite map_fold_context_k : map.
 
Lemma mapi_context_map (f : nat -> term -> term) g (ctx : context) :
  mapi_context f (map g ctx) = mapi (fun i => map_decl (f (Nat.pred #|ctx| - i)) ∘ g) ctx.
Proof.
  rewrite mapi_context_fold fold_context_k_alt mapi_map. now len.
Qed.
Hint Rewrite mapi_context_map : map.
 
Lemma mapi_context_map_context (f : nat -> term -> term) g (ctx : context) :
  mapi_context f (map_context g ctx) = 
  mapi_context (fun i => f i ∘ g) ctx.
Proof.
  now rewrite !mapi_context_fold fold_context_k_map.
Qed.
Hint Rewrite mapi_context_map_context : map.

Lemma map_context_mapi_context (f : term -> term) (g : nat -> term -> term) (ctx : context) :
  map_context f (mapi_context g ctx) = 
  mapi_context (fun i => f ∘ g i) ctx.
Proof.
  rewrite !mapi_context_fold. now unfold map_context; rewrite map_fold_context_k.
Qed.
Hint Rewrite map_context_mapi_context : map.

Lemma map_mapi_context {A} (f : context_decl -> A) (g : nat -> term -> term) (ctx : context) :
  map f (mapi_context g ctx) = mapi (fun i => f ∘ map_decl (g (Nat.pred #|ctx| - i))) ctx.
Proof.
  now rewrite mapi_context_fold fold_context_k_alt map_mapi.
Qed.
Hint Rewrite @map_mapi_context : map.

Lemma shiftf0 {A B} (f : nat -> A -> B) : shiftf f 0 =2 f.
Proof. intros x. unfold shiftf. now rewrite Nat.add_0_r. Qed.

Hint Rewrite @shiftf0 : map.

Lemma map_predicate_k_map_predicate_k 
  (finst finst' : Instance.t -> Instance.t)
  (f f' : nat -> term -> term)
  k k' (p : predicate term) :
  map_predicate_k finst f k (map_predicate_k finst' f' k' p) =
  map_predicate_k (finst ∘ finst') (fun i => f (i + k) ∘ f' (i + k')) 0 p.
Proof.
  unfold map_predicate, map_predicate_k. destruct p; cbn.
  f_equal.
  now rewrite map_map.
  now rewrite !mapi_context_fold fold_context_k_compose shiftf0.
  now len.
Qed.
Hint Rewrite map_predicate_k_map_predicate_k : map.

Lemma map_predicate_map_predicate_k 
  (finst finst' : Instance.t -> Instance.t)
  (f : term -> term) (f' : nat -> term -> term) 
  k (p : predicate term) :
  map_predicate finst f f (map_predicate_k finst' f' k p) =
  map_predicate_k (finst ∘ finst') (fun k => f ∘ f' k) k p.
Proof.
  unfold map_predicate, map_predicate_k. destruct p; cbn.
  f_equal.
  apply map_map.
  rewrite !mapi_context_fold map_fold_context_k.
  reflexivity.
Qed.
Hint Rewrite map_predicate_map_predicate_k : map.

Lemma map_predicate_k_map_predicate
  (finst finst' : Instance.t -> Instance.t)
  (f' : term -> term) (f : nat -> term -> term) 
  k (p : predicate term) :
  map_predicate_k finst f k (map_predicate finst' f' f' p) =
  map_predicate_k (finst ∘ finst') (fun k => (f k) ∘ f') k p.
Proof.
  unfold map_predicate, map_predicate_k. destruct p; cbn.
  f_equal; len; auto.
  * apply map_map.
  * rewrite !mapi_context_fold.
    fold (map_context f' pcontext0).
    now rewrite fold_context_k_map.
Qed.
Hint Rewrite map_predicate_k_map_predicate : map.

Lemma map_branch_map_branch
      {term term' term''}
      (f : term' -> term'')
      (f' : term -> term')
      (b : branch term) :
  map_branch f (map_branch f' b) =
  map_branch (f ∘ f') b.
Proof.
  unfold map_branch; destruct b; cbn.
  f_equal.
  rewrite map_map.
  now setoid_rewrite compose_map_decl.
Qed.
Hint Rewrite @map_branch_map_branch : map.

Lemma map_branch_k_map_branch_k (f f' : nat -> term -> term) k k' (b : branch term) :
  map_branch_k f k (map_branch_k f' k' b) =
  map_branch_k (fun i => f (i + k) ∘ f' (i + k')) 0 b.
Proof.
  unfold map_branch, map_branch_k; destruct b; cbn. len.
  f_equal.
  rewrite !mapi_context_fold.
  now rewrite !fold_context_k_compose shiftf0.
Qed.
Hint Rewrite map_branch_k_map_branch_k : map.

Lemma map_branch_map_branch_k
      (f : term -> term)
      (f' : nat -> term -> term) k
      (b : branch term) :
  map_branch f (map_branch_k f' k b) =
  map_branch_k (fun k => f ∘ (f' k)) k b.
Proof.
  unfold map_branch, map_branch_k; destruct b; cbn.
  f_equal.
  now rewrite !mapi_context_fold map_fold_context_k.
Qed.

Hint Rewrite map_branch_map_branch_k : map.
Lemma map_branch_k_map_branch
      (f' : term -> term)
      (f : nat -> term -> term) k
      (b : branch term) :
  map_branch_k f k (map_branch f' b) =
  map_branch_k (fun k => f k ∘ f') k b.
Proof.
  unfold map_branch, map_branch_k; destruct b; cbn. len.
  f_equal.
  rewrite !mapi_context_fold.
  now fold (map_context f' bcontext0); rewrite fold_context_k_map.
Qed.

Hint Rewrite map_branch_k_map_branch : map.

Lemma map_branch_id x : map_branch (@id term) x = id x.
Proof.
  unfold map_branch, id; destruct x; cbn.
  f_equal. now rewrite map_decl_id map_id.
Qed.
Hint Rewrite @map_branch_id : map.

Lemma map_decl_eq_spec {A B} {P : A -> Type} {d} {f g : A -> B} :
  ondecl P d ->
  (forall x, P x -> f x = g x) ->
  map_decl f d = map_decl g d.
Proof.
  destruct d; cbn; intros [Pty Pbod] Hfg.
  unfold map_decl; cbn in *; f_equal.
  * destruct decl_body; cbn in *; eauto. f_equal.
    eauto. 
  * eauto.
Qed.

Lemma map_context_eq_spec {A B} P (f g : A -> B) ctx :
  onctx P ctx ->
  (forall x, P x -> f x = g x) ->
  map_context f ctx = map_context g ctx.
Proof.
  intros onc Hfg.
  induction onc; simpl; auto.
  rewrite IHonc. f_equal.
  eapply map_decl_eq_spec; eauto.
Qed.

Lemma map_branch_eq_spec {A B} (f g : A -> B) (x : branch A) :
  map_context f (bcontext x) = map_context g (bcontext x) ->  
  f (bbody x) = g (bbody x) ->
  map_branch f x = map_branch g x.
Proof.
  intros. unfold map_branch; f_equal; auto.
Qed.
Hint Resolve map_branch_eq_spec : all.

Lemma map_branch_k_eq_spec {A B} (f g : nat -> A -> B) k k' (x : branch A) :
  mapi_context (shiftf f k) (bcontext x) = mapi_context (shiftf g k') (bcontext x) ->  
  shiftf f k #|x.(bcontext)| (bbody x) = shiftf g k' #|x.(bcontext)| (bbody x) ->
  map_branch_k f k x = map_branch_k g k' x.
Proof.
  intros. unfold map_branch_k; f_equal; auto.
Qed.
Hint Resolve map_branch_eq_spec : all.

Instance map_branch_proper {term} : Proper (`=1` ==> Logic.eq ==> Logic.eq) 
  (@map_branch term term).
Proof.
  intros eqf0 eqf1 eqf.
  intros x y ->.
  apply map_branch_eq_spec; auto.
  now rewrite eqf.
Qed.

Lemma map_context_id (ctx : context) : map_context id ctx = ctx.
Proof.
  unfold map_context.
  now rewrite map_decl_id map_id.
Qed.

Lemma map_branch_id_spec (f : term -> term) (x : branch term) :
  map_context f (bcontext x) = bcontext x ->
  f (bbody x) = (bbody x) ->
  map_branch f x = x.
Proof.
  intros. rewrite (map_branch_eq_spec _ id); auto.
  now rewrite map_context_id.
  now rewrite map_branch_id.
Qed.
Hint Resolve map_branch_id_spec : all.

Lemma map_branch_k_id_spec (f : nat -> term -> term) k (x : branch term) :
  mapi_context (shiftf f k) (bcontext x) = bcontext x ->
  shiftf f k #|x.(bcontext)| (bbody x) = (bbody x) ->
  map_branch_k f k x = x.
Proof.
  intros. unfold map_branch_k.
  destruct x; simpl in *; f_equal; eauto.
Qed.
Hint Resolve map_branch_k_id_spec : all.

Lemma map_branches_map_branches
      {term term' term''}
      (f : term' -> term'')
      (f' : term -> term')
      (l : list (branch term)) :
  map (fun b => map_branch f (map_branch f' b)) l =
  map (map_branch (f ∘ f')) l.
Proof.
  eapply map_ext => b. apply map_branch_map_branch.
Qed.

Definition tCaseBrsProp {A} (P : A -> Type) (l : list (branch A)) :=
  All (fun x => onctx P (bcontext x) × P (bbody x)) l.

Definition tCaseBrsProp_k (P : nat -> term -> Type) k (l : list (branch term)) :=
  All (fun x => onctx_k P k (bcontext x) × P (#|x.(bcontext)| + k) (bbody x)) l.

Lemma map_branches_k_map_branches_k
      {term term' term''}
      (f : nat -> term' -> term'')
      (g : term -> term')
      (f' : nat -> term -> term') k
      (l : list (branch term)) :
  map (fun b => map_branch (f #|bcontext (map_branch g b)|) (map_branch (f' k) b)) l =
  map (fun b => map_branch (f #|bcontext b|) (map_branch (f' k) b)) l.
Proof.
  eapply map_ext => b. rewrite map_branch_map_branch.
  rewrite map_branch_map_branch.
  now simpl; autorewrite with len.
Qed.

Lemma case_brs_map_spec {A B} {P : A -> Type} {l} {f g : A -> B} :
  tCaseBrsProp P l -> (forall x, P x -> f x = g x) ->
  map_branches f l = map_branches g l.
Proof.
  intros. red in X.
  eapply All_map_eq. eapply All_impl; eauto. simpl; intros.
  destruct X0.
  apply map_branch_eq_spec; eauto.
  eapply map_context_eq_spec; eauto.
Qed.

Lemma map_decl_eqP_spec {A B} {P : A -> Type} {p : A -> bool}
   {d} {f g : A -> B} :
  ondecl P d ->
  test_decl p d -> 
  (forall x, P x -> p x -> f x = g x) ->
  map_decl f d = map_decl g d.
Proof.
  destruct d; cbn; intros [Pty Pbod] [pty pbody]%andb_and Hfg.
  unfold map_decl; cbn in *; f_equal.
  * destruct decl_body; cbn in *; eauto. f_equal.
    eauto. 
  * eauto.
Qed.

Lemma map_context_eqP_spec {A B} {P : A -> Type} {p : A -> bool}
   {ctx} {f g : A -> B} :
  All (ondecl P) ctx ->
  test_context p ctx -> 
  (forall x, P x -> p x -> f x = g x) ->
  map_context f ctx = map_context g ctx.
Proof.
  intros Ha Hctx Hfg. induction Ha; simpl; auto.
  revert Hctx; simpl; intros [Hx Hl]%andb_and.
  rewrite IHHa; f_equal; auto.
  eapply map_decl_eqP_spec; eauto.
Qed.

Lemma mapi_context_eqP_spec {A B} {P : A -> Type} {ctx} {f g : nat -> A -> B} :
  All (ondecl P) ctx ->
  (forall k x, P x -> f k x = g k x) ->
  mapi_context f ctx = mapi_context g ctx.
Proof.
  intros Ha Hfg. induction Ha; simpl; auto.
  rewrite IHHa; f_equal.
  destruct p as [Hty Hbody].
  unfold map_decl; destruct x ; cbn in *; f_equal.
  * destruct decl_body; cbn in *; auto.
    f_equal. eauto.
  * eauto.
Qed.

Lemma mapi_context_eqP_id_spec {A} {P : A -> Type} {ctx} {f : nat -> A -> A} :
  All (ondecl P) ctx ->
  (forall k x, P x -> f k x = x) ->
  mapi_context f ctx = ctx.
Proof.
  intros Ha Hfg. induction Ha; simpl; auto.
  rewrite IHHa; f_equal.
  destruct p as [Hty Hbody].
  unfold map_decl; destruct x ; cbn in *; f_equal.
  * destruct decl_body; cbn in *; auto.
    f_equal. eauto.
  * eauto.
Qed.

Lemma mapi_context_eqP_test_id_spec {A} {P : A -> Type} (p : nat -> A -> bool)
  k {ctx} {f : nat -> A -> A} :
  All (ondecl P) ctx ->
  test_context_k p k ctx ->
  (forall k (x : A), P x -> p k x -> f k x = x) ->
  mapi_context (shiftf f k) ctx = ctx.
Proof.
  intros Ha ht Hfg. revert ht.
  induction Ha; simpl; auto.
  intros [hl [hty hbod]%andb_and]%andb_and.
  rewrite IHHa; auto; f_equal.
  destruct p0 as [Hty Hbody].
  unfold map_decl; destruct x ; cbn in *; f_equal; eauto.
  destruct decl_body; cbn in *; auto.
  f_equal. unfold shiftf. eapply Hfg; auto. 
Qed.

Lemma test_context_k_eqP_id_spec {A} {P : A -> Type} (p q : nat -> A -> bool) k k' {ctx} :
  All (ondecl P) ctx ->
  test_context_k p k ctx ->
  (forall i (x : A), P x -> p (i + k) x -> q (i + k') x) ->
  test_context_k q k' ctx.
Proof.
  intros Ha ht Hfg. revert ht.
  induction Ha; simpl; auto.
  intros [hl [hty hbod]%andb_and]%andb_and.
  rewrite IHHa; simpl; auto.
  destruct p0 as [Hty Hbody].
  unfold test_decl; destruct x ; cbn in *; eauto.
  destruct decl_body; cbn in *; auto.
  rewrite !Hfg; auto.
Qed.

Lemma test_context_k_eqP_eq_spec {A} {P : A -> Type} (p q : nat -> A -> bool) k k' {ctx} :
  All (ondecl P) ctx ->
  (forall i (x : A), P x -> p (i + k) x = q (i + k') x) ->
  test_context_k p k ctx = test_context_k q k' ctx.
Proof.
  intros Ha Hfg.
  induction Ha; simpl; auto.
  rewrite IHHa; auto; f_equal.
  destruct p0 as [Hty Hbody].
  unfold test_decl; destruct x ; cbn in *; f_equal; eauto.
  destruct decl_body; cbn in *; auto;
  rewrite !Hfg; auto.
Qed.

Lemma test_context_k_eq_spec (p q : nat -> term -> bool) k k' {ctx} :
  (p =2 q) ->
  k = k' ->
  test_context_k p k ctx = test_context_k q k' ctx.
Proof.
  intros Hfg <-.
  induction ctx as [|[na [b|] ty] ctx]; simpl; auto; now rewrite IHctx Hfg.
Qed.

Lemma test_context_k_eq (p : nat -> term -> bool) n ctx : 
  test_context_k p n ctx = alli (fun k d => test_decl (p (n + k)) d) 0 (List.rev ctx).
Proof.
  induction ctx; simpl; auto.
  rewrite IHctx alli_app /= andb_comm andb_true_r andb_comm. f_equal.
  len. now rewrite Nat.add_comm.
Qed.

Instance test_context_k_Proper : Proper (`=2` ==> Logic.eq ==> `=1`) (@test_context_k term).
Proof.
  intros f g Hfg k k' <- ctx.
  now apply test_context_k_eq_spec.
Qed.

Instance test_predicate_k_Proper : Proper (`=1` ==> `=2` ==> Logic.eq ==> `=1`) (@test_predicate_k term).
Proof.
  intros hi hi' eqhi f g Hfg k k' <- ctx.
  unfold test_predicate_k. rewrite eqhi.
  now setoid_rewrite Hfg.
Qed.

Instance test_branch_k_Proper : Proper (`=2` ==> Logic.eq ==> `=1`) (@test_branch_k term).
Proof.
  intros f g Hfg k k' <- ctx.
  unfold test_branch_k.
  now setoid_rewrite Hfg.
Qed.

Lemma case_brs_map_spec_cond {A B} {P : A -> Type} p {l} {f g : A -> B} :
  tCaseBrsProp P l -> 
  forallb (test_branch p) l ->
  (forall x, P x -> p x -> f x = g x) ->
  map_branches f l = map_branches g l.
Proof.
  intros. red in X. 
  eapply forallb_All in H.
  eapply All_map_eq.
  eapply All_prod in X; tea. clear H.
  eapply All_impl; eauto. simpl; intros br [[]%andb_and []].
  apply map_branch_eq_spec; eauto.
  eapply map_context_eqP_spec; eauto.
Qed.

Lemma case_brs_map_k_spec {A B} {P : A -> Type} {k l} {f g : nat -> A -> B} :
  tCaseBrsProp P l ->
  (forall k x, P x -> f k x = g k x) ->
  map_branches_k f k l = map_branches_k g k l.
Proof.
  intros. red in X.
  eapply All_map_eq. eapply All_impl; eauto. simpl; intros.
  destruct X0 as [Hctx Hbod].
  apply map_branch_k_eq_spec; eauto.
  apply (mapi_context_eqP_spec Hctx).
  intros k' x' hx'. unfold shiftf. now apply H.
Qed.

Lemma case_brs_forallb_map_spec {A B} {P : A -> Type} {p : A -> bool}
      {l} {f g : A -> B} :
  tCaseBrsProp P l ->
  forallb (test_branch p) l ->
  (forall x, P x -> p x -> f x = g x) ->
  map (map_branch f) l = map (map_branch g) l.
Proof.
  intros.
  eapply All_map_eq. red in X. apply forallb_All in H.
  eapply All_impl. eapply All_prod. exact X. exact H. simpl.
  intros [bctx bbod] [[Hbctx Hbr] [Hctx hb]%andb_and]. cbn in *.
  unfold map_branch; cbn. f_equal.
  - eapply map_context_eqP_spec; eauto. 
  - eapply H0; eauto.
Qed.

Lemma test_context_map (p : term -> bool) f (ctx : context) :
  test_context p (map_context f ctx) = test_context (p ∘ f) ctx.
Proof.
  induction ctx; simpl; auto.
  rewrite IHctx. f_equal.
  now rewrite test_decl_map_decl.
Qed.
Hint Rewrite test_context_map : map.

Lemma onctx_test P (p q : term -> bool) ctx : 
  onctx P ctx ->
  test_context p ctx ->
  (forall t, P t -> p t -> q t) -> 
  test_context q ctx.
Proof.
  intros Hc tc HP. revert tc.
  induction Hc; simpl; auto.
  destruct p0.
  intros [pl [pbod pty]%andb_and]%andb_and.
  rewrite (IHHc pl); simpl.
  unfold test_decl.
  rewrite (HP _ p0 pty) andb_true_r; simpl.
  destruct (decl_body x); simpl in *; eauto.
Qed.

(** Useful for inductions *)
Lemma onctx_k_rev {P : nat -> term -> Type} {k} {ctx} :
  onctx_k P k ctx <~>
  Alli (fun i => ondecl (P (i + k))) 0 (List.rev ctx).
Proof.
  split.
  - unfold onctx_k.
    intros Hi.
    eapply forall_nth_error_Alli => i x hx.
    pose proof (nth_error_Some_length hx).
    rewrite nth_error_rev // in hx.
    rewrite List.rev_involutive in hx.
    len in hx.
    eapply Alli_nth_error in Hi; tea.
    simpl in Hi. simpl.
    replace (Nat.pred #|ctx| - (#|ctx| - S i) + k) with (i + k) in Hi => //.
    len in H; by lia.
  - intros Hi.
    eapply forall_nth_error_Alli => i x hx.
    eapply Alli_rev_nth_error in Hi; tea.
    simpl.
    replace (#|ctx| - S i + k) with (Nat.pred #|ctx| - i + k) in Hi => //.
    lia.
Qed.

Lemma onctx_k_shift {P : nat -> term -> Type} {k} {ctx} :
  onctx_k P k ctx ->
  onctx_k (fun k' => P (k' + k)) 0 ctx.
Proof.
  intros Hi%onctx_k_rev.
  eapply onctx_k_rev.
  eapply Alli_impl; tea => /= n x.
  now rewrite Nat.add_0_r.
Qed.

Lemma onctx_k_P {P : nat -> term -> Type} {p : nat -> term -> bool} {k} {ctx : context} :
  (forall x y, reflectT (P x y) (p x y)) ->
  reflectT (onctx_k P k ctx) (test_context_k p k ctx).
Proof.
  intros HP.
  eapply equiv_reflectT.
  - intros Hi%onctx_k_rev.
    rewrite test_context_k_eq.
    induction Hi; simpl; auto.
    rewrite Nat.add_comm.
    rewrite IHHi /= //.
    now move/(ondeclP (HP _)): p0 => ->.
  - intros Hi. eapply onctx_k_rev.
    move: ctx Hi. induction ctx.
    * constructor.
    * move => /= /andb_and [Hctx Hd].
      eapply Alli_app_inv; eauto. constructor.
      + move/(ondeclP (HP _)): Hd. now len.
      + constructor.
Qed.

Module PCUICLookup := EnvironmentTyping.Lookup PCUICTerm PCUICEnvironment.
Include PCUICLookup.

Derive NoConfusion for global_decl.
