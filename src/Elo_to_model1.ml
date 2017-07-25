(** Provides a converter from Electrod models to (part of) a solver
    model.  *)

open Containers

module Make
    (Ltl : Solver.LTL)
    (ConvertFormulas : Elo_to_LTL_intf.S
     with type ltl = Ltl.t and type atomic = Ltl.atomic)
    (Model : Solver.MODEL
     with type ltl = ConvertFormulas.ltl
      and type atomic = ConvertFormulas.atomic) =
struct

  (* Compute an LTL formula and the list of atomic propositions from a
     list of symmetries *)
  let syms_to_ltl elo =
    let open Elo in
    let open Ltl in
    let syms = elo.sym in
    let dom = elo.domain in
    let sym_to_ltl (sym : Symmetry.t) =
      Symmetry.fold
        (fun (name1, tuple1) (name2, tuple2)
             ((rigid_atoms_acc, flex_atoms_acc, fml_acc)
              : atomic Sequence.t *atomic Sequence.t* Ltl.t)
         ->         
          (*We assume that a symmetry is well-formed (each pair of
          name tuple share the same name) *)         
          if not (Name.equal name1 name2) then
            assert false
          else           
            let name_is_const =
              Domain.get_exn name1 dom |> Relation.is_const
            in
            let at1 = make_atomic name1 tuple1 in
            let at_fml1 =  atomic at1 in
            let at2 = make_atomic name2 tuple2 in
            let at_fml2 = atomic at2 in
            if name_is_const then
              (Sequence.cons at1 (Sequence.cons at2 rigid_atoms_acc),
               flex_atoms_acc,
               or_ (implies at_fml1 (lazy at_fml2))
                   (lazy (and_ (iff at_fml1 at_fml2) (lazy fml_acc))))
            else
              (rigid_atoms_acc,
               Sequence.cons at1 (Sequence.cons at2 flex_atoms_acc),
               or_ (implies at_fml1 (lazy at_fml2))
                   (lazy (and_ (iff at_fml1 at_fml2) (lazy fml_acc))))
        )
        sym
        (Sequence.empty, Sequence.empty, true_)
    in
    List.fold_left
      (fun (rigid_atoms_acc, flex_atoms_acc, fmls_acc) sym ->
        let (cur_rigid_atoms, cur_flex_atoms, cur_fml) = sym_to_ltl sym in
        (Sequence.append cur_rigid_atoms rigid_atoms_acc,
         Sequence.append cur_flex_atoms flex_atoms_acc,
         Sequence.cons cur_fml fmls_acc))
      (Sequence.empty, Sequence.empty, Sequence.empty)
      syms

  
  let run elo =
    let open Elo in
    (* #781 Handle instance:

       To handle the instance, one possibility would be to update the bound
       computation (bounds_exp) and [build_Ident].

       However, apparently, we won't need to differentiate the domain and the
       instance in the future. So we take the simpler path that consists in
       updating the domain itself. As this is confined to the following
       functions, we do this for the time being. If the need arises, a
       refactoring won't be too painful. *)
    let elo =
      Elo.{ elo with
              domain = Domain.update_domain_with_instance elo.domain
                         elo.instance } in

    (* walk through formulas, convert them to LTL and accumulate rigid
       and flexible variables. TODO: replace sequences by sets. *)
    (* let exception Early_stop in *)
    let translate_formulas fmls =
      (* try *)
      List.fold_left
        (fun (acc_r, acc_f, acc_fml) fml ->
           let (r, f, ltl) = ConvertFormulas.convert elo fml in
           (* if ltl = Ltl.false_ then *)
           (*   raise Early_stop *)
           (* else *)
           (Sequence.append r acc_r,
            Sequence.append f acc_f,
            Sequence.cons ltl acc_fml))
        Sequence.(empty, empty, empty) fmls
        (* with *)
        (*   Early_stop -> Sequence.(empty, empty, Ltl.false_) *)
    in

    (* handling symmetries *)
    let (rigid_syms, flex_syms, syms_fmls) = syms_to_ltl elo in

    (* handling invariants *)
    let (rigid_inv, flex_inv, invars) = translate_formulas elo.Elo.invariants in


    (* handling the goal *)
    let goal_fml = match elo.goal with GenGoal.Run g | GenGoal.Check g -> g in
    let (rigid_goal, flex_goal, property) =
      ConvertFormulas.convert elo
      @@ GenGoal.(List.fold_left
                    (fun x y -> fml (Location.span (x.fml_loc, y.fml_loc))
                      @@ lbinary x and_ y)
                    (fml Location.dummy true_) goal_fml)
    in

    let rigid = Sequence.(append rigid_syms (append rigid_inv rigid_goal)) in
    let flexible = Sequence.(append flex_syms (append flex_goal flex_inv)) in 
    Model.make ~rigid ~flexible
      ~invariant:Sequence.(append invars syms_fmls) ~property

end

