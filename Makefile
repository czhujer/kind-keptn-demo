# Set environment variables
export CLUSTER_NAME?=keptn
#export CILIUM_VERSION?=1.10.6
export CILIUM_VERSION?=1.11.1
export KEPTN_VERSION?=0.12.0

.PHONY: kind-all
#kind-all: kind-create kx-kind cilium-install keptn-load-images deploy-cert-manager install-nginx-ingress deploy-prometheus-stack
kind-all: kind-create kx-kind cilium-install keptn-load-images install-nginx-ingress # keptn-deploy

.PHONY: kind-create
kind-create:
	kind --version
	kind create cluster --name $(CLUSTER_NAME) --config="kind/kind-config.yaml"
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

.PHONY: cilium-install
cilium-install:
	# pull image locally
	docker pull quay.io/cilium/cilium:v$(CILIUM_VERSION)
	docker pull quay.io/cilium/hubble-ui:v0.8.5
	docker pull quay.io/cilium/hubble-ui-backend:v0.8.5
	docker pull quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/cilium:v$(CILIUM_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-ui-backend:v0.8.5
	kind load docker-image --name $(CLUSTER_NAME) quay.io/cilium/hubble-relay:v$(CILIUM_VERSION)
	# Add the Cilium repo
	helm repo add cilium https://helm.cilium.io/
	# install/upgrade the chart
	helm upgrade --install cilium cilium/cilium --version $(CILIUM_VERSION) \
	   -f kind/kind-values-cilium-hubble.yaml \
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
	   --set ipam.mode=kubernetes

.PHONY: keptn-load-images
keptn-load-images:
	# pull image locally
	docker pull docker.io/bitnami/mongodb:4.4.9-debian-10-r0
	docker pull docker.io/keptn/distributor:$(KEPTN_VERSION)
	docker pull docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	docker pull nats:2.1.9-alpine3.12
	docker pull synadia/prometheus-nats-exporter:0.5.0
	docker pull docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)
	# Load the image onto the cluster
	kind load docker-image --name $(CLUSTER_NAME) docker.io/bitnami/mongodb:4.4.9-debian-10-r0
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/distributor:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/mongodb-datastore:$(KEPTN_VERSION)
	kind load docker-image --name $(CLUSTER_NAME) nats:2.1.9-alpine3.12
	kind load docker-image --name $(CLUSTER_NAME) synadia/prometheus-nats-exporter:0.5.0
	kind load docker-image --name $(CLUSTER_NAME) docker.io/keptn/shipyard-controller:$(KEPTN_VERSION)

KIND_IP := $(shell docker container inspect $(CLUSTER_NAME)-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}')
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
	kubectl apply -f keptn/crd-istio-destinationrules.yaml \
				  -f keptn/crd-istio-virtualservices.yaml
	# https://raw.githubusercontent.com/keptn-sandbox/keptn-in-a-box/master/resources/istio/public-gateway.yaml

.PHONY: keptn-set-login
keptn-set-login:
	kubectl create secret -n keptn generic bridge-credentials --from-literal="BASIC_AUTH_USERNAME=admin" --from-literal="BASIC_AUTH_PASSWORD=admin" -oyaml --dry-run=client | kubectl replace -f -
	kubectl -n keptn rollout restart deployment bridge
    # keptn configure bridge –action=expose

.PHONY: keptn-create-project-kiosk
keptn-create-project-kiosk:
	keptn create project kiosk --shipyard=keptn/kiosk/shipyard.yaml
	keptn create service helloservice --project=kiosk
	keptn add-resource --project=kiosk --service=helloservice --all-stages --resource=./helm/helloservice.tgz
	keptn trigger delivery --project=kiosk --service=helloservice --image ghcr.io/podtato-head/podtatoserver:v0.1.1
	#
#	keptn create service helloservice-new --project=kiosk
#	keptn add-resource --project=kiosk --service=helloservice-new --all-stages --resource=./helm/helloservice-new.tgz
#	keptn trigger delivery --project=kiosk --service=helloservice-new --image ghcr.io/podtato-head/podtatoserver:v0.1.1

.PHONY: prepare-helm-charts
prepare-helm-charts:
	cd helm
	tar -czvf helloservice.tgz helloserver/

.PHONY: install-nginx-ingress
install-nginx-ingress:
	docker pull k8s.gcr.io/ingress-nginx/controller:v1.1.1
	kind load docker-image --name $(CLUSTER_NAME) k8s.gcr.io/ingress-nginx/controller:v1.1.1
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ingress-nginx-admission

#.PHONY: deploy-cert-manager
#deploy-cert-manager:
#	kind/cert-manager_install.sh

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
