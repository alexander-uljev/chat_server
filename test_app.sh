CHAT_SERVER_MODE=local_multi \
mix test test/chat_server/chat_server_mix_test.exs \
--only env

mix test test/chat_server/chat_server_mix_test.exs \
--only cli -- --mode local_mono

mix test test/chat_server/chat_server_mix_test.exs \
--only destinations
