#!/bin/sh
kind create cluster
istioctl install --set meshConfig.outboundTrafficPolicy.mode=REGISTRY_ONLY --set profile=demo -y
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
kubectl apply -f https://kind.sigs.k8s.io/examples/loadbalancer/metallb-config.yaml
ingress=$(kubectl -n istio-system get service "istio-ingressgateway" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

openssl req -new -x509 -days 1 -keyout certificates/ca-key.pem -out certificates/ca-crt.pem -subj "/C=RU/ST=Moscow/L=Moscow/O=Example/OU=Example/CN=myhost.localhost"
openssl genrsa -out certificates/application-key.pem 4096
openssl req -new -key certificates/application-key.pem -out certificates/application-csr.pem -subj "/C=RU/ST=Moscow/L=Moscow/O=Example/OU=Example/CN=$ingress"
openssl x509 -req -days 9999 -in certificates/application-csr.pem -CA certificates/ca-crt.pem -CAkey certificates/ca-key.pem -CAcreateserial -out certificates/application-crt.pem
openssl verify -CAfile certificates/ca-crt.pem certificates/application-crt.pem
openssl genrsa -out certificates/user-key.pem 4096
openssl req -new -key certificates/user-key.pem -out certificates/user-csr.pem -subj "/C=RU/ST=Moscow/L=Moscow/O=Example/OU=Example/CN=myotherhost.localhost"
openssl x509 -req -days 9999 -in certificates/user-csr.pem -CA certificates/ca-crt.pem -CAkey certificates/ca-key.pem -CAcreateserial -out certificates/user-crt.pem
openssl verify -CAfile certificates/ca-crt.pem certificates/user-crt.pem

kubectl create namespace devops
kubectl label namespace devops istio-injection=enabled
kubectl create -n istio-system secret generic frontend-certs --from-file=tls.key=certificates/application-key.pem --from-file=tls.crt=certificates/application-crt.pem --from-file=ca.crt=certificates/ca-crt.pem
kubectl apply -f egress.yml
kubectl apply -f ingress.yml
kubectl apply -f service-a.yml
kubectl apply -f service-b.yml
kubectl wait --namespace devops --for=condition=ready pod --selector=app=service-b --timeout=90s
kubectl wait --namespace devops --for=condition=ready pod --selector=app=service-a --timeout=90s
kubectl port-forward deploy/service-a 9090:9090 -n devops & echo "DONE!"
echo "Establishing port-dorwarding... " && sleep 10

echo -e "\n\nRunning the test command:\ncurl --cert certificates/user-crt.pem --key certificates/user-key.pem --cacert certificates/ca-crt.pem http://127.0.0.1:9090"
curl --cert certificates/user-crt.pem --key certificates/user-key.pem --cacert certificates/ca-crt.pem http://127.0.0.1:9090
