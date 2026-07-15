#!/bin/bash
# Install Gateway API CRDs
# Version: v1.2.0 (standard + experimental for Cilium)

set -euo pipefail

GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.2.0}"
STANDARD_URL="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/standard"
EXPERIMENTAL_URL="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/experimental"

echo "Installing Gateway API CRDs version ${GATEWAY_API_VERSION}..."
echo ""

echo "Installing standard CRDs..."
kubectl apply -f "${STANDARD_URL}/gateway.networking.k8s.io_gatewayclasses.yaml"
kubectl apply -f "${STANDARD_URL}/gateway.networking.k8s.io_gateways.yaml"
kubectl apply -f "${STANDARD_URL}/gateway.networking.k8s.io_httproutes.yaml"
kubectl apply -f "${STANDARD_URL}/gateway.networking.k8s.io_referencegrants.yaml"

echo ""
echo "Installing experimental CRDs (required by Cilium)..."
kubectl apply -f "${EXPERIMENTAL_URL}/gateway.networking.k8s.io_grpcroutes.yaml"
kubectl apply -f "${EXPERIMENTAL_URL}/gateway.networking.k8s.io_tlsroutes.yaml"

echo ""
echo "Gateway API CRDs installed successfully!"
echo ""
echo "Verify installation:"
echo "  kubectl get crd | grep gateway"
