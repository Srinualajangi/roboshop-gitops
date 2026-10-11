# Environments in the lab = namespaces on ONE kind cluster

Isolated per namespace: names, RBAC, quotas/limits, NetworkPolicy, Pod Security level, node placement (via taints + selectors).

NOT isolated (shared by dev, qa and prod here):
- the control plane (apiserver/etcd): a bad CRD or an apiserver overload hits all envs
- cluster-scoped objects: CRDs, ClusterRoles, StorageClasses, admission webhooks
- the Kubernetes version: you cannot test an upgrade in dev first
- the node kernel and container runtime (a container escape on a shared node)
- the cloud account / IAM / network (in AWS terms: same VPC, same blast radius)

Real enterprise: one EKS cluster per environment, usually one AWS account per environment
(AWS Organizations + SCPs), prod access via break-glass. Namespaces separate TEAMS inside a cluster.
