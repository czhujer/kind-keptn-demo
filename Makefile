# Set environment variables
export CLUSTER_NAME?=kind-keptn
#export CILIUM_VERSION?=1.10.6
export CILIUM_VERSION?=1.11.1

.PHONY: kind-create
kind-create:
	kind --version
	kind create cluster --name $(CLUSTER_NAME) --config="kind/kind-config.yaml"

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
	# Load the image onto the cluster
	kind load docker-image \
 		--name $(CLUSTER_NAME) \
 		quay.io/cilium/cilium:v$(CILIUM_VERSION)
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
