# next-kube-app

Minimal Next.js application deployed to Kubernetes with Harbor and automated GitHub Actions delivery on merges to `main`.

**Repository:** https://github.com/fleetrun-in/next-kube-app

## Local development

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Docker

```bash
docker build -t next-kube-app:local .
docker run --rm -p 3000:3000 next-kube-app:local
```

## Kubernetes

Manifests live in [`k8s/`](k8s/). Render them with environment substitution:

```bash
export IMAGE="harbor.example.com/apps/next-kube-app:latest"
export INGRESS_HOST="next-kube-app.example.com"
export DOCKER_CONFIG_JSON_B64="$(printf '{"auths":{"harbor.example.com":{"auth":"'$(printf 'user:pass' | base64 -w0)'"}}}' | base64 -w0)"
./scripts/render-manifests.sh
kubectl apply -f /tmp/next-kube-app-k8s/
```

## GitHub repository secrets

Configure these in the GitHub repo **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `HARBOR_REGISTRY` | Harbor **hostname** on the TLS cert (e.g. `harbor.example.com`) — not an IP, no `https://`, no trailing slash |
| `HARBOR_PROJECT` | Harbor project name (e.g. `apps`) — no leading/trailing slashes |
| `HARBOR_CA_CERT_B64` | Optional: base64 of Harbor CA/root `.crt` if the registry uses a private or self-signed certificate |
| `HARBOR_USERNAME` | Harbor robot or user account |
| `HARBOR_PASSWORD` | Harbor password or robot token |
| `KUBECONFIG_B64` | Base64-encoded kubeconfig with deploy permissions |
| `INGRESS_HOST` | Public DNS name for the app (e.g. `next-kube-app.example.com`) |
| `HARBOR_IP` | Node IP where Harbor ingress is reachable (mapped to `HARBOR_REGISTRY` in CI and Kaniko `hostAliases`) |

## Cluster prerequisites (bare metal)

Before the first deploy, on each node:

1. Point `harbor.example.com` and your app host at a node IP (`/etc/hosts` or real DNS).
2. Expose ingress on node IPs (`externalIPs` on `ingress-nginx-controller`).
3. Allow Harbor pulls with a private/self-signed registry (see `scripts/configure-cluster-nodes.sh`).

```bash
# From the parent Kube repo .env
source ../.env
export KUBECONFIG=/path/to/kubeconfig
./scripts/configure-cluster-nodes.sh
```

## Enable GitHub Actions workflow

GitHub rejects workflow pushes unless your `gh` token has the `workflow` scope:

```bash
gh auth refresh -h github.com -s workflow
git push origin main
```

## CI/CD

On every push to `main`, GitHub Actions:

1. Builds the Docker image
2. Pushes to Harbor (`<registry>/<project>/next-kube-app:<sha>` and `:latest`)
3. Applies Kubernetes manifests
4. Waits for rollout completion

Point DNS for `INGRESS_HOST` at your ingress-nginx external endpoint. cert-manager issues TLS via the `letsencrypt-prod` ClusterIssuer.

## Harbor TLS in GitHub Actions

Harbor on bare metal usually uses a cert for a **hostname** (e.g. `harbor.example.com`), not for a raw IP. If `HARBOR_REGISTRY` is an IP, Docker fails with `doesn't contain any IP SANs`.

1. Set `HARBOR_REGISTRY` to the hostname on the certificate (same name you use in cluster `/etc/hosts`).
2. Set `HARBOR_IP` to a node IP that reaches Harbor ingress (the workflow adds a hosts entry on the runner).
3. If the registry uses a private CA or self-signed cert, add `HARBOR_CA_CERT_B64` (base64-encoded CA `.crt` file).

```bash
base64 -w0 harbor-ca.crt   # paste into GitHub secret HARBOR_CA_CERT_B64
```

## Harbor setup

1. Create a project (e.g. `apps`) in Harbor.
2. Create a robot account with push/pull permissions for that project.
3. Store credentials in GitHub secrets above.
