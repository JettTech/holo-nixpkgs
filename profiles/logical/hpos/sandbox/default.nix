{
  imports = [ ../. ];

  services.holo-auth-client.enable = false;

  services.holo-router-agent.enable = false;

  services.holochain-conductor.config.network = {
    type = "sim2h";
    sim2h_url = "wss://localhost:9000";
  };

  services.hpos-init.enable = false;

  services.sim2h-server.enable = true;

  services.zerotierone.enable = false;

  system.holo-nixpkgs.autoUpgrade.enable = false;
}
