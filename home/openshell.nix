{
  homeDirectory,
  pkgs,
}: let
  version = "0.0.104";
  gatewayName = "k3s";
  configDirectory = "${homeDirectory}/.config/openshell";
  gatewayDirectory = "${configDirectory}/gateways/${gatewayName}";
  oidcSecretFile = "${configDirectory}/oidc-client-secret";

  package = pkgs.stdenvNoCC.mkDerivation {
    pname = "openshell";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/NVIDIA/OpenShell/releases/download/v${version}/openshell-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-qNsmKtmvmWo9kgP8w9e6kP4sbLDz//ybfRubRM0n3yI=";
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 openshell "$out/bin/openshell"
      runHook postInstall
    '';

    meta = {
      description = "Safe, private runtime for autonomous AI agents";
      homepage = "https://github.com/NVIDIA/OpenShell";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "openshell";
      platforms = ["x86_64-linux"];
    };
  };

  command = pkgs.writeShellApplication {
    name = "openshell";
    runtimeInputs = [pkgs.jq];
    text = ''
      token_file="${gatewayDirectory}/oidc_token.json"
      metadata_file="${gatewayDirectory}/metadata.json"

      if [[ ! -r "${oidcSecretFile}" ]]; then
        echo "OpenShell OIDC client secret is not available" >&2
        exit 1
      fi

      OPENSHELL_OIDC_CLIENT_SECRET="$(<"${oidcSecretFile}")"
      export OPENSHELL_OIDC_CLIENT_SECRET

      if [[ -f "$metadata_file" ]] && ! jq -e '.expires_at == null or .expires_at > (now + 60)' "$token_file" >/dev/null 2>&1; then
        ${package}/bin/openshell gateway login ${gatewayName} >/dev/null
      fi

      exec ${package}/bin/openshell "$@"
    '';
  };

  bootstrap = pkgs.writeShellApplication {
    name = "openshell-bootstrap";
    runtimeInputs = [
      package
      pkgs.coreutils
      pkgs.kubectl
    ];
    text = ''
      kubeconfig=/etc/rancher/k3s/k3s.yaml
      mtls_directory="${gatewayDirectory}/mtls"
      temporary_directory="$(mktemp -d)"
      trap 'rm -rf "$temporary_directory"' EXIT
      umask 077

      kubectl --kubeconfig "$kubeconfig" --namespace openshell wait \
        --for=condition=Ready \
        --selector=app.kubernetes.io/name=openshell,app.kubernetes.io/instance=openshell \
        pod \
        --timeout=5m

      kubectl --kubeconfig "$kubeconfig" --namespace openshell get secret openshell-client-tls \
        --output=jsonpath='{.data.ca\.crt}' | base64 --decode >"$temporary_directory/ca.crt"
      kubectl --kubeconfig "$kubeconfig" --namespace openshell get secret openshell-client-tls \
        --output=jsonpath='{.data.tls\.crt}' | base64 --decode >"$temporary_directory/tls.crt"
      kubectl --kubeconfig "$kubeconfig" --namespace openshell get secret openshell-client-tls \
        --output=jsonpath='{.data.tls\.key}' | base64 --decode >"$temporary_directory/tls.key"
      kubectl --kubeconfig "$kubeconfig" --namespace authentik get secret authentik-openshell-oidc \
        --output=jsonpath='{.data.OPENCLAW_OPENSHELL_OIDC_CLIENT_SECRET}' | base64 --decode >"$temporary_directory/oidc-client-secret"

      install -d -m 0700 "${configDirectory}" "${gatewayDirectory}" "$mtls_directory"
      install -m 0600 "$temporary_directory/ca.crt" "$mtls_directory/ca.crt"
      install -m 0600 "$temporary_directory/tls.crt" "$mtls_directory/tls.crt"
      install -m 0600 "$temporary_directory/tls.key" "$mtls_directory/tls.key"
      install -m 0600 "$temporary_directory/oidc-client-secret" "${oidcSecretFile}"

      OPENSHELL_OIDC_CLIENT_SECRET="$(<"${oidcSecretFile}")"
      export OPENSHELL_OIDC_CLIENT_SECRET

      for _ in {1..60}; do
        ${package}/bin/openshell gateway remove ${gatewayName} >/dev/null 2>&1 || true
        if ! ${package}/bin/openshell gateway add https://127.0.0.1:17670 \
          --local \
          --name ${gatewayName} \
          --oidc-issuer https://auth.kentaro1043.com/application/o/openshell/ \
          --oidc-client-id openshell-cli \
          --oidc-audience openshell-cli; then
          sleep 5
          continue
        fi
        if ${package}/bin/openshell --gateway ${gatewayName} status; then
          exit 0
        fi
        sleep 5
      done

      echo "OpenShell gateway did not become ready" >&2
      exit 1
    '';
  };
in {
  inherit bootstrap command package;
}
