-module (rsa).

-export([make_sig/1, gen_keys/1, encrypt/2, decrypt/2, 
	decrypt_from_file/2, encrypt_to_file/3, save_key/3, load_key/2]).

-export ([init/0, init/1]).
% Returns a public and private key
init() ->
	application:start(crypto),
	{{A,N},{B,N}} = gen_keys(128),
	{A,B,N}.

init(Len) ->
	{{A,N},{B,N}} = gen_keys(Len),
	{A,B,N}.
	
gen_keys(Len) ->
	% make_sig(Len).
	A = 45045285646712350422756027992481719367460211547300585283059992642930083877444080280784746978717741244217982222789217924199197927411026193058436808573574516780861725055040129619731895206491336310721436947246396272958181409962791911315577752050055222923897,
	B = 779386634638912994267587225841964732798943132064854242497195385765915669035025091295553841796231295157007742299025077680522068332782415014928253545462665918080862118435995627473091849758502238720538262782675909732397163063189922465120071296754467259972401,
	N = 883813979280459083571612049809461829564448184007573612413566687611259529356205376882431351279482331004614263159616860328514053811386250012835323532416127205326788388165115483569961638911853361813913348944144646631425027454023854480199361068923362615456313,
	{{A,N},{B,N}}.
 
encrypt({N, E}, Msg) ->
	ListMess = case erlang:is_binary(Msg) of
		true -> erlang:binary_to_list(Msg);
		false -> Msg
	end,
	List = str2int(ListMess),
	% List = lists:reverse(ints_to_rxstr(ListMess)),
  crypto:mod_exp(List, E, N).

decrypt({N, D}, Msg) ->
	Decrypted = crypto:mod_exp(Msg, D, N),
	int2str(Decrypted).
	  
decrypt_from_file(Filename, Priv) ->
    {ok, [{ciphertext, Data}]} = file:consult(Filename),
    decrypt(Priv, Data).

encrypt_to_file(Filename, Pub, Msg) ->
    {ok, FP} = file:open(Filename, [write]),
    io:format(FP, "{ciphertext, ~p}.~n", [encrypt(Pub, Msg)]),
    file:close(FP).

save_key(Filename, Type, Key) ->
    {ok, FP} = file:open(Filename, [write]),
    io:format(FP, "{~p, ~p}.~n", [Type, Key]),
    file:close(FP).

load_key(Filename, Type) ->
    {ok, Terms} = file:consult(Filename),
    {value, {Type, Ret}} = lists:keysearch(Type, 1, Terms),
    Ret.

% make_sig(Who, Len) when Len > 79 ->
%     {{Pub,N},{Priv,N}}={Public, Private} = make_sig(Len),
%     file:write_file(Who ++ ".pub", term_to_binary(Public)),
%     file:write_file(Who ++ ".pri", term_to_binary(Private)),
%     D=str2int("asdfasdfasdfad"),
%     E=crypto:mod_exp(D,Priv,N),
%     F=crypto:mod_exp(E,Pub,N),
%     io:format("String ~p,~p~n",[int2str(F),F]),
%     {term_to_binary(Public),term_to_binary(Private)}.

make_sig(Len) ->
    %% generate two <Len> digit prime numbers
    P = primes:make_prime(Len),
    Q = primes:make_prime(Len),
    N = P*Q,
    Phi = (P-1)*(Q-1),
    %% now make B such that B < Phi and gcd(B, Phi) = 1
    B = b(Phi),
    A = inv(B, Phi),
    {{B,N},{A,N}}.

b(Phi) ->
    K = length(integer_to_list(Phi)) - 1,
    B = b(1, K, Phi),
    B.

b(Try, K, Phi) ->
    B = primes:make(K),
    if 
	B < Phi ->
	    case gcd(B, Phi) of
		1 -> B;
		_ -> b(Try+1, K, Phi)
	    end;
	true ->
	    b(Try, K, Phi)
    end.
%E tag1

inv(A, B) ->
    case solve(A, B) of
	{X, _Y} ->
	    if X < 0 -> X + B;
	       true  -> X
	    end;
	_ ->
	    no_inverse
    end.

%% greatest common denominator
gcd(A, B) when A < B -> gcd(B, A);
gcd(A, 0) -> A;
gcd(A, B) ->
    gcd(B, A rem B).



solve(A, B) ->
    case catch s(A,B) of
	insoluble -> insoluble;
	{X, Y} ->
	    case A * X - B * Y of
		1     -> {X, Y};
		_Other -> error
	    end
    end.

s(_A, 0)  -> throw(insoluble);
s(_A, 1)  -> {0, -1};
s(_A, -1) -> {0, 1};
s(A, B)  ->
    K1 = A div B,
    K2 = A - K1*B,
    {Tmp, X} = s(B, -K2),
    {X, K1 * X - Tmp}.


%% converts a string to a base 256 integer
%% converts a base 256 integer to a string

%S tag2    
str2int(Str) -> str2int(Str, 0).

str2int([H|T], N) -> str2int(T, N*256+H);
str2int([], N) -> N.

int2str(N) -> int2str(N, []).

int2str(N, L) when N =< 0 -> L;
int2str(N, L) ->
    N1 = N div 256,
    H = N - N1 * 256,
    int2str(N1, [H|L]).

digit_to_xchar(D) when (D >= 0) and (D < 10) ->
    D + 48;
digit_to_xchar(D) ->
    D + 87.
		
ints_to_rxstr([], Res) ->
    Res;
ints_to_rxstr([N | Ns], Res) ->
    ints_to_rxstr(Ns, [digit_to_xchar(N rem 16),
		       digit_to_xchar(N div 16) | Res]).