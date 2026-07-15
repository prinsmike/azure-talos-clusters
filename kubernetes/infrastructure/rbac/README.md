# Kubernetes RBAC Configurations

This directory contains RBAC (Role-Based Access Control) configurations for Talos
Linux Kubernetes clusters.

## Talos Node RBAC

**File:** `talos-node-rbac.yaml`

Grants Talos nodes permission to list other nodes in the cluster. This is required
by Talos's KubernetesPullController, which monitors node resources.

### Problem

Without this RBAC configuration, Talos nodes will show the following error:

```
user: warning: [talos] kubernetes registry node watch error {
  "component": "controller-runtime",
  "controller": "KubernetesPullController",
  "error": "nodes is forbidden: User \"system:node:...\" cannot list resource \"nodes\" in API group \"\" at the cluster scope"
}
```

### Installation

```bash
kubectl apply -f talos-node-rbac.yaml
```

### Troubleshooting

If the `system:nodes` group binding doesn't work (nodes may not be in that group
depending on configuration), you can add direct bindings to specific node users
(see `talos-node-rbac-dev.yaml` for an example):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: talos-nodes-list-nodes
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: talos-node-list-nodes
subjects:
  # Add each node user explicitly
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: system:node:<control-plane-node-name>
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: system:node:<worker-node-name>
```

To find your node usernames:

```bash
# List all nodes
kubectl get nodes

# The username format is: system:node:<node-name>
```
