Monitoring stack (Prometheus + Grafana)

Files added:
- monitoring-namespace.yaml: creates `monitoring` namespace
- prometheus-configmap.yaml: Prometheus config to scrape services/pods labeled `app: webapp`
- prometheus-deployment.yaml: Prometheus deployment (single replica)
- prometheus-service.yaml: ClusterIP service for Prometheus
- grafana-deployment.yaml: Grafana deployment (admin password: `admin`)
- grafana-service.yaml: Grafana Service (LoadBalancer)
- grafana-datasource-configmap.yaml: Grafana datasource pointing to Prometheus

Notes:
- This is a simple, non-HA monitoring setup intended for demo / development. For production use, use the
  Prometheus Operator or kube-prometheus-stack via Helm and configure persistent storage, user/password
  secrets, and RBAC properly.

How to deploy:

kubectl apply -f eks/manifestfiles/monitoring-namespace.yaml
kubectl apply -f eks/manifestfiles/prometheus-configmap.yaml
kubectl apply -f eks/manifestfiles/prometheus-deployment.yaml
kubectl apply -f eks/manifestfiles/prometheus-service.yaml
kubectl apply -f eks/manifestfiles/grafana-datasource-configmap.yaml
kubectl apply -f eks/manifestfiles/grafana-deployment.yaml
kubectl apply -f eks/manifestfiles/grafana-service.yaml

Retrieve Grafana external URL (once LoadBalancer provisioned):

kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

Default Grafana admin login: `admin` / `admin` (change immediately in production)
