{
  forrSelf = final: prev: {
    erlangPackages = prev.beam.packagesWith prev.erlang_28;
    erlang = final.erlangPackages.erlang;
    elixir = final.erlangPackages.elixir_1_17;

    mixRelease = final.erlangPackages.mixRelease.override {
      elixir = final.elixir;
    };
    fetchMixDeps = final.erlangPackages.fetchMixDeps.override {
      elixir = final.elixir;
    };

    elixir-ls = prev.elixir-ls.override {elixir = final.elixir;};
  };
}
