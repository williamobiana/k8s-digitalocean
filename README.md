# K8s Digital Ocean

* orchestrate a cluster
    - kind
    - metallb for loadbalancer
* authorization & permissions
    - RBAC
    - kube config
    - role & role binding
    - group RBAC
* pod specifications
    - app deployment
        + pods
        + repilicaSets
        + deployment
    - namespaces
    - cluster contexts
    - app deployment to specific node (NodeSelector)
    - NodeSelector based on env
    - pod nodeSelector (admission control plugin) 
    - deamonSet
    - jobs & cronJobs
    - delete jobs when complete using a feature gate (TTLafterFinished)
    - init containers
* configuration resources
    - secrets
    - configMaps to store configurations
    - immutable secrets & configmaps
    - resource quota & limit
* volume orchestration
    - persistent volume(PV) & persistent volume claim(PVC)
    - NFS persistent volume
    - EBS persistent volume
    - stateful set
    - dynamic persistent volume
    - using helm to deploy persistent volume
* pod autoscaling to manage traffic load
    - pod autoscaler
    - using helm to deploy metric server pod autoscaler
    - creating template with pod presets
    - pod disruption bedget for voluntary eviction
* helm chart package manager
    - helm
* gitops argoCD
    - argoCD deployment
    - argoCD configuration (UI & CLI)
