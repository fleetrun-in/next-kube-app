#!/usr/bin/env bash
# One-time cluster prep for private Harbor + ingress on bare metal.
# Run from a machine with SSH access to all Kubernetes nodes.
set -euo pipefail

: "${KUBE_CONTROL_PLANE_IP:?}"
: "${KUBE_WORKER1_IP:?}"
: "${KUBE_WORKER2_IP:?}"
: "${KUBE_SSH_KEY:?}"
: "${HARBOR_HOSTNAME:?}"

SSH_KEY="${KUBE_SSH_KEY/#\$\{HOME\}/$HOME}"
NODES=("$KUBE_CONTROL_PLANE_IP" "$KUBE_WORKER1_IP" "$KUBE_WORKER2_IP")

for ip in "${NODES[@]}"; do
  echo "Configuring ${ip}..."
  ssh -i "$SSH_KEY" "ubuntu@${ip}" bash -s <<EOF
set -euo pipefail
grep -q "${HARBOR_HOSTNAME}" /etc/hosts || echo "${ip} ${HARBOR_HOSTNAME}" | sudo tee -a /etc/hosts
grep -q "next-kube-app.example.com" /etc/hosts || echo "${ip} next-kube-app.example.com" | sudo tee -a /etc/hosts
sudo mkdir -p /etc/containerd/certs.d/${HARBOR_HOSTNAME}
sudo tee /etc/containerd/certs.d/${HARBOR_HOSTNAME}/hosts.toml >/dev/null <<EOC
server = "https://${HARBOR_HOSTNAME}"

[host."https://${HARBOR_HOSTNAME}"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOC
if ! grep -q 'registry.configs."${HARBOR_HOSTNAME}".tls' /etc/containerd/config.toml; then
  sudo python3 - <<'PY'
from pathlib import Path
p = Path("/etc/containerd/config.toml")
text = p.read_text()
block = '''
[plugins."io.containerd.cri.v1.images".registry.configs."${HARBOR_HOSTNAME}".tls]
  insecure_skip_verify = true
'''
anchor = '[plugins."io.containerd.cri.v1.images".registry]'
if anchor in text and "${HARBOR_HOSTNAME}" not in text:
    text = text.replace(anchor, anchor + block)
    p.write_text(text)
PY
fi
sudo systemctl restart containerd kubelet
EOF
done

echo "Patching ingress-nginx external IPs..."
export KUBECONFIG="${KUBECONFIG:-}"
kubectl patch svc ingress-nginx-controller -n ingress-nginx --type=json -p "[
  {\"op\":\"add\",\"path\":\"/spec/externalIPs\",\"value\":[\"${KUBE_CONTROL_PLANE_IP}\",\"${KUBE_WORKER1_IP}\",\"${KUBE_WORKER2_IP}\"]}
]" 2>/dev/null || echo "Set KUBECONFIG and run kubectl patch manually."

echo "Done."
