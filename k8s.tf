resource "kubernetes_namespace" "flux_namespace" {
  metadata {
    name = "flux"
  }
  depends_on = [ google_container_node_pool.blockchain_cluster_node_pool ]
}

resource "kubernetes_namespace" "monitoring_namespace" {
  metadata {
    name = "monitoring"
  }
  depends_on = [ kubernetes_namespace.flux_namespace ]
}

resource "null_resource" "deploy_prometheus" {
  provisioner "local-exec" {

    command = <<EOF
set -e
set -x
gcloud container clusters get-credentials "${google_container_cluster.blockchain_cluster.name}" --region="${google_container_cluster.blockchain_cluster.location}" --project="${google_container_cluster.blockchain_cluster.project}"

cd ${path.module}
# Install Helm operator in order to install the prometheus operator
# Instructions from https://docs.fluxcd.io/projects/helm-operator/en/latest/get-started/using-yamls/
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/1.1.0/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/1.1.0/deploy/rbac.yaml
kubectl apply -f helm-operator.yaml

cat <<'EOPO' > prometheus-operator.yaml
${templatefile("${path.module}/prometheus-operator.yaml.tmpl",
   { "monitoring_slack_url": var.monitoring_slack_url } ) }
EOPO
kubectl apply -f prometheus-operator.yaml
rm prometheus-operator.yaml
EOF

  }
  depends_on = [ kubernetes_namespace.monitoring_namespace ]
}
