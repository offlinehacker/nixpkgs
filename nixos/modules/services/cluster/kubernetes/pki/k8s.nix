# pki integration with kubernetes components, this is put here, so k8s and pki
# are kept decoupled

{ config, lib, ... }:

with lib;

let
  top = config.services.kubernetes;
  pki = top.pki;

in {
  config = mkIf pki.enable {
    services.kubernetes = {
      pki.certs = {
        etcdServer = {
          enable = mkDefault config.services.etcd.enable;
          name = "etcd-server";
          kind = "server";
          csr = {
            CN = "etcd-server";
            hosts = [ "127.0.0.1" ];
          };
          privateKeyOwner = "etcd";
        };

        # kubernetes apiserver certificate
        apiserver = {
          enable = mkDefault top.apiserver.enable;
          action = "systemctl restart --no-block kube-apiserver.service";
          name = "kube-apiserver";
          kind = "server";
          csr = {
            CN = "kubernetes";
            hosts = [
              "localhost" # local kube-apiserver connections
              "kubernetes.default.svc"
              "kubernetes.default.svc.${top.clusterDomain}"
              top.apiserver.advertiseAddress # advertised address of apiserver
            ];
          };
          privateKeyOwner = "kubernetes";
        };

        # client certificate for connecting to kube-proxy
        apiserverProxyClient = {
          enable = mkDefault top.apiserver.enable;
          action = "systemctl restart --no-block kube-apiserver.service";
          name = "kube-apiserver-proxy-client";
          kind = "client";
          csr.CN = "front-proxy-client";
          privateKeyOwner = "kubernetes";
        };

        # client certificate for connecting to kubelets
        apiserverKubeletClient = {
          enable = mkDefault top.apiserver.enable;
          action = "systemctl restart --no-block kube-apiserver.service";
          name = "kube-apiserver-kubelet-client";
          kind = "client";
          csr.CN = "system:kube-apiserver";
          privateKeyOwner = "kubernetes";
        };

        # client certificate for connecting to etcd
        apiserverEtcdClient = {
          enable = mkDefault top.apiserver.enable;
          action = "systemctl restart --no-block kube-apiserver.service";
          name = "kube-apiserver-etcd-client";
          kind = "client";
          csr.CN = "etcd-client";
          privateKeyOwner = "kubernetes";
        };

        # cluster admin has all access to kubernetes
        clusterAdmin = {
          enable = mkDefault top.apiserver.enable;
          name = "kube-cluster-admin";
          kind = "client";
          csr = {
            CN = "cluster-admin";
            names = [{
              O = "system:masters";
            }];
          };
          privateKeyOwner = "root";
        };

        # resource bootstrapper is used for resource bootstrapping
        resourceBootstrapper = {
          enable = mkDefault top.apiserver.enable;
          name = "kube-resource-bootstrapper";
          kind = "client";
          csr = {
            CN = "resource-bootstrapper";
            names = [{
              O = "system:masters";
            }];
          };
          privateKeyOwner = "kubernetes";
        };

        # kube controller manager server certificate
        controllerManager = {
          enable = mkDefault top.controllerManager.enable;
          name = "kube-controller-manager";
          kind = "server";
          csr.CN = "kube-controller-manager";
          action = "systemctl restart --no-block kube-controller-manager.service";
          privateKeyOwner = "kubernetes";
        };

        # kube controller manager kubeconfig client cert
        controllerManagerClient = {
          enable = mkDefault top.controllerManager.enable;
          name = "kube-controller-manager-client";
          kind = "client";
          csr.CN = "system:kube-controller-manager";
          action = "systemctl restart --no-block kube-controller-manager.service";
          privateKeyOwner = "kubernetes";
        };

        # cert required for signing service accounts
        serviceAccountSigner = {
          enable = mkDefault (top.controllerManager.enable || top.apiserver.enable);
          name = "kube-service-account-signer";
          kind = "signing";
          csr.CN = "system:service-account-signer";
          action = "systemctl restart --no-block kube-controller-manager.service";
          privateKeyOwner = "kubernetes";
        };

        # kube scheduler kubeconfig client cert
        schedulerClient = {
          enable = mkDefault top.scheduler.enable;
          name = "kube-scheduler-client";
          kind = "client";
          csr.CN = "system:kube-scheduler";
          action = "systemctl restart --no-block kube-scheduler.service";
          privateKeyOwner = "kubernetes";
        };

        # kubelet server cert
        kubelet = {
          enable = mkDefault top.kubelet.enable;
          name = "kubelet";
          kind = "server";
          csr.CN = top.kubelet.hostname;
          action = "systemctl restart --no-block kubelet.service";
          privateKeyOwner = "root";
        };

        # kubelet kubeconfig client cert
        kubeletClient = {
          enable = mkDefault top.kubelet.enable;
          name = "kubelet-client";
          kind = "client";
          csr = {
            CN = "system:node:${top.kubelet.hostname}";
            names = [{
              O = "system:nodes";
            }];
          };
          action = "systemctl restart --no-block kubelet.service";
          privateKeyOwner = "root";
        };

        # kube proxy client cert
        kubeProxyClient = {
          enable = mkDefault top.proxy.enable;
          name = "kube-proxy-client";
          kind = "client";
          csr.CN = "system:kube-proxy";
          action = "systemctl restart --no-block kube-proxy.service";
        };

        serviceAccountCertSyncEtcdClient = {
          enable = mkDefault pki.serviceAccountCertSync.enable;
          action = "systemctl restart --no-block kube-service-account-cert-upsert.service";
          name = "kube-service-account-cert-sync-etcd-client";
          kind = "client";
          csr.CN = "etcd-client";
          privateKeyOwner = "kubernetes";
        };

        # flannel kubeconfig client cert
        flannelClient = {
          enable = mkDefault top.networking.flannel.enable;
          name = "flannel-client";
          kind = "client";
          csr.CN = "flannel-client";
          action = "systemctl restart --no-block flannel.service";
          privateKeyOwner = "kubernetes";
        };
      };

      apiserver = with pki.certs; {
        etcd = {
          caFile = mkDefault apiserverEtcdClient.ca.cert;
          certFile = mkDefault apiserverEtcdClient.cert;
          keyFile = mkDefault apiserverEtcdClient.key;
        };
        kubeconfig = {
          caFile = mkDefault clusterAdmin.ca.cert;
          certFile = mkDefault clusterAdmin.cert;
          keyFile = mkDefault clusterAdmin.key;
        };
        bootstrap.kubeconfig = {
          caFile = mkDefault resourceBootstrapper.ca.cert;
          certFile = mkDefault resourceBootstrapper.cert;
          keyFile = mkDefault resourceBootstrapper.key;
        };
        clientCaFile = mkDefault apiserver.ca.cert;
        tlsCertFile = mkDefault apiserver.cert;
        tlsKeyFile = mkDefault apiserver.key;
        kubeletClientCaFile = mkDefault apiserverKubeletClient.ca.cert;
        kubeletClientCertFile = mkDefault apiserverKubeletClient.cert;
        kubeletClientKeyFile = mkDefault apiserverKubeletClient.key;
        proxyClientCertFile = mkDefault apiserverProxyClient.cert;
        proxyClientKeyFile = mkDefault apiserverProxyClient.key;
        serviceAccountKeyFile = mkDefault pki.certs.serviceAccountSigner.cert;
      };

      controllerManager = with pki.certs; {
        serviceAccountKeyFile = mkDefault serviceAccountSigner.key;
        rootCaFile = mkDefault serviceAccountSigner.ca.cert;
        kubeconfig = {
          caFile = mkDefault controllerManagerClient.ca.cert;
          certFile = mkDefault controllerManagerClient.cert;
          keyFile = mkDefault controllerManagerClient.key;
        };
      };

      scheduler = with pki.certs; {
        kubeconfig = {
          caFile = mkDefault schedulerClient.ca.cert;
          certFile = mkDefault schedulerClient.cert;
          keyFile = mkDefault schedulerClient.key;
        };
      };

      kubelet = with pki.certs; {
        clientCaFile = mkDefault kubeletClient.ca.cert;
        tlsCertFile = mkDefault kubelet.cert;
        tlsKeyFile = mkDefault kubelet.key;
        kubeconfig = {
          caFile = mkDefault kubeletClient.ca.cert;
          certFile = mkDefault kubeletClient.cert;
          keyFile = mkDefault kubeletClient.key;
        };
      };

      proxy = with pki.certs; {
        kubeconfig = {
          caFile = mkDefault kubeProxyClient.ca.cert;
          certFile = mkDefault kubeProxyClient.cert;
          keyFile = mkDefault kubeProxyClient.key;
        };
      };

      networking.flannel = with pki.certs; {
        kubeconfig = {
          caFile = mkDefault flannelClient.ca.cert;
          certFile = mkDefault flannelClient.cert;
          keyFile = mkDefault flannelClient.key;
        };
      };
    };

    services.etcd = with pki.certs; {
      clientCertAuth = mkDefault true;
      peerClientCertAuth = mkDefault true;
      certFile = mkDefault etcdServer.cert;
      keyFile = mkDefault etcdServer.key;
      trustedCaFile = mkDefault etcdServer.ca.cert;
    };
  };
}
