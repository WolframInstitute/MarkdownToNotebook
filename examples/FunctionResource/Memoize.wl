(* Memoize[f] rewrites f so its results are cached. Results are stored in a private Association
   keyed on Hash[HoldComplete[args]], with the held arguments kept beside each result, so a hash
   collision recomputes instead of returning another call's value, and a verbatim Sequence or
   Unevaluated argument keeps a key of its own. Because the key is an integer hash and never a
   pattern, a call whose arguments contain Blank or Pattern is cached like any other, where
   storing it as a definition f[args] = value would define a rule that matches other calls.

   Memoize[f, crit] only caches calls for which crit[args] is True; crit is evaluated once,
   when Memoize is, and applied once on a cache miss (never on a hit), so an expensive
   criterion does not tax repeated reads, and Memoize[f] caches every call. The original
   definitions of f are kept as a dispatch table, and a miss applies them to the call itself
   with Replace, so the call matches with f's own attributes (Flat, Orderless and OneIdentity
   among them), options and defaults, and their bodies still call f, so recursion stays
   memoized. A call no definition answers stays a call of f and is not cached.

   Memoize holds its arguments, so it also takes the definitions themselves: Memoize[def], with
   def a Set, a SetDelayed or a CompoundExpression of them, makes the definitions and then
   memoizes each symbol they define at the top level, so `f[x_] := ...; // Memoize` caches f
   as it is defined. A definition whose left-hand side is headed by a System symbol, such as
   Options[f] = ... or f::tag = ..., is made but defines nothing to memoize. *)

SetAttributes[Memoize, HoldAll];

Memoize[f_Symbol, crit_ : (True &)] := With[{
    cache = Unique[f],
    unanswered = Unique[f],
    criterion = crit
},
    (* the original definitions, closed by a rule that marks a call none of them answers *)
    With[{rules = Dispatch[Append[DownValues[f], HoldPattern[_] :> unanswered]]},
        cache = <||>;
        ResourceFunction["BlockProtected"][{f},
            DownValues[f] = {
                HoldPattern[f[args___]] :> With[{held = HoldComplete[args]},
                    With[{key = Hash[held]},
                        With[{res = With[{hit = Lookup[cache, key, Missing[]]},
                            If[ ! MissingQ[hit] && First[hit] === held,
                                Last[hit],
                                With[{computed = Replace[Unevaluated[f[args]], rules]},
                                    (* a call no definition answers, a result FailureQ gives True
                                       for, and a call the criterion declines are never cached: an
                                       unanswered call is not a value, the Message side effects of a
                                       failure would be swallowed on a hit, and an abort is not an
                                       answer *)
                                    If[ computed =!= unanswered && ! FailureQ[computed] && TrueQ[criterion[args]],
                                        cache[key] = {held, computed}
                                    ];
                                    computed
                                ]
                            ]
                        ]},
                            res /; res =!= unanswered
                        ]
                    ]
                ]
            }
        ]
    ];
    f
]

Memoize[defs : _Set | _SetDelayed | _CompoundExpression, crit_ : (True &)] := With[{
    defined = DeleteDuplicates[definedSymbols[defs]]
},
    defs;
    Replace[
        Map[Replace[#, HoldComplete[f_] :> Memoize[f, crit]] &, defined],
        {f_} :> f
    ]
]

(* the symbols a definition, or a compound of definitions, defines at the top level, each
   wrapped in HoldComplete *)
SetAttributes[{definedSymbols, definedHead}, HoldAllComplete];
definedSymbols[CompoundExpression[defs___]] := Join @@ Map[definedSymbols, Unevaluated[{defs}]]
definedSymbols[(Set | SetDelayed)[lhs_, _]] := definedHead[lhs]
definedSymbols[_] := {}
definedHead[Verbatim[HoldPattern][lhs_]] := definedHead[lhs]
definedHead[Verbatim[Condition][lhs_, _]] := definedHead[lhs]
definedHead[(f_Symbol)[___]] /; Context[Unevaluated[f]] =!= "System`" := {HoldComplete[f]}
definedHead[_] := {}
