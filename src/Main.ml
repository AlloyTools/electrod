
(** {b Actual main function.} *)

open Containers




(* inspired by Logs_fmt code *)     
let keyword =
  let open Logs in
  function
    | App -> ""
    | Error -> "ERROR"
    | Warning -> "WARNING"
    | Info -> "INFO"
    | Debug -> "DEBUG"


let short =
  let open Logs in
  function
    | App -> ""
    | Error -> "E"
    | Warning -> "W"
    | Info -> "I"
    | Debug -> "D"



let pp_header ppf (l, h) =
  let open Logs in 
  let open Logs_fmt in
  let pp_h ppf style h = Fmtc.pf ppf "[%a] " Fmtc.(styled style string) h in
  match l with
    | App ->
        begin match h with
          | None -> ()
          | Some h -> Fmtc.pf ppf "[%a] " Fmtc.(styled app_style string) h
        end
    | Error
    | Warning
    | Info
    | Debug ->
        pp_h ppf (Msg.style l)
        @@ CCOpt.map_or ~default:(keyword l) (fun s -> short l ^ s) h




type tool =
  | NuXmv
  | NuSMV


let main style_renderer verbosity tool file scriptfile keep_files =
  Printexc.record_backtrace true;

  Fmt_tty.setup_std_outputs ?style_renderer ();

  Logs.set_reporter (Logs_fmt.reporter ~pp_header ());
  Logs.set_level ~all:true verbosity;

  Logs.app
    (fun m ->
       m "%a" Fmtc.(styled `Bold string) "electrod (C) 2016-2017 ONERA");

  Logs.app (fun m -> m "Processing file: %s" file);

  (try
     let inch = Unix.open_process_in "tput cols" in
     let cols =
       inch
       |> IO.read_line
       |> Fun.tap (fun _ -> ignore @@ Unix.close_process_in inch)
       |> Option.get_or ~default:"80"
       |> int_of_string in
     (* Msg.debug (fun m -> m "Columns: %d" cols); *)
     Format.(pp_set_margin stdout) cols;
     Format.(pp_set_margin stderr) cols
   with _ ->
     Msg.debug
       (fun m -> m "Columns not found, leaving terminal as is..."));

  (* begin work *)
  try
    let raw_to_elo_t = Transfo.tlist [ Raw_to_elo.transfo ] in
    let elo_to_elo_t = Transfo.tlist [ Simplify1.transfo; Simplify2.transfo ] in
    let elo_to_smv_t = Transfo.tlist
                         [ Elo_to_SMV1.transfo; (* Elo_to_SMV2.transfo *)] in

    let elo =
      Parser_main.parse_file file
      |> Fun.tap (fun _ -> Msg.info (fun m -> m "Parsing done"))
      |> Transfo.(get_exn raw_to_elo_t "raw_to_elo" |> run)
      |> Fun.tap (fun _ -> Msg.info (fun m -> m "Static analysis done"))
      (* |> Fun.tap (fun elo -> Msg.debug (fun m -> m "After raw_to_elo =@\n%a@." (Elo.pp) elo)) *)
      |> Transfo.(get_exn elo_to_elo_t "simplify1" |> run)
      |> Fun.tap (fun elo -> Msg.debug (fun m -> m "After simplify1 =@\n%a@." (Elo.pp) elo))
      |> Fun.tap (fun _ -> Msg.info (fun m -> m "Simplification done"))
    in
    let before_conversion = Mtime_clock.now () in
    let model =
      elo
      |> Transfo.(get_exn elo_to_smv_t "to_smv1" |> run) 
      |> Fun.tap (fun _ ->
            Msg.info (fun m ->
                  m "Conversion done in %a"
                    Mtime.Span.pp
                    (Mtime.span before_conversion @@ Mtime_clock.now ())
                ))
    in
    (* let sup_r = Domain.sup (Name.name "r") elo.domain in *)
    (* let tc_r = TupleSet.transitive_closure sup_r in *)
    (* Msg.debug (fun m -> *)
    (*     m "Borne sup de la tc de r : %a " TupleSet.pp tc_r); *)

    let cmd, script = match tool, scriptfile with
      | NuXmv, None -> ("nuXmv", Solver.Default SMV.nuXmv_default_script)
      | NuXmv, Some s -> ("nuXmv", Solver.File s)
      | NuSMV, None -> ("NuSMV", Solver.Default SMV.nuSMV_default_script)
      | NuSMV, Some s -> ("NuSMV", Solver.File s)
    in

    Msg.debug (fun m -> m "@.%a"
                          (Elo_to_SMV1.pp ~margin:78) model);

    Msg.info (fun m -> m "%a" Elo_to_SMV1.SMV_LTL.pp_hasconsing_assessment
                         (Elo_to_SMV1.SMV_LTL.pp));

    let res = Elo_to_SMV1.analyze ~cmd ~keep_files
                ~elo:elo ~script ~file model in
    Logs.app (fun m -> m "Analysis yields:@\n%a" Solver.pp_outcome res);

    Logs.app (fun m -> m "Elapsed (wall-clock) time: %a"
                         Mtime.Span.pp (Mtime_clock.elapsed ()))

  with
    | Exit ->
        Logs.app
          (fun m -> m "Aborting (%a)." Mtime.Span.pp (Mtime_clock.elapsed ()));
        exit 1
    | e ->
        raise e
      


