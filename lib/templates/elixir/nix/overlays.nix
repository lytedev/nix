{
  forSelf = final: prev: {
    erlang = prev.beam.packagesWith prev.beam.interpreters.erlang_27;
    elixir = final.erlang.elixir_1_17;
    mixRelease = final.erlang.mixRelease.override { elixir = final.elixir; };
    fetchMixDeps = final.erlang.fetchMixDeps.override { elixir = final.elixir; };
    elixir-ls = prev.elixir-ls.override { elixir = final.elixir; };
  };
}
