final: previous:

with final;
with lib;

let
  aorura = fetchFromGitHub {
    owner = "Holo-Host";
    repo = "aorura";
    rev = "2aef90935d6e965cf6ec02208f84e4b6f43221bd";
    sha256 = "00d9c6f0hh553hgmw01lp5639kbqqyqsz66jz35pz8xahmyk5wmw";
  };

  cargo-to-nix = fetchFromGitHub {
    owner = "transumption-unstable";
    repo = "cargo-to-nix";
    rev = "ba6adc0a075dfac2234e851b0d4c2511399f2ef0";
    sha256 = "1rcwpaj64fwz1mwvh9ir04a30ssg35ni41ijv9bq942pskagf1gl";
  };

  chaperone = fetchFromGitHub {
    owner = "Holo-Host";
    repo = "chaperone";
    rev = "2386e905dc60dbb2bff482b92d5fbeb418627931";
    sha256 = "02yxlqcgly3235pj6rb84px1my3ps3m5plk0nijazpiakndh2nxz";
  };

  gitignore = fetchFromGitHub {
    owner = "hercules-ci";
    repo = "gitignore";
    rev = "f9e996052b5af4032fe6150bba4a6fe4f7b9d698";
    sha256 = "0jrh5ghisaqdd0vldbywags20m2cxpkbbk5jjjmwaw0gr8nhsafv";
  };

  holo-router = fetchFromGitHub {
    owner = "Holo-Host";
    repo = "holo-router";
    rev = "f6c5be74307b29689d1d2bb939c9c5ca44c6ca91";
    sha256 = "0j9fpm51wr0lb22g7qsilmasb4gi21yyqscdgp3szk9bb5q83alq";
  };

  holochain-rust = fetchFromGitHub {
    owner = "holochain";
    repo = "holochain-rust";
    rev = "e33624e0e3cb23158212590ee89d6aaa7ca86e2e";
    sha256 = "1bjkl623r0y2ybibnxma2j1mp8rhr3zwav96f9jq34f2vqyw0vj8";
  };

  hp-admin = fetchFromGitHub {
    owner = "Holo-Host";
    repo = "hp-admin";
    rev = "4ae0f0cc28e199a5d8f4d23f2aa508aae2cf5111";
    sha256 = "1abna46da9av059kfy10ls0fa6ph8vhh75rh8cv3mvi96m2n06zd";
  };

  hp-admin-crypto = fetchFromGitHub {
    owner = "Holo-Host";
    repo = "hp-admin-crypto";
    rev = "690e3dbc7a49ecd31ab622b576001d93ce3de1ae";
    sha256 = "01ji3ybx46gyi5y99vrf72yman3azjwkdzhf79rsa81bsy2jb664";
  };

  hpos-config = fetchFromGitHub {
    owner = "Holo-Host";
    repo = "hpos-config";
    rev = "a64da0d9bc0ef87bc358fcdad6323b424cf4971b";
    sha256 = "1059lfr2vnacq3aghmir007vgql4za197xx2qlm732vhb6svgpma";
  };

  nixpkgs-mozilla = fetchTarball {
    url = "https://github.com/mozilla/nixpkgs-mozilla/archive/dea7b9908e150a08541680462fe9540f39f2bceb.tar.gz";
    sha256 = "0kvwbnwxbqhc3c3hn121c897m89d9wy02s8xcnrvqk9c96fj83qw";
  };

  npm-to-nix = fetchFromGitHub {
    owner = "transumption-unstable";
    repo = "npm-to-nix";
    rev = "6d2cbbc9d58566513019ae176bab7c2aeb68efae";
    sha256 = "1wm9f2j8zckqbp1w7rqnbvr8wh6n072vyyzk69sa6756y24sni9a";
  };
in

{
  inherit (callPackage aorura {})
    aorura-cli
    aorura-emu
    ;

  inherit (callPackage cargo-to-nix {})
    buildRustPackage
    cargoToNix
    ;

  inherit (callPackage chaperone {}) chaperone;

  inherit (callPackage gitignore {}) gitignoreSource;

  inherit (callPackage holo-router {})
    holo-router-agent
    holo-router-gateway
    ;

  inherit (callPackage hp-admin {})
    hp-admin-ui
    holofuel-ui
    ;

  inherit (callPackage hp-admin-crypto {}) hp-admin-crypto-server;

  inherit (callPackage hpos-config {})
    hpos-config-gen-cli
    hpos-config-gen-web
    hpos-config-into-base36-id
    hpos-config-into-keystore
    ;

  inherit (callPackage npm-to-nix {}) npmToNix;

  inherit (callPackage "${nixpkgs-mozilla}/package-set.nix" {}) rustChannelOf;

  buildDNA = makeOverridable (
    callPackage ./build-dna {
      inherit (rust.packages.nightly) rustPlatform;
    }
  );

  buildImage = imports:
    let
      system = nixos {
        inherit imports;
      };

      imageNames = filter (name: hasAttr name system) [
        "isoImage"
        "sdImage"
        "virtualBoxOVA"
        "vm"
      ];
    in
      head (attrVals imageNames system);

  mkJobsets = callPackage ./mk-jobsets {};

  mkRelease = src: platforms:
    let
      buildMatrix =
        lib.mapAttrs (_: pkgs: import src { inherit pkgs; }) platforms;
    in
      {
        aggregate = releaseTools.channel {
          name = "aggregate";
          inherit src;

          constituents = with lib;
            concatMap (collect isDerivation) (attrValues buildMatrix);
        };

        platforms = buildMatrix;
      };

  tryDefault = x: default:
    let
      eval = builtins.tryEval x;
    in
      if eval.success then eval.value else default;

  writeJSON = config: writeText "config.json" (builtins.toJSON config);

  writeTOML = config: runCommand "config.toml" {} ''
    ${remarshal}/bin/json2toml < ${writeJSON config} > $out
  '';

  dnaHash = dna: builtins.readFile (
    runCommand "${dna.name}-hash" {} ''
      ${holochain-cli}/bin/hc hash -p ${dna}/${dna.name}.dna.json \
        | tail -1 \
        | cut -d ' ' -f 3- \
        | tr -d '\n' > $out
    ''
  );

  dnaPackages = recurseIntoAttrs (
    import ./dna-packages final previous
  );

  inherit (callPackage holochain-rust {})
    holochain-cli
    holochain-conductor
    sim2h-server
    ;

  holo = recurseIntoAttrs {
    buildProfile = profile: buildImage [
      "${holo-nixpkgs.path}/profiles/logical/holo/${profile}"
      "${pkgs.path}/nixos/modules/virtualisation/qemu-vm.nix"
    ];

    hydra-master = holo.buildProfile "hydra/master";
    hydra-minion = holo.buildProfile "hydra/minion";
    router-gateway = holo.buildProfile "router-gateway";
    sim2h = holo.buildProfile "sim2h";
    wormhole-relay = holo.buildProfile "wormhole-relay";
  };

  holo-auth-client = callPackage ./holo-auth-client {
    stdenv = stdenvNoCC;
    python3 = python3.withPackages (ps: [ ps.requests ]);
  };

  holo-cli = callPackage ./holo-cli {};

  holo-nixpkgs.path = gitignoreSource ../..;

  holo-nixpkgs-tests = recurseIntoAttrs (
    import "${holo-nixpkgs.path}/tests" { inherit pkgs; }
  );

  holoport-nano-dtb = callPackage ./holoport-nano-dtb {
    linux = linux_latest;
  };

  hpos = recurseIntoAttrs {
    buildImage = imports:
      buildImage (imports ++ [ hpos.logical ]);

    logical = "${holo-nixpkgs.path}/profiles/logical/hpos";
    physical = "${holo-nixpkgs.path}/profiles/physical/hpos";

    qemu = (hpos.buildImage [ "${hpos.physical}/vm/qemu" ]) // {
      meta.platforms = [ "x86_64-linux" ];
    };

    virtualbox = (hpos.buildImage [ "${hpos.physical}/vm/virtualbox" ]) // {
      meta.platforms = [ "x86_64-linux" ];
    };
  };

  hpos-admin = callPackage ./hpos-admin {
    stdenv = stdenvNoCC;
    python3 = python3.withPackages (ps: [ ps.flask ps.gevent ]);
  };

  hpos-admin-client = callPackage ./hpos-admin-client {
    stdenv = stdenvNoCC;
    python3 = python3.withPackages (ps: [ ps.click ps.requests ]);
  };

  hpos-init = python3Packages.callPackage ./hpos-init {};

  hpos-led-manager = callPackage ./hpos-led-manager {
    inherit (rust.packages.nightly) rustPlatform;
  };

  hpstatus = fetchFromGitHub {
    owner = "Holo-Host";
    repo = "hpstatus";
    rev = "562c637f7fa370633998efa319ae1225d7241537";
    sha256 = "1wm744mavp7k9ajikzm3hg01byc58s9dfwsmy47j1mhzc0j0l2fr";
  };

  hydra = previous.hydra.overrideAttrs (
    super: {
      doCheck = false;
      patches = [
        ./hydra/logo-vertical-align.diff
        ./hydra/no-restrict-eval.diff
        ./hydra/secure-github.diff
      ];
      meta = super.meta // {
        hydraPlatforms = [ "x86_64-linux" ];
      };
    }
  );

  libsodium = previous.libsodium.overrideAttrs (
    super: {
      # Separate debug output breaks cross-compilation
      separateDebugInfo = false;
    }
  );

  linuxPackages_latest = previous.linuxPackages_latest.extend (
    self: super: {
      sun50i-a64-gpadc-iio = self.callPackage ./linux-packages/sun50i-a64-gpadc-iio {};
    }
  );

  magic-wormhole-mailbox-server = python3Packages.callPackage ./magic-wormhole-mailbox-server {};

  nodejs = nodejs-12_x;

  rust = previous.rust // {
    packages = previous.rust.packages // {
      nightly = {
        rustPlatform = final.makeRustPlatform {
          inherit (buildPackages.rust.packages.nightly) cargo rustc;
        };

        cargo = final.rust.packages.nightly.rustc;
        rustc = (
          rustChannelOf {
            channel = "nightly";
            date = "2019-07-14";
            sha256 = "1llbwkjkjis6rv0rbznwwl0j6bf80j38xgwsd4ilcf0qps4cvjsx";
          }
        ).rust.override {
          targets = [
            "aarch64-unknown-linux-musl"
            "wasm32-unknown-unknown"
            "x86_64-pc-windows-gnu"
            "x86_64-unknown-linux-musl"
          ];
        };
      };
    };
  };

  wrangler = callPackage ./wrangler {};

  wrapDNA = drv: runCommand (lib.removeSuffix ".dna.json" drv.name) {} ''
    install -Dm -x ${drv} $out/${drv.name}
  '';

  zerotierone = previous.zerotierone.overrideAttrs (
    super: {
      meta = with lib; super.meta // {
        platforms = platforms.linux;
        license = licenses.free;
      };
    }
  );
}
