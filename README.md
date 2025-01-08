# K8s Digital Ocean

* orchestrate a cluster
    - kind
    - metallb for loadbalancer
    - kind working with mulitple clusters
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



aws eks update-kubeconfig --name ex-infrastructure
kubectl apply -f karpenter.yaml
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter -c controller
kubectl get nodes -L karpenter.sh/registered
kubectl get pods -A -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
kubectl get svc
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl apply -f argocd-app.yaml 



Add this resource policies to delete the resources on uninstall
customResourceDefinitions:
  applications.argoproj.io:
    resource:
      policy: delete
  applicationsets.argoproj.io:
    resource:
      policy: delete
  appprojects.argoproj.io:
    resource:
      policy: delete
