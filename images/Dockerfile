# Dockerfile for scale-ci-prom

FROM quay.io/openshift-scale/scale-ci-workload:latest

MAINTAINER Red Hat OpenShift Performance and Scale

ENV KUBECONFIG /root/.kube/config

RUN mkdir -p /root/.kube && mkdir -p /var/lib/pbench-agent/tools-default && git clone https://github.com/chaitanyaenr/ocp-diagnosis.git /root/ocp-diagnosis

COPY run.sh /root/run.sh

ENTRYPOINT ["/root/run.sh"]
