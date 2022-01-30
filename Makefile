# Set environment variables
export CLUSTER_NAME?=keptn
#export CILIUM_VERSION?=1.10.6
export CILIUM_VERSION?=1.11.1
export KEPTN_VERSION?=0.12.0
export TRIVY_IMAGE_CHECK=1

# kind image list
# image: kindest/node:v1.20.2@sha256:15d3b5c4f521a84896ed1ead1b14e4774d02202d5c65ab68f30eeaf310a3b1a7
# image: kindest/node:v1.21.2@sha256:9d07ff05e4afefbba983fac311807b3c17a5f36e7061f6cb7e2ba756255b2be4
# image: kindest/node:v1.22.4@sha256:ca3587e6e545a96c07bf82e2c46503d9ef86fc704f44c17577fca7bcabf5f978
# image: kindest/node:v1.23.3@sha256:0df8215895129c0d3221cda19847d1296c4f29ec93487339149333bd9d899e5a
export KIND_NODE_IMAGE="kindest/node:v1.23.3@sha256:0df8215895129c0d3221cda19847d1296c4f29ec93487339149333bd9d899e5a"

.PHONY: kind-all
#kind-all: kind-create kx-kind cilium-prepare-images cilium-install deploy-prometheus-stack nginx-ingress-install keptn-prepare-images keptn-deploy deploy-cert-manager
kind-all: kind-create kx-kind cilium-prepare-images cilium-install deploy-prometheus-stack nginx-ingress-install keptn-prepare-images  # keptn-deploy

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

.PHONY: cilium-prepare-images
cilium-prepare-images:
	# pull image locally
	docker pull quay.io/cilium/cilium:v$(CILIUM_VERSION)
	docker pull quay.io/cilium/hubble-ui:v0.8.5
	docker pull quay.io/cilium/hubble-ui-backend:v0.8.5
	docker pull quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=1 quay.io/cilium/cilium:v$(CILIUM_VERSION)
	trivy image --severity=HIGH --exit-code=1 quay.io/cilium/hubble-ui:v0.8.5
	trivy image --severity=HIGH --exit-code=1 quay.io/cilium/hubble-ui-backend:v0.8.5
	trivy image --severity=HIGH --exit-code=1 quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
endif
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/cilium:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui-backend:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)

.PHONY: cilium-install
cilium-install:
	# Add the Cilium repo
	helm repo add cilium https://helm.cilium.io/
	# install/upgrade the chart
	helm upgrade --install cilium cilium/cilium --version $(CILIUM_VERSION) \
	   -f kind/kind-values-cilium-hubble.yaml \
	   -f kind/kind-values-cilium-service-monitors.yaml \
   	   --wait \
	   --namespace kube-system \
	   --set operator.replicas=1 \
	   --set nodeinit.enabled=true \
	   --set kubeProxyReplacement=partial \
	   --set hostServices.enabled=false \
	   --set externalIPs.enabled=true \
	   --set nodePort.enabled=true \
	   --set hostPort.enabled=true \
	   --set bpf.masquerade=false \
	   --set image.pullPolicy=IfNotPresent \
	   --set ipam.mode=kubernetes \
	   --set prometheus.enabled=true \
	   --set operator.prometheus.enabled=true

.PHONY: keptn-prepare-images
keptn-prepare-images:
	# pull image locally
	docker pull docker.io/bitnami/mongodb:4.4.9-debian-10-r0
	docker pull docker.io/keptn/distributor:$(KEPTN_VERSION)
	docker pull docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	docker pull nats:2.1.9-alpine3.12
	docker pull synadia/prometheus-nats-exporter:0.5.0
	docker pull docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)
	docker pull docker.io/keptn/jmeter-service:0.8.4
	docker pull keptncontrib/prometheus-service:0.7.2
ifeq ($(TRIVY_IMAGE_CHECK), 1)
	trivy image --severity=HIGH --exit-code=0 docker.io/bitnami/mongodb:4.4.9-debian-10-r0
	trivy image --severity=HIGH --exit-code=1 docker.io/keptn/distributor:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 nats:2.1.9-alpine3.12
	trivy image --severity=HIGH --exit-code=1 synadia/prometheus-nats-exporter:0.5.0
	trivy image --severity=HIGH --exit-code=1 docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)
	trivy image --severity=HIGH --exit-code=0 docker.io/keptn/jmeter-service:0.8.4
	trivy image --severity=HIGH --exit-code=0 keptncontrib/prometheus-service:0.7.2
endif
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) docker.io/bitnami/mongodb:4.4.9-debian-10-r0
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/distributor:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) nats:2.1.9-alpine3.12
	kind load docker-image --name $(CLUSTER_NAME) synadia/prometheus-nats-exporter:0.5.0
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/jmeter-service:0.8.4
	kind load docker-image --name $(CLUSTER_NAME) keptncontrib/prometheus-service:0.7.2

.PHONY: keptn-deploy
keptn-deploy:
	helm repo add keptn https://charts.keptn.sh
	helm upgrade --install \
		keptn keptn/keptn \
		-n keptn \
		--create-namespace \
		--wait \
		--set=control-plane.ingress.host=bridge.127.0.0.1.nip.io \
		-f kind/kind-values-keptn.yaml
	helm upgrade --install \
		helm-service \
		https://github.com/keptn/keptn/releases/download/$(KEPTN_VERSION)/helm-service-$(KEPTN_VERSION).tgz \
		-n keptn
	helm upgrade --install \
		jmeter-service https://github.com/keptn/keptn/releases/download/0.8.4/jmeter-service-0.8.4.tgz \
		-n keptn
	helm upgrade --install \
			-n keptn \
		  prometheus-service \
		  https://github.com/keptn-contrib/prometheus-service/releases/download/0.7.2/prometheus-service-0.7.2.tgz \
		  --set=prometheus.endpoint="http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090"
	#
	kubectl apply -n monitoring \
 		-f https://raw.githubusercontent.com/keptn-contrib/prometheus-service/0.7.2/deploy/role.yaml
	#
	kubectl apply -f keptn/crd-istio-destinationrules.yaml \
				  -f keptn/crd-istio-virtualservices.yaml
	# https://raw.githubusercontent.com/keptn-sandbox/keptn-in-a-box/master/resources/istio/public-gateway.yaml

.PHONY: keptn-set-login
keptn-set-login:
	kubectl create secret -n keptn generic bridge-credentials --from-literal="BASIC_AUTH_USERNAME=admin" --from-literal="BASIC_AUTH_PASSWORD=admin" -oyaml --dry-run=client | kubectl replace -f -
	kubectl -n keptn rollout restart deployment bridge
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

.PHONY: prepare-helm-charts
prepare-helm-charts:
	helm package ./helm/helloserver/ -d helm && mv helm/helloserver-`cat helm/helloserver/Chart.yaml |yq eval '.version' - |tr -d '\n'`.tgz helm/helloservice.tgz

.PHONY: keptn-delete-project-podtato-head
keptn-delete-project-podtato-head:
	keptn delete project podtato-head
	kubectl delete ns podtato-head-dev || true
	kubectl delete ns podtato-head-prod || true
	# keptn delete service helloservice -p podtato-head

.PHONY: nginx-ingress-install
nginx-ingress-install:
	docker pull k8s.gcr.io/ingress-nginx/controller:v1.1.1
	kind load docker-image --name $(CLUSTER_NAME) k8s.gcr.io/ingress-nginx/controller:v1.1.1
	helm repo add --force-update ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	  --namespace ingress-nginx \
	  --create-namespace \
	-f kind/kind-values-ingress-nginx.yaml

#	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
#	kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission

#.PHONY: deploy-cert-manager
#deploy-cert-manager:
#	kind/cert-manager_install.sh

.PHONY: deploy-prometheus-stack
deploy-prometheus-stack:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm upgrade --install \
	prometheus-stack \
	prometheus-community/kube-prometheus-stack \
	--namespace monitoring \
    --create-namespace \
    -f kind/kind-values-prometheus.yaml

#.PHONY: k8s-apply
#k8s-apply:
#	kubectl get ns cilium-linkerd 1>/dev/null 2>/dev/null || kubectl create ns cilium-linkerd
#	kubectl apply -k k8s/podinfo -n cilium-linkerd
#	kubectl apply -f k8s/client
#	kubectl apply -f k8s/networkpolicy
#
#.PHONY: check-status
#check-status:
#	linkerd top deployment/podinfo --namespace cilium-linkerd
#	linkerd tap deployment/client --namespace cilium-linkerd
#	kubectl exec deploy/client -n cilium-linkerd -c client -- curl -s podinfo:9898
