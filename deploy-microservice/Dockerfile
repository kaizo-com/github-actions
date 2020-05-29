FROM google/cloud-sdk:alpine

ENV KUSTOMIZE_VERSION="3.5.5"
ENV KUSTOMIZE_ARCHIVE_URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
ENV KUSTOMIZE_ARCHIVE="/tmp/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"

ENV KUBECTL_VERSION="v1.18.3"
ENV KUBECTL_ARCHIVE_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

RUN \
  apk --no-cache add curl gettext && \
  curl -L --output $KUSTOMIZE_ARCHIVE $KUSTOMIZE_ARCHIVE_URL && \
  tar -xvzf $KUSTOMIZE_ARCHIVE -C /usr/local/bin && \
  chmod +x /usr/local/bin/kustomize && \
  kustomize version && \
  curl -L --output /usr/local/bin/kubectl $KUBECTL_ARCHIVE_URL && \
  chmod +x /usr/local/bin/kubectl && \
  kubectl version --client

ARG SERVICE_NAME
ARG TARGET_ENV
ARG REVISION
ARG IMAGE
ARG GCP_PROJECT_ID
ARG GCP_CLUSTER_NAME
ARG GCP_ZONE
ARG GCP_SERVICE_ACCOUNT_KEY

COPY entrypoint.sh /entrypoint.sh
COPY templates/ /templates

ENTRYPOINT ["/entrypoint.sh"]
