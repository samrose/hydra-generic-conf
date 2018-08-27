{ config,lib, pkgs, ... }:
{
  imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];

  ec2.hvm = true;

  services = {
    hydra = {
      enable = true;
      hydraURL = "http://ec2-13-58-169-56.us-east-2.compute.amazonaws.com"; # externally visible URL
      notificationSender = "hydra@holo.host"; # e-mail of hydra service
      # a standalone hydra will require you to unset the buildMachinesFiles list to avoid using a nonexistant /etc/nix/machines

      # you will probably also want, otherwise *everything* will be built from scratch
      useSubstitutes = true;
      listenHost = "127.0.0.1";
      port = 3000;
    };

    nginx = {
      enable = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "hydra.holo.yflower.de" = {
          addSSL = true;
          enableACME = true;
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:3000";
            };
            "/channels" = {
              alias = "/srv/channels";
              extraConfig = ''
                autoindex on;
              '';
            };
          };
        };
      };
    };
  };

  systemd.services = {
    "release-channel-master" = {
      requires = [ "hydra-server.service" ];
      after = [ "hydra-server.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = let py = pkgs.python3.withPackages (ps: [ ps.click ]); in ''
          ${py}/bin/python3 ${./scripts/release-channel.py} --target /srv/channels
        '';
      };
    };
  };

  systemd.timers = {
    "release-channel-master" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "minutely";
        Unit = "release-channel-master.service";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 22 ];

  nix.buildMachines = [
    {
      hostName = "localhost";
      system = "x86_64-linux";
      supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
      maxJobs = 2;
    }
  ];

  nix.gc.automatic = true;
  nix.gc.dates = "*:0/30";
  nix.gc.options = ''--max-freed "$((15 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))"'';
}
