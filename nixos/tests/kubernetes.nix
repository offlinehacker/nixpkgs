# This test runs kubernetes and checks single and multy node scenarios

import ./make-test.nix rec {
  name = "kubernetes";

  redisMaster = builtins.toFile "redis-master-pod.yaml" ''
      id: redis-master-pod
      kind: Pod
      apiVersion: v1beta1
      desiredState:
        manifest:
          version: v1beta1
          id: redis-master-pod
          containers:
            - name: master
              image: master:5000/scratch
              cpu: 100
              ports:
                - name: redis-server
                  containerPort: 6379
                  hostPort: 6379
              volumeMounts:
                - name: nix-store
                  mountPath: /nix/store
                  readOnly: true
              volumeMounts:
                - name: system-profile
                  mountPath: /bin
                  readOnly: true
              command:
                - /bin/redis-server
          volumes:
            - name: nix-store
              source:
                hostDir:
                  path: /nix/store
            - name: system-profile
              source:
                hostDir:
                  path: /run/current-system/sw/bin
      labels:
        name: redis
        role: master
  '';

  nodes = {
    master =
      { config, pkgs, nodes, ... }:
        {
          virtualisation.kubernetes = {
            roles = ["master" "node"];
            controllerManager.machines = ["master" "node"];
            kubelet.address = "0.0.0.0";
            kubelet.extraOpts = "-network_container_image=master:5000/pause";
            apiserver.address = "0.0.0.0";
          };
          virtualisation.docker.extraOptions = "--iptables=false --ip-masq=false -b cbr0 --insecure-registry master:5000";

          services.etcd = {
            listenPeerUrls = ["http://0.0.0.0:7001"];
            listenClientUrls = ["http://127.0.0.1:4001"];
            initialAdvertisePeerUrls = ["http://master:7001"];
            initialCluster = ["master=http://master:7001" "node=http://node:7001"];
          };
          services.dockerRegistry.enable = true;
          services.dockerRegistry.host = "0.0.0.0";
          services.dockerRegistry.port = 5000;

          virtualisation.vlans = [ 1 2 ];
          networking.bridges = {
            cbr0.interfaces = [ "eth2" ];
          };
          networking.interfaces = {
            cbr0 = {
              ipAddress = "10.10.0.1";
              prefixLength = 24;
            };
          };
          networking.localCommands = ''
            ip route add 10.10.0.0/16 dev cbr0
            ip route flush cache
          '';

          networking.firewall.enable = false;
          #networking.firewall.allowedTCPPorts = [ 4001 7001 ];

          environment.systemPackages = [ pkgs.redis ];
        };

    node =
      { config, pkgs, nodes, ... }:
        {
          virtualisation.kubernetes = {
            roles = ["node" "master"];
            kubelet.address = "0.0.0.0";
            kubelet.extraOpts = "-network_container_image=master:5000/pause";
          };
          virtualisation.docker.extraOptions = "--iptables=false --ip-masq=false -b cbr0 --insecure-registry master:5000";
          services.etcd = {
            listenPeerUrls = ["http://0.0.0.0:7001"];
            listenClientUrls = ["http://127.0.0.1:4001"];
            initialAdvertisePeerUrls = ["http://node:7001"];
            initialCluster = ["master=http://master:7001" "node=http://node:7001"];
          };

          virtualisation.vlans = [ 1 2 ];
          networking.bridges = {
            cbr0.interfaces = [ "eth2" ];
          };
          networking.interfaces = {
            cbr0 = {
              ipAddress = "10.10.1.1";
              prefixLength = 24;
            };
          };
          networking.localCommands = ''
            ip route add 10.10.0.0/16 dev cbr0
            ip route flush cache
          '';

          networking.firewall.enable = false;
          #networking.firewall.allowedTCPPorts = [ 4001 7001 ];

          environment.systemPackages = [ pkgs.redis ];
        };

    client =
      { config, pkgs, nodes, ... }:
        {
          virtualisation.docker.enable = true;
          virtualisation.docker.extraOptions = "--insecure-registry master:5000";
          environment.systemPackages = [ pkgs.kubernetes ];
          environment.etc."test/redis-master-pod.yaml".source = redisMaster;
          environment.etc."test/pause".source = "${pkgs.kubernetes}/libexec/kubernetes/pause";
          environment.etc."test/Dockerfile".source = pkgs.writeText "Dockerfile" ''
            FROM scratch
            ADD pause /
            ENTRYPOINT ["/pause"]
          '';
        };
  };

  testScript = ''
    startAll;

    $client->waitForUnit("docker.service");
    $master->waitForUnit("docker-registry.service");
    $client->succeed("tar cv --files-from /dev/null | docker import - scratch");
    $client->succeed("docker tag scratch master:5000/scratch");
    $client->succeed("docker push master:5000/scratch");
    $client->succeed("mkdir /root/pause");
    $client->succeed("cp /etc/test/pause /root/pause");
    $client->succeed("cp /etc/test/Dockerfile /root/pause");
    $client->succeed("docker build -t master:5000/pause /root/pause");
    $client->succeed("docker push master:5000/pause");

    $master->waitForUnit("kubernetes-apiserver.service");
    $master->waitForUnit("kubernetes-scheduler.service");
    $master->waitForUnit("kubernetes-controller-manager.service");
    $master->waitForUnit("kubernetes-kubelet.service");
    $master->waitForUnit("kubernetes-proxy.service");

    $node->waitForUnit("kubernetes-kubelet.service");
    $node->waitForUnit("kubernetes-proxy.service");

    $master->waitUntilSucceeds("kubecfg get minions/master");
    $master->waitUntilSucceeds("kubecfg get minions/node");

    subtest "simple pod", sub {
      $client->succeed("kubectl create -f ${redisMaster} -s http://master:8080");
      $client->succeed("kubectl get pods -s http://master:8080 | grep redis-master | grep Running");
      $node->waitUntilSucceeds("docker ps -a | grep redis");
    }

  '';
}
