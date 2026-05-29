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
| `HARBOR_REGISTRY` | Harbor hostname for image paths (e.g. `harbor.example.com`) — or an IP if you also set `HARBOR_HOSTNAME` |
| `HARBOR_HOSTNAME` | **Required** for private Harbor: TLS cert hostname (e.g. `harbor.example.com`) — same as cluster `/etc/hosts` |
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

On every push to `main`, GitHub Actions connects to your cluster via `KUBECONFIG_B64`, builds the image **inside the cluster** with Kaniko (GitHub-hosted runners cannot reach a private Harbor IP), pushes to Harbor, applies manifests, and waits for rollout.

1. Renders Kubernetes manifests
2. Runs a Kaniko build Job in the cluster (clones this repo at the commit SHA)
3. Pushes to Harbor (`<hostname>/<project>/next-kube-app:<sha>` and `:latest`)
4. Applies Deployment, Service, and Ingress
5. Waits for rollout completion

Point DNS for `INGRESS_HOST` at your ingress-nginx external endpoint. cert-manager issues TLS via the `letsencrypt-prod` ClusterIssuer.

## Harbor TLS in GitHub Actions

Harbor on bare metal is private — the workflow does **not** build on the GitHub runner. Kaniko runs on-cluster with `hostAliases` and TLS skip (same as `scripts/configure-cluster-nodes.sh`).

Set **`HARBOR_HOSTNAME`** to the Harbor TLS hostname (same as cluster `/etc/hosts`, e.g. `harbor.example.com`). This is required when `HARBOR_REGISTRY` is an IP or when `INGRESS_HOST` uses an IP-based name (e.g. `app.178.38.188.254`).

| Secret | Example |
|--------|---------|
| `HARBOR_HOSTNAME` | `harbor.example.com` |
| `HARBOR_IP` | `178.38.188.254` |
| `HARBOR_REGISTRY` | `178.38.188.254` or `harbor.example.com` |

If the registry uses a private CA, add `HARBOR_CA_CERT_B64` (optional; Kaniko uses `--skip-tls-verify-registry`).

```bash
base64 -w0 harbor-ca.crt   # paste into GitHub secret HARBOR_CA_CERT_B64
```

## Harbor setup

1. Create a project (e.g. `apps`) in Harbor.
2. Create a robot account with push/pull permissions for that project.
3. Store credentials in GitHub secrets above.
