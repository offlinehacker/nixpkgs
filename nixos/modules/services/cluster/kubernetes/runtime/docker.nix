{ config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.runtime.docker;

  infraContainer = pkgs.dockerTools.buildImage {
    name = "pause";
    tag = "latest";
    contents = top.package.pause;
    config.Cmd = "/bin/pause";
  };

in {

  ###### interface
  options.services.kubernetes.runtime.docker = {
    enable = mkEnableOption "Kubernetes docker runtime.";

    seedDockerImages = mkOption {
      description = "List of docker images to preload on system";
      default = [];
      type = types.listOf types.package;
    };
  };

  ###### implementation
  config = mkIf (top.kubelet.enable && cfg.enable) {
    users.users.kubernetes.extraGroups = [ "docker" ];

    services.kubernetes = {
      kubelet = {
        podInfraContainerImage = mkDefault "pause";
        path = [ pkgs.docker ];
      };

      # infra container (pause) is automatically preloaded, as it's needed for
      # running any pod
      runtime.docker.seedDockerImages = [ infraContainer ];
    };

    virtualisation.docker = {
      enable = mkDefault true;

      # kubernetes needs access to logs
      logDriver = mkDefault "json-file";

      # iptables must be disabled for kubernetes
      extraOptions = "--iptables=false --ip-masq=false";

      # auto prune should be disabled, as prune is already perfomed by
      # kubernetes
      autoPrune.enable = mkDefault false;
    };

    systemd.services.kube-docker-bootstrap = {
      wantedBy = [ "kube-runtime.target" ];
      after = [ "docker.service" ];
      path = with pkgs; [ docker ];
      script = ''
        ${concatMapStrings (img: ''
          echo "Seeding docker image: ${img}"
          docker load <${img}
        '') cfg.seedDockerImages}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Slice = "kubernetes.slice";
      };
    };

    # add docker to kube-runtime target
    systemd.services.docker = {
      wantedBy = [ "kube-runtime.target" ];
      before = [ "kube-runtime.target" ];
    };
  };
}
