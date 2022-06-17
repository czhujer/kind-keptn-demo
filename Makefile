# Set environment variables
export CLUSTER_NAME?=keptn
export CILIUM_VERSION?=1.11.5
export CERT_MANAGER_CHART_VERSION=1.8.1
export ARGOCD_CHART_VERSION=4.8.3
export KEPTN_VERSION?=0.13.6
export TRIVY_IMAGE_CHECK=0

export ARGOCD_OPTS="--grpc-web --insecure --server argocd.127.0.0.1.nip.io"

# kind image list
# kindest/node:v1.22.7@sha256:1dfd72d193bf7da64765fd2f2898f78663b9ba366c2aa74be1fd7498a1873166
# kindest/node:v1.23.5@sha256:a69c29d3d502635369a5fe92d8e503c09581fcd406ba6598acc5d80ff5ba81b1
export KIND_NODE_IMAGE="kindest/node:v1.24.1@sha256:fd82cddc87336d91aa0a2fc35f3c7a9463c53fd8e9575e9052d2c75c61f5b083"

.PHONY: kind-basic
kind-basic: kind-create kx-kind kind-install-crds cilium-prepare-images cilium-install argocd-deploy nginx-ingress-deploy

.PHONY: kind-keptn
kind-keptn: kind-basic prometheus-stack-deploy keptn-prepare-images keptn-deploy

.PHONY: kind-create
kind-create:
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 "$(KIND_NODE_IMAGE)"
endif
	kind --version
	kind create cluster --name "$(CLUSTER_NAME)" \
 		--config="kind/kind-config.yaml" \
 		--image="$(KIND_NODE_IMAGE)"
# for testing PSP
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/psp/privileged-psp.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/psp/baseline-psp.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/psp/restricted-psp.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/kind/psp/cluster-roles.yaml
#	kubectl apply -f https://github.com/appscodelabs/tasty-kube/raw/master/kind/psp/role-bindings.yaml
# for more control planes, but no workers
# kubectl taint nodes --all node-role.kubernetes.io/master- || true

.PHONY: kind-delete
kind-delete:
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: kx-kind
kx-kind:
	kind export kubeconfig --name $(CLUSTER_NAME)

.PHONY: kind-install-crds
kind-install-crds:
	# fix prometheus-operator's CRDs
	kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-servicemonitors.yaml
	# for keptn
	kubectl apply -f keptn/crd-istio-destinationrules.yaml \
				  -f keptn/crd-istio-virtualservices.yaml
	# https://raw.githubusercontent.com/keptn-sandbox/keptn-in-a-box/master/resources/istio/public-gateway.yaml

.PHONY: cilium-prepare-images
cilium-prepare-images:
	# pull image locally
	docker pull quay.io/cilium/cilium:v$(CILIUM_VERSION)
	docker pull quay.io/cilium/hubble-ui:v0.8.5
	docker pull quay.io/cilium/hubble-ui-backend:v0.8.5
	docker pull quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	docker pull docker.io/envoyproxy/envoy:v1.18.4@sha256:e5c2bb2870d0e59ce917a5100311813b4ede96ce4eb0c6bfa879e3fbe3e83935
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/cilium:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-ui:v0.8.5
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-ui-backend:v0.8.5
	trivy image --severity=HIGH --exit-code=0 quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/envoyproxy/envoy:v1.18.4@sha256:e5c2bb2870d0e59ce917a5100311813b4ede96ce4eb0c6bfa879e3fbe3e83935
endif
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/cilium:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui-backend:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/envoyproxy/envoy:v1.18.4@sha256:e5c2bb2870d0e59ce917a5100311813b4ede96ce4eb0c6bfa879e3fbe3e83935

.PHONY: cilium-install
cilium-install:
	# Add the Cilium repo
	helm repo add cilium https://helm.cilium.io/
	# install/upgrade the chart
	helm upgrade --install cilium cilium/cilium --version $(CILIUM_VERSION) \
	   -f kind/kind-values-cilium.yaml \
	   -f kind/kind-values-cilium-hubble.yaml \
	   -f kind/kind-values-cilium-service-monitors.yaml \
	   --namespace kube-system \
	   --wait

.PHONY: cert-manager-deploy
cert-manager-deploy:
	# prepare image(s)
	docker pull quay.io/jetstack/cert-manager-controller:v$(CERT_MANAGER_CHART_VERSION)
	docker pull quay.io/jetstack/cert-manager-webhook:v$(CERT_MANAGER_CHART_VERSION)
	docker pull quay.io/jetstack/cert-manager-cainjector:v$(CERT_MANAGER_CHART_VERSION)
	docker pull quay.io/jetstack/cert-manager-ctl:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-controller:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-webhook:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-cainjector:v$(CERT_MANAGER_CHART_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/jetstack/cert-manager-ctl:v$(CERT_MANAGER_CHART_VERSION)
	#
	helm repo add cert-manager https://charts.jetstack.io
	helm upgrade --install \
		cert-manager cert-manager/cert-manager \
		--version "v${CERT_MANAGER_CHART_VERSION}" \
	   --namespace cert-manager \
	   --create-namespace \
	   --values kind/cert-manager.yaml \
	   --wait

.PHONY: argocd-deploy
argocd-deploy:
	# prepare image(s)
#	docker pull quay.io/argoproj/argocd:v2.3.4
#	docker pull quay.io/argoproj/argocd-applicationset:v0.4.1
#	docker pull redis:6.2.6-alpine
#	docker pull bitnami/redis-exporter:1.26.0-debian-10-r2
#	kind load docker-image --name $(CLUSTER_NAME) quay.io/argoproj/argocd:v2.3.4
#	kind load docker-image --name $(CLUSTER_NAME) quay.io/argoproj/argocd-applicationset:v0.4.1
#	kind load docker-image --name $(CLUSTER_NAME) redis:6.2.6-alpine
#	kind load docker-image --name $(CLUSTER_NAME) bitnami/redis-exporter:1.26.0-debian-10-r2
	# install
	helm repo add argo https://argoproj.github.io/argo-helm
	helm upgrade --install \
		argocd-single \
		argo/argo-cd \
		--namespace argocd \
		--create-namespace \
		--version "${ARGOCD_CHART_VERSION}" \
		-f kind/kind-values-argocd.yaml \
		-f kind/kind-values-argocd-service-monitors.yaml \
		--wait
	# update CRDs
	kubectl -n argocd apply -f argocd/argo-cd-crds.yaml
	# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo ""

.PHONY: nginx-ingress-deploy
nginx-ingress-deploy:
	docker pull k8s.gcr.io/ingress-nginx/controller:v1.2.1
	kind load docker-image --name $(CLUSTER_NAME) k8s.gcr.io/ingress-nginx/controller:v1.2.1
	# ingress
	kubectl -n argocd apply -f argocd/nginx-ingress.yaml
	kubectl -n argocd apply -f argocd/gateway-api-crds.yaml

.PHONY: metrics-server-deploy
metrics-server-deploy:
	kubectl -n argocd apply -f argocd/projects/system-kube.yaml
	kubectl -n argocd apply -f argocd/metrics-server.yaml

.PHONY: prometheus-stack-deploy
prometheus-stack-deploy:
	# projects
	kubectl -n argocd apply -f argocd/projects/system-monitoring.yaml
	# (update) CRDs
	kubectl -n argocd apply -f argocd/prometheus-stack-crds.yaml
	sleep 10
	#monitoring
	kubectl -n argocd apply -f argocd/prometheus-stack.yaml
	kubectl -n argocd apply -f argocd/prometheus-adapter.yaml

.PHONY: starboard-deploy
starboard-deploy:
	# projects
	kubectl -n argocd apply -f argocd/projects/security-starboard.yaml
	# (update) CRDs
	kubectl -n argocd apply -f argocd/security-starboard.yaml

.PHONY: keptn-prepare-images
keptn-prepare-images:
	# pull image locally
	docker pull docker.io/bitnami/mongodb:4.4.13-debian-10-r33
	docker pull docker.io/bitnami/mongodb-exporter:0.31.1-debian-10-r4
	docker pull docker.io/keptn/distributor:$(KEPTN_VERSION)
	docker pull docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	docker pull docker.io/keptn/bridge2:$(KEPTN_VERSION)
	docker pull nats:2.1.9-alpine3.12
	docker pull synadia/prometheus-nats-exporter:0.5.0
	docker pull docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)
	docker pull docker.io/keptn/jmeter-service:$(KEPTN_VERSION)
	docker pull docker.io/keptn/helm-service:$(KEPTN_VERSION)
	docker pull keptncontrib/prometheus-service:0.7.5
	docker pull keptncontrib/argo-service:0.9.3
	# docker pull docker.io/keptn/distributor:0.10.0
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 docker.io/bitnami/mongodb:4.4.13-debian-10-r33
	trivy image --severity=HIGH --exit-code=0 docker.io/bitnami/mongodb-exporter:0.31.1-debian-10-r4
	trivy image --severity=HIGH --exit-code=1 docker.io/keptn/distributor:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/keptn/bridge2:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 nats:2.1.9-alpine3.12
	trivy image --severity=HIGH --exit-code=1 synadia/prometheus-nats-exporter:0.5.0
	trivy image --severity=HIGH --exit-code=1 docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/keptn/jmeter-service:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/keptn/helm-service:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 keptncontrib/prometheus-service:0.7.5
	trivy image --severity=HIGH --exit-code=0 keptncontrib/argo-service:0.9.3
	# trivy image --severity=HIGH --exit-code=0 docker.io/keptn/distributor:0.10.0
endif
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) docker.io/bitnami/mongodb:4.4.13-debian-10-r33
	kind load docker-image --name $(CLUSTER_NAME) docker.io/bitnami/mongodb-exporter:0.31.1-debian-10-r4
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/distributor:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/bridge2:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) nats:2.1.9-alpine3.12
	kind load docker-image --name $(CLUSTER_NAME) synadia/prometheus-nats-exporter:0.5.0
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/jmeter-service:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/helm-service:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) keptncontrib/prometheus-service:0.7.5
	kind load docker-image --name $(CLUSTER_NAME) keptncontrib/argo-service:0.9.3
	# kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/distributor:0.10.0

.PHONY: keptn-delete
keptn-delete:
	kubectl -n argocd delete -f argocd/keptn-nats.yaml || true
	kubectl -n argocd delete -f argocd/keptn-mongodb.yaml || true
	kubectl -n argocd delete -f argocd/keptn.yaml || true
	kubectl delete ns keptn -R

.PHONY: keptn-deploy
keptn-deploy:
	#	kubectl label --overwrite ns keptn \
	#      pod-security.kubernetes.io/enforce=baseline \
	#      pod-security.kubernetes.io/enforce-version=latest \
	#      pod-security.kubernetes.io/warn=restricted \
	#      pod-security.kubernetes.io/warn-version=latest \
	#      pod-security.kubernetes.io/audit=restricted \
	#      pod-security.kubernetes.io/audit-version=latest
	kubectl -n argocd apply -f argocd/argo-rollouts.yaml
	kubectl -n argocd apply -f argocd/projects/system-keptn.yaml
	kubectl -n argocd apply -f argocd/keptn-nats.yaml
	kubectl -n argocd apply -f argocd/keptn-mongodb.yaml
	kubectl -n argocd apply -f argocd/keptn.yaml
#	helm repo add keptn https://charts.keptn.sh
#	helm upgrade --install \
#		keptn keptn/keptn \
#		-n keptn \
#		--create-namespace \
#		--wait \
#		-f kind/kind-values-keptn.yaml
#	helm upgrade --install \
#		helm-service \
#		https://github.com/keptn/keptn/releases/download/$(KEPTN_VERSION)/helm-service-$(KEPTN_VERSION).tgz \
#		-n keptn
#	helm upgrade --install \
#		jmeter-service https://github.com/keptn/keptn/releases/download/0.8.4/jmeter-service-0.8.4.tgz \
#		-n keptn
#	helm upgrade --install \
#			-n keptn \
#		  prometheus-service \
#		  https://github.com/keptn-contrib/prometheus-service/releases/download/0.7.2/prometheus-service-0.7.2.tgz \
#		  --set=prometheus.endpoint="http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090"
#	helm upgrade --install \
#			-n keptn \
#			argo-service \
#			https://github.com/keptn-contrib/argo-service/releases/download/0.9.1/argo-service-0.9.1.tgz
#	#
#	kubectl apply -n monitoring \
# 		-f https://raw.githubusercontent.com/keptn-contrib/prometheus-service/0.7.2/deploy/role.yaml

.PHONY: keptn-gitops-operator-deploy
keptn-gitops-operator-deploy:
	kubectl -n argocd apply -f argocd/projects/system-keptn.yaml
	kubectl -n argocd apply -f argocd/keptn-gitops-operator.yaml

.PHONY: keptn-set-login
keptn-set-login:
	kubectl create secret -n keptn generic bridge-credentials --from-literal="BASIC_AUTH_USERNAME=admin" --from-literal="BASIC_AUTH_PASSWORD=admin" -oyaml --dry-run=client | kubectl replace -f -
	kubectl -n keptn rollout restart deployment bridge
	keptn auth -n keptn --endpoint="http://bridge.127.0.0.1.nip.io"
	# keptn configure bridge –action=expose

.PHONY: keptn-create-project-podtato-head
keptn-create-project-podtato-head:
	keptn create project podtato-head --shipyard=keptn/podtato-head/shipyard.yaml
	keptn create service helloservice --project=podtato-head
	keptn add-resource --project=podtato-head --service=helloservice --all-stages --resource=./helm/helloservice.tgz
	echo "Adding keptn quality-gates to project podtato-head"
	keptn add-resource --project=podtato-head --stage=dev --service=helloservice --resource=keptn/podtato-head/prometheus/sli.yaml --resourceUri=prometheus/sli.yaml
	keptn add-resource --project=podtato-head --stage=dev --service=helloservice --resource=keptn/podtato-head/slo.yaml --resourceUri=slo.yaml
	#
	echo "Adding jmeter load tests to project podtato-head"
	keptn add-resource --project=podtato-head --stage=dev --service=helloservice --resource=keptn/podtato-head/jmeter/load.jmx --resourceUri=jmeter/load.jmx
	keptn add-resource --project=podtato-head --stage=dev --service=helloservice --resource=keptn/podtato-head/jmeter/jmeter.conf.yaml --resourceUri=jmeter/jmeter.conf.yaml
	echo "enable prometheus monitoring"
	keptn configure monitoring prometheus --project=podtato-head --service=helloservice
	echo "trigger delivery"
	keptn trigger delivery --project=podtato-head --service=helloservice \
		--image ghcr.io/podtato-head/podtatoserver:v0.1.1 \
		--values "replicaCount=2" \
		--values "serviceMonitor.enabled=true" \
		--values "serviceMonitor.interval=5s" --values "serviceMonitor.scrapeTimeout=5s"
	#
	# keptn trigger evaluation --project=podtato-head --service=helloservice --stage=dev --timeframe=5m

.PHONY: keptn-deploy-correct-version-podtato-head
keptn-deploy-correct-version-podtato-head:
	keptn trigger delivery --project=podtato-head --service=helloservice \
			--image ghcr.io/podtato-head/podtatoserver:v0.1.1 \
			--values "replicaCount=2" \
			--values "serviceMonitor.enabled=true" \
			--values "serviceMonitor.interval=5s" --values "serviceMonitor.scrapeTimeout=5s"

.PHONY: keptn-deploy-slow-version-podtato-head
keptn-deploy-slow-version-podtato-head:
	keptn trigger delivery --project=podtato-head --service=helloservice \
			--image="ghcr.io/podtato-head/podtatoserver" --tag=v0.1.2

.PHONY: keptn-helloserver-prepare-helm-charts
keptn-helloserver-prepare-helm-charts:
	helm package ./helm/helloserver/ -d helm && mv helm/helloserver-`cat helm/helloserver/Chart.yaml |yq eval '.version' - |tr -d '\n'`.tgz helm/helloservice.tgz

.PHONY: keptn-redeploy-chart-podtato-head
keptn-redeploy-chart-podtato-head:
	make keptn-helloserver-prepare-helm-charts && \
	keptn add-resource --project=podtato-head --service=helloservice --all-stages --resource=./helm/helloservice.tgz && \
	make keptn-deploy-correct-version-podtato-head

.PHONY: keptn-delete-project-podtato-head
keptn-delete-project-podtato-head:
	keptn delete project podtato-head
	kubectl delete ns podtato-head-dev || true
	kubectl delete ns podtato-head-prod || true
	# keptn delete service helloservice -p podtato-head

.PHONY: keptn-create-project-sockshop
keptn-create-project-sockshop:
	keptn create project sockshop --shipyard=keptn/sockshop/shipyard.yaml
	keptn create service carts --project=sockshop
	keptn add-resource --project=sockshop --stage=prod --service=carts --resource=keptn/sockshop/jmeter/load.jmx --resourceUri=jmeter/load.jmx
	keptn add-resource --project=sockshop --stage=prod --service=carts --resource=keptn/sockshop/slo-quality-gates.yaml --resourceUri=slo.yaml
	keptn configure monitoring prometheus --project=sockshop --service=carts
	keptn add-resource --project=sockshop --stage=prod --service=carts --resource=keptn/sockshop/sli-config-argo-prometheus.yaml --resourceUri=prometheus/sli.yaml
	#
	argocd app create --name carts-prod \
		--repo https://github.com/keptn/examples.git --dest-server https://kubernetes.default.svc \
		--dest-namespace sockshop-prod --path onboarding-carts/argo/carts --revision 0.11.0 \
		--sync-policy none

.PHONY: test-network-apply-assets
test-network-apply-assets:
	kubectl get ns test-network 1>/dev/null 2>/dev/null || kubectl create ns test-network
	kubectl apply -n test-network -k tests/assets/k8s/podinfo --wait=true
	kubectl apply -n test-network -f tests/assets/k8s/client  --wait=true
	kubectl apply -n test-network -f tests/assets/k8s/networkpolicy --wait=true

.PHONY: test-network-check-status
test-network-check-status:
#	linkerd top deployment/podinfo --namespace test-network
#	linkerd tap deployment/client --namespace test-network
	kubectl exec -n test-network deploy/client -c client -- curl -s podinfo:9898

.PHONY: run-ginkgo
run-ginkgo:
	cd tests/e2e && go test
