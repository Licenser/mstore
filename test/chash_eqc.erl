-module(chash_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eunit/include/eunit.hrl").
-include("../include/mstore.hrl").

-import(mstore_heler, [int_array/0, float_array/0, pos_int/0, non_neg_int/0,
                       i_or_f_list/0, i_or_f_array/0,
                       non_empty_i_or_f_list/0, out/1]).

-compile(export_all).


size() ->
    ?LET(N, choose(1, 5), trunc(math:pow(2, N))).

chash() ->
    ?LET(N, size(),
         {N, chash:fresh(N, first)}).

size_prop() ->
    ?FORALL(N, non_neg_int(),
            try
                chash:size(chash:fresh(N, the_node)) == N
            catch
                _:_ ->
                    not (N > 1 andalso (N band (N - 1) =:= 0))
            end).

update_prop() ->
    ?FORALL({N, CHash}, chash(),
            ?FORALL(Pos, choose(1, N),
                    begin
                        {Index, _} = lists:nth(Pos, chash:nodes(CHash)),
                        CHash1 = chash:update(Index, new, CHash),
                        lists:keyfind(Index, 1, chash:nodes(CHash1)) == {Index, new} andalso
                            length([new || new <- chash:members(CHash1)]) == 1 andalso
                            chash:contains_name(new, CHash1) andalso
                            chash:contains_name(first, CHash1) andalso
                            not chash:contains_name(new, CHash)
                    end)).

successors_length_prop() ->
    ?FORALL({Rand, {N, CHash}}, {int(), chash()},
            ?FORALL(Picks, choose(1, N),
                    length(chash:successors(chash:key_of(Rand), CHash, Picks)) == Picks)).

inverse_pred_prop() ->
    ?FORALL({Rand, {_, CHash}}, {int(), chash()},
            begin
                Key = chash:key_of(Rand),
                S = [I || {I,_} <- chash:successors(Key, CHash)],
                P = [I || {I,_} <- chash:predecessors(Key,CHash)],
                S == lists:reverse(P)
            end).

next_index_prop() ->
    ?FORALL({Rand, {_, CHash}}, {int(), chash()},
            begin
                <<I:160/integer>> = chash:key_of(Rand),
                I1 = chash:next_index(I, CHash),
                I =< I1 orelse I1 == 0
            end).

predecessors_int_prop() ->
    ?FORALL({Rand, {_, CHash}}, {int(), chash()},
            begin
                B = <<I:160/integer>> = chash:key_of(Rand),
                chash:predecessors(B, CHash) == chash:predecessors(I, CHash)
            end).

run_test_() ->
    Props = [
             fun size_prop/0,
             fun update_prop/0,
             fun successors_length_prop/0,
             fun inverse_pred_prop/0,
             fun next_index_prop/0,
             fun predecessors_int_prop/0
            ],
    [
     begin
         P = out(Prop()),
         ?_assert(quickcheck(numtests(500,P)))
     end
     || Prop <- Props].