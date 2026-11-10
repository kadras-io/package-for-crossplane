{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/packages/
  packages = [
    # Carvel
    pkgs.imgpkg
    # kapp 0.66.0 rejects the change group it computes for CRDs with long kinds, like
    # ManagedResourceActivationPolicy. Fixed in 0.66.1 (https://github.com/carvel-dev/kapp/pull/1124), which requires Go 1.27.
    ((pkgs.kapp.override { buildGoModule = pkgs.buildGo127Module; }).overrideAttrs (finalAttrs: prev: {
      version = "0.66.1";
      src = prev.src.override {
        hash = "sha256-46wW5KZKj6zqvYsWC86cJGWtzpP3bvymXmkZOc6hZDc=";
      };
    }))
    pkgs.kbld
    pkgs.vendir
    pkgs.ytt

    # Kubernetes
    pkgs.k3d
    pkgs.kind
    pkgs.kubeconform
    pkgs.kubectl
    pkgs.kubernetes-helm

    # Testing
    pkgs.kuttl
    pkgs.kyverno-chainsaw

    # Utilities
    pkgs.cosign
    pkgs.go-task
    pkgs.jq
    pkgs.podman
    pkgs.yamllint
    pkgs.yq-go
  ];

  # https://devenv.sh/languages/
  languages.go.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
