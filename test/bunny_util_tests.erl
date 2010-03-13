-module(bunny_util_tests).
%%
%% Tests
%%
-include_lib("gen_bunny.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(DEFAULT_USER, <<"guest">>).
-define(DEFAULT_PASS, <<"guest">>).
-define(DEFAULT_VHOST, <<"/">>).

%%
%% Message Helpers
%%

new_message_test() ->
    Foo = bunny_util:new_message(<<"Foo">>),
    ?assert(?is_message(Foo)),
    ?assertMatch(
       #content{payload_fragments_rev=[Payload]} when Payload =:= <<"Foo">>,
       Foo).


get_payload_test() ->
    Bar = #content{payload_fragments_rev=[<<"Bar">>]},
    ?assertEqual(<<"Bar">>, bunny_util:get_payload(Bar)).


set_delivery_mode_test() ->
    Foo = bunny_util:new_message(<<"Foo">>),
    FooModed = bunny_util:set_delivery_mode(Foo, 2),
    ?assertEqual((FooModed#content.properties)#'P_basic'.delivery_mode, 2).


get_delivery_mode_test() ->
    Msg = #content{properties=#'P_basic'{delivery_mode=2}},
    ?assertEqual(2, bunny_util:get_delivery_mode(Msg)).


set_content_type_test() ->
    Msg = bunny_util:new_message(<<"true">>),
    NewMsg = bunny_util:set_content_type(Msg, <<"application/json">>),
    ?assertEqual((NewMsg#content.properties)#'P_basic'.content_type,
                 <<"application/json">>).


get_content_type_test() ->
    Msg = #content{
      properties=#'P_basic'{content_type = <<"application/json">>}},
    ?assertEqual(<<"application/json">>, bunny_util:get_content_type(Msg)).


%%
%% Exchange Helpers
%%

new_exchange_test() ->
    Exchange = bunny_util:new_exchange(<<"Hello">>),
    ?assert(?is_exchange(Exchange)),
    ?assertMatch(#'exchange.declare'{exchange = <<"Hello">>,
                                     type = <<"direct">>}, Exchange).


new_exchange_with_type_test() ->
    Exchange = bunny_util:new_exchange(<<"Hello">>, <<"topic">>),
    ?assert(?is_exchange(Exchange)),
    ?assertMatch(#'exchange.declare'{exchange = <<"Hello">>,
                                     type = <<"topic">>}, Exchange).


get_type_test() ->
    ?assertEqual(<<"direct">>,
                 bunny_util:get_type(#'exchange.declare'{type = <<"direct">>})).


set_type_test() ->
    Exchange =bunny_util:new_exchange(<<"Hello">>),
    NewExchange = bunny_util:set_type(Exchange, <<"topic">>),

    ?assertMatch(#'exchange.declare'{exchange = <<"Hello">>,
                                     type = <<"topic">>}, NewExchange).


is_durable_exchange_test() ->
    ?assertEqual(true,
                 bunny_util:is_durable(#'exchange.declare'{durable=true})),
    ?assertEqual(false,
                 bunny_util:is_durable(#'exchange.declare'{durable=false})).


set_durable_exchange_test() ->
    Exchange = bunny_util:new_exchange(<<"Hello">>),
    NewExchange = bunny_util:set_durable(Exchange, true),
    ?assertEqual(true, NewExchange#'exchange.declare'.durable),

    NewExchange2 = bunny_util:set_durable(Exchange, false),
    ?assertEqual(false, NewExchange2#'exchange.declare'.durable).


%%
%% Queue helpers
%%


new_queue_test() ->
    Queue = bunny_util:new_queue(<<"Hello">>),
    ?assert(?is_queue(Queue)),
    ?assertMatch(#'queue.declare'{queue = <<"Hello">>}, Queue).


is_durable_queue_test() ->
    ?assertEqual(true,
                 bunny_util:is_durable(#'queue.declare'{durable=true})),
    ?assertEqual(false,
                 bunny_util:is_durable(#'queue.declare'{durable=false})).


set_durable_queue_test() ->
    Queue = bunny_util:new_queue(<<"Hello">>),
    NewQueue = bunny_util:set_durable(Queue, true),
    ?assertEqual(true, NewQueue#'queue.declare'.durable),

    NewQueue2 = bunny_util:set_durable(Queue, false),
    ?assertEqual(false, NewQueue2#'queue.declare'.durable).


%%
%% Connect helper
%%
connect_setup() ->
    {ok, _} = mock:mock(amqp_connection),
    ok.

connect_stop(_) ->
    mock:verify_and_stop(amqp_connection),
    ok.

direct_expects(ExpectedUser, ExpectedPass) ->
    mock:expects(amqp_connection, start_direct,
                 fun({#amqp_params{username=U, password=P}})
                       when U =:= ExpectedUser, P =:= ExpectedPass ->
                         true
                 end,
                 dummy_direct_conn),

    mock:expects(amqp_connection, open_channel,
                 fun({dummy_direct_conn}) ->
                         true
                 end,
                 dummy_direct_channel),
    ok.

network_expects(Host, Port, User, Pass, VHost) ->
    mock:expects(amqp_connection, start_network,
                 fun({#amqp_params{username=U,
                                   password=P0,
                                   host=H,
                                   port=P1,
                                   virtual_host=V}})
                     when U =:= User,
                          P0 =:= Pass,
                          H =:= Host,
                          P1 =:= Port,
                          V =:= VHost ->
                         true
                 end,
                 dummy_network_conn),

    mock:expects(amqp_connection, open_channel,
                 fun({dummy_network_conn}) ->
                         true
                 end,
                 dummy_network_channel),
    ok.


connect_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             direct_expects(?DEFAULT_USER, ?DEFAULT_PASS),

             ?assertEqual({ok, {dummy_direct_conn, dummy_direct_channel}}, bunny_util:connect())
         end])}.


connect_direct_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             direct_expects(?DEFAULT_USER, ?DEFAULT_PASS),
             ?assertEqual({ok, {dummy_direct_conn, dummy_direct_channel}},
                          bunny_util:connect(direct))
         end])}.


connect_direct_creds_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             direct_expects(<<"al">>, <<"franken">>),
             ?assertEqual({ok, {dummy_direct_conn, dummy_direct_channel}},
                          bunny_util:connect({direct, #amqp_params{
                                     username= <<"al">>,
                                     password= <<"franken">>}}))
         end])}.


connect_network_host_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             ?PROTOCOL_PORT,
                             ?DEFAULT_USER,
                             ?DEFAULT_PASS,
                             ?DEFAULT_VHOST),
             ?assertEqual({ok, {dummy_network_conn, dummy_network_channel}},
                          bunny_util:connect({network, "amqp.example.com"}))
         end])}.

connect_network_host_port_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             10000,
                             ?DEFAULT_USER,
                             ?DEFAULT_PASS,
                             ?DEFAULT_VHOST),
             ?assertEqual({ok, {dummy_network_conn, dummy_network_channel}},
                          bunny_util:connect(
                            {network, "amqp.example.com", 10000}))
         end])}.


connect_network_host_port_creds_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             10000,
                             "al",
                             "franken",
                             ?DEFAULT_VHOST),
             ?assertEqual({ok, {dummy_network_conn, dummy_network_channel}},
                          bunny_util:connect(
                            {network, "amqp.example.com", 10000,
                             {"al", "franken"}}))
         end])}.


connect_network_host_port_creds_vhost_test_() ->
    {setup, fun connect_setup/0, fun connect_stop/1,
     ?_test(
        [begin
             network_expects("amqp.example.com",
                             10000,
                             "al",
                             "franken",
                             <<"/awesome">>),
             ?assertEqual({ok, {dummy_network_conn, dummy_network_channel}},
                          bunny_util:connect(
                            {network, "amqp.example.com", 10000,
                             {"al", "franken"}, <<"/awesome">>}))
         end])}.

%%
%% Declare Tests
%%

declare_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    ok.


declare_stop(_) ->
    mock:verify_and_stop(amqp_channel),
    ok.


declare_expects(Exchange, Queue, Binding) ->
    QName = bunny_util:get_name(Queue),
    EName = bunny_util:get_name(Exchange),

    mock:expects(amqp_channel, call,
                 fun({dummy_channel, Q = #'queue.declare'{}})
                       when Q =:= Queue ->
                         true;

                    ({dummy_channel, E = #'exchange.declare'{}})
                       when E =:= Exchange ->
                         true;
                    ({dummy_channel, #'queue.bind'{queue=BQ,
                                                   exchange=BE,
                                                   routing_key=BK}})
                       when BQ =:= QName,
                            BE =:= EName,
                            BK =:= Binding->
                         true
                 end,
                 fun({dummy_channel, #'queue.declare'{}}, 2) ->
                         #'queue.declare_ok'{queue=QName};
                    ({dummy_channel, #'exchange.declare'{}}, 1) ->
                         #'exchange.declare_ok'{};
                    ({dummy_channel, #'queue.bind'{}}, 3) ->
                         #'queue.bind_ok'{}
                 end,
                 3),
    ok.



declare_everything_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(bunny_util:new_exchange(<<"Foo">>),
                             bunny_util:new_queue(<<"Foo">>),
                             <<"Foo">>),
             ?assertEqual({ok, {bunny_util:new_exchange(<<"Foo">>),
                                bunny_util:new_queue(<<"Foo">>)}},
                          bunny_util:declare(dummy_channel, <<"Foo">>))
         end])}.


declare_names_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(bunny_util:new_exchange(<<"Foo">>),
                             bunny_util:new_queue(<<"Bar">>),
                             <<"Baz">>),
             ?assertEqual({ok, {bunny_util:new_exchange(<<"Foo">>),
                                bunny_util:new_queue(<<"Bar">>)}},
                           bunny_util:declare(
                            dummy_channel,
                            {<<"Foo">>, <<"Bar">>, <<"Baz">>}))
         end])}.


declare_records_test_() ->
    {setup, fun declare_setup/0, fun declare_stop/1,
     ?_test(
        [begin
             declare_expects(bunny_util:new_exchange(<<"Foo">>),
                             bunny_util:new_queue(<<"Bar">>),
                             <<"Baz">>),
             ?assertEqual({ok, {bunny_util:new_exchange(<<"Foo">>),
                                bunny_util:new_queue(<<"Bar">>)}},
                          bunny_util:declare(
                            dummy_channel,
                            {bunny_util:new_exchange(<<"Foo">>),
                             bunny_util:new_queue(<<"Bar">>),
                             <<"Baz">>}))
         end])}.
