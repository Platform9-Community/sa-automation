# these are set from your environment
KUBECONFIG ?= path_to_a_kubeconfig
KUBE_CONTEXT ?= default

# Customize any of the below
CHART_NAME := node-svc-checker
CHART_REPO := ./helm
CHART_VERSION := 0.1.0
NAMESPACE := nsc-system
# end customizations

CHART_VERSION_SAFE := $(subst .,-,$(CHART_VERSION))
RELEASE_NAME := $(CHART_NAME)-$(CHART_VERSION_SAFE)
TIMESTAMP := $(shell date '+%Y-%m-%d-%s')

HELM_COMMON := $(RELEASE_NAME) $(CHART_REPO)/$(CHART_NAME) \
	--namespace $(NAMESPACE) \
	--create-namespace \
	--kubeconfig $(KUBECONFIG) \
	--kube-context $(KUBE_CONTEXT) \
	--version $(CHART_VERSION) \
	--set namespace=$(NAMESPACE) \
	--values values-$(RELEASE_NAME).yaml

KUBECTL_COMMON := --context $(KUBE_CONTEXT) --kubeconfig $(KUBECONFIG)

default:
	@echo "Run one of the following targets: generate_values, template, install, upgrade, \
	uninstall, list"

generate_values:
	( [[ -f values-$(RELEASE_NAME).yaml ]] && cp values-$(RELEASE_NAME).yaml values_$(RELEASE_NAME).$(TIMESTAMP).yaml ) || true
	@echo "Saving values file as values-$(RELEASE_NAME).yaml"
	helm show values $(CHART_REPO)/$(CHART_NAME) \
		--version $(CHART_VERSION) > values-$(RELEASE_NAME).yaml

template:
	helm template $(HELM_COMMON)

install:
	helm upgrade --install $(HELM_COMMON)

upgrade:
	helm upgrade $(HELM_COMMON)

uninstall:
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

list:
	helm list --filter $(CHART_NAME) \
		--all-namespaces --kubeconfig $(KUBECONFIG) --kube-context $(KUBE_CONTEXT)
	@echo
	kubectl $(KUBECTL_COMMON) get pods -o wide \
		-l app.kubernetes.io/name=node-svc-checker -A
