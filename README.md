# k3s-home-lab

A 3-node high-availability Kubernetes cluster on consumer hardware, with a
full observability stack. Built to practice SRE fundamentals: failure
recovery, observability, SLOs, and GitOps.

## Architecture

```text
┌─────────────────────────────────────────────────────────┐
│ 3x Lenovo ThinkCentre M720q (i5-7500, 16GB RAM, SSD)    │
│ Ubuntu Server 24.04 LTS                                 │
├─────────────────────────────────────────────────────────┤
│ k3s (3 servers, embedded etcd HA)                       │
│  ┌───────────┐   ┌───────────┐   ┌───────────┐          │
│  │  k8s-1    │   │  k8s-2    │   │  k8s-3    │          │
│  │  server   │   │  server   │   │  server   │          │
│  │  etcd     │   │  etcd     │   │  etcd     │          │
│  │  pods     │   │  pods     │   │  pods     │          │
│  └───────────┘   └───────────┘   └───────────┘          │
├─────────────────────────────────────────────────────────┤
│ Observability (namespace: monitoring)                   │
│  Prometheus + Grafana + Alertmanager (kube-prom-stack)  │
│  Loki + Grafana Alloy (logs)                            │
│  node-exporter, kube-state-metrics                      │
├─────────────────────────────────────────────────────────┤
│ Workloads                                               │
│  demo-app (stateless HTTP, /metrics endpoint)           │
│  Pod anti-affinity: 1 pod per node                      │
└─────────────────────────────────────────────────────────┘
```

## Nodes

| Node  | IP            | Role            |
|-------|---------------|-----------------|
| k8s-1 | 192.168.1.11  | server (etcd)   |
| k8s-2 | 192.168.1.12  | server (etcd)   |
| k8s-3 | 192.168.1.13  | server (etcd)   |

IPs are DHCP reservations on the home router. Hostnames and network setup are
documented in [`cluster/node-setup.md`](cluster/node-setup.md).

## Design Decisions

### Why 3 servers instead of 1 server + 2 agents?

A single server node is a single point of failure for the control plane. If it
goes down, there is no scheduling, no self-healing, and no API access. With 3
etcd members, losing any one node keeps quorum (2 of 3) and the cluster stays
operational. This was a deliberate choice for this lab, I will do another lab
using 1 server + 2 agents later.

### Why k3s over full Kubernetes?

- Single binary with low resource overhead, so the control plane fits on
  16GB machines alongside workloads (idle footprint: TBD, measure with
  `kubectl top nodes`).
- Bundles an ingress controller (Traefik), metrics-server, and a local-path
  storage provisioner, which means fewer moving parts to debug while learning.
- Same API and object model as upstream Kubernetes, so the skills transfer.
- Planned next: rebuild the cluster the hard way (kubeadm, then manual
  components) to learn what k3s abstracts away.

### Why kube-prometheus-stack over standalone Prometheus?

It bundles Prometheus, Grafana, Alertmanager, node-exporter, and
kube-state-metrics with pre-wired ServiceMonitors and dashboards, replacing a
lot of boilerplate YAML with one Helm install. The tradeoff is less visibility
into each component's configuration.

### Why Loki over Elasticsearch/Fluentd?

Loki indexes labels only, not log content, so storage and RAM needs are much
lower. For a 3-node lab that keeps log retention cheap. Queries use LogQL
(label selectors plus line filters), which is enough for "find the error"
workflows.

### Why Grafana Alloy for log collection?

Loki stores logs, but something has to collect them from each node and send
them there. Alloy runs as a DaemonSet (one pod per node), reads container
logs, adds labels like namespace and pod name, and ships them to Loki.
Promtail used to do this job, but it reached end of life in March 2026 and
all development moved to Alloy, so Alloy is the supported choice for a new
cluster.

## Observability

| Signal  | Collector                     | Storage                 | Visualization |
|---------|-------------------------------|-------------------------|---------------|
| Metrics | Prometheus (15s scrape)       | TSDB (7d retention)     | Grafana       |
| Logs    | Alloy (Kubernetes API tailing)| Loki (local PVC)        | Grafana       |
| Alerts  | Alertmanager                  | n/a                     | (TBD)         |

Key dashboards:

- Cluster overview (CPU, memory, disk per node)
- Application: request rate, p99 latency, error rate
- Logs: filtered by namespace and pod, error-level only

## Failure Scenarios

"Expected" reflects Kubernetes defaults. "Measured" gets filled in from real
drills on this cluster.

| Scenario | How | Expected (defaults) | Measured |
|----------|-----|---------------------|----------|
| Pod kill | `kubectl delete pod <pod>` | Deployment controller recreates it within seconds | TBD |
| Node drain | `kubectl drain <node> --ignore-daemonsets` | Pods reschedule onto remaining nodes | TBD |
| k3s service stop | `sudo systemctl stop k3s` on one node | Node goes NotReady; running containers may keep running | TBD |
| Node power-off | Power off one server | NotReady after roughly 40s; pods evicted after the default 5-minute toleration; quorum (2/3) maintained | TBD |
| Quorum loss | Power off two servers | API unavailable until a majority returns; already-running workloads keep serving | TBD |

## Known Limitations

- **Wi-Fi.** The nodes are on Wi-Fi for now. etcd is sensitive to latency
  and jitter, so expect occasional leader elections and slow-request warnings.
  Plan: Buy as switch and move to wired connection.
- **Single registration address.** The kubeconfig points at k8s-1
  (192.168.1.11). If that node is down, `kubectl` from my PC fails even though
  the cluster is healthy. Possible fixes: a virtual IP such as kube-vip, or
  DNS round-robin. For now can also just update server IP in
  kubeconfig.
- **Control-plane nodes also run workloads.** Fine for a lab, but it means
  heavy pods can compete with etcd and the API server for resources.

## Repository Structure

```text
k3s-home-lab/
├── README.md
├── cluster/
│   ├── install-server.sh          # k3s server install with --cluster-init
│   ├── join-server.sh             # joins nodes 2 and 3 as servers
│   └── node-setup.md              # hostname, IP reservation, prerequisites
├── apps/
│   └── demo-app.yaml              # Deployment + Service + ServiceMonitor
├── monitoring/
│   ├── kube-prometheus-stack/
│   │   └── values.yaml
│   ├── loki/
│   │   └── values.yaml
│   └── alloy/
│       └── values.yaml
├── terraform/                     # planned
└── .gitignore
```

## Roadmap

- [x] 3-node k3s cluster with etcd HA
- [x] kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
- [x] Loki + Alloy for log collection
- [x] demo-app with ServiceMonitor
- [ ] Argo CD (GitOps: cluster state managed from this repo)
- [ ] Alertmanager routing (Discord webhook? TBD)
- [ ] Load testing with `hey` / `k6`
- [ ] HPA based on request rate
- [ ] SLOs and error budgets for demo-app
- [ ] Chaos drills with measured recovery times (fill in the table above)
- [ ] Move nodes from Wi-Fi to wired Ethernet
- [ ] Terraform: bootstrap Argo CD
- [ ] Rebuild with kubeadm ("the hard way") and write up the differences

## Prerequisites

- 3 machines running Ubuntu Server 24.04 LTS
- Fixed IPs (DHCP reservations on the router) on the same subnet
- About 2GB free RAM per node for the control plane, plus workloads
- Time sync running on every node (etcd is sensitive to clock drift)
- Network access to Docker Hub and quay.io for image pulls

## Quick Start

```bash
# On k8s-1 (192.168.1.11): initialize the cluster
./cluster/install-server.sh

# Read the join token (keep it out of Git)
sudo cat /var/lib/rancher/k3s/server/node-token

# On k8s-2 and k8s-3: join as servers
./cluster/join-server.sh 192.168.1.11 "<token>"

# Verify: all three nodes Ready with control-plane and etcd roles
kubectl get nodes -o wide
```

Never commit the join token or the kubeconfig. Both are covered by
`.gitignore`.

