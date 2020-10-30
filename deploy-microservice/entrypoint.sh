#! /usr/bin/env bash

if [ $# -ne 8 ]; then
  echo "Not enough arguments supplied"
  echo "Usage: entrypoint.sh [SERVICE_NAME] [TARGET_ENV] [REVISION] [IMAGE] [GCP_PROJECT_ID] [GCP_CLUSTER_NAME] [GCP_ZONE] [GCP_SERVICE_ACCOUNT_KEY]"
  exit 1
fi

export SERVICE_NAME=$1
export TARGET_ENV=$2
export REVISION=$3
export IMAGE=$4
export GCP_PROJECT_ID=$5
export GCP_CLUSTER_NAME=$6
export GCP_ZONE=$7
export GCP_SERVICE_ACCOUNT_KEY=$8

echo "SERVICE_NAME:     $SERVICE_NAME"
echo "TARGET_ENV:       $TARGET_ENV"
echo "REVISION:         $REVISION"
echo "IMAGE:            $IMAGE"
echo "GCP_PROJECT_ID:   $GCP_PROJECT_ID"
echo "GCP_CLUSTER_NAME: $GCP_CLUSTER_NAME"
echo "GCP_ZONE:         $GCP_ZONE"
echo ""
echo "HOME:             $HOME"
echo "PWD:              $PWD"
echo "Working Dir:      $GITHUB_WORKSPACE"
echo "Repo:             $GITHUB_REPOSITORY"
echo "Sha:              $GITHUB_SHA"
echo ""
echo "Kustomize:"
echo "    $(kustomize version)"
echo "Kubectl:"
echo "    $(kubectl version --client)"

KUSTOMIZE_DIR=".github/k8s/"
TEMPLATES_DIR="/templates/"

echo ""
echo "Contents of project patches dir:"
ls -al $KUSTOMIZE_DIR

echo ""
echo "Setting gcloud defaults..."
gcloud config set core/project $GCP_PROJECT_ID
gcloud config set compute/zone $GCP_ZONE

echo ""
echo "Writing the GCP service account credentials to a tmp file..."
SERVICE_ACCOUNT_KEY_FILE=$(mktemp)
echo "$GCP_SERVICE_ACCOUNT_KEY" | base64 -d > $SERVICE_ACCOUNT_KEY_FILE

echo "Authenticating gcloud for project '$GCP_PROJECT_ID'..."
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_KEY_FILE

echo "Authenticating kubectl for cluster '$GCP_CLUSTER_NAME'..."
gcloud container clusters get-credentials $GCP_CLUSTER_NAME

echo ""
echo "Make sure we can connect to the cluster."
echo "Fetching the target namespace..."
kubectl get namespace ${TARGET_ENV} -o yaml | sed 's/^/  /'

echo ""
echo "Initializing kustomizations..."
cd $KUSTOMIZE_DIR
KUSTOMIZE_FILE_NAME="kustomization-${TARGET_ENV}.yaml"
touch ${KUSTOMIZE_FILE_NAME}
kustomize edit set namespace $TARGET_ENV

echo "Generating kustomization base resources..."
mkdir base
envsubst < $TEMPLATES_DIR/deployment-base.yaml > base/deployment-base.yaml
envsubst < $TEMPLATES_DIR/service-base.yaml > base/service-base.yaml
kustomize edit add resource base/deployment-base.yaml
kustomize edit add resource base/service-base.yaml

echo "Adding build info kustomizations..."
kustomize edit add annotation version:git-$REVISION
kustomize edit set image $SERVICE_NAME=$IMAGE

echo "Adding project-specific patches..."
for patch in *.yaml; do
  if [ "$patch" != "${KUSTOMIZE_FILE_NAME}" ]; then
    echo "  Adding patch '${patch}'..."
    kustomize edit add patch ${patch}
  fi
done

if [ -d $TARGET_ENV ]; then
  for patch in $TARGET_ENV/*.yaml; do
      echo "  Adding patch '${patch}'..."
      kustomize edit add patch ${patch}
  done
fi

echo "Contents of ${KUSTOMIZE_FILE_NAME}:"
cat ${KUSTOMIZE_FILE_NAME} | sed 's/^/  /'

echo ""
echo "Kustomizing resources..."
kustomize build . > kustomized.yaml
cat kustomized.yaml | sed 's/^/  /'

echo ""
echo "Deploying to ${TARGET_ENV}..."
kubectl --namespace $TARGET_ENV apply -f kustomized.yaml --record
kubectl --namespace $TARGET_ENV rollout status deployment.v1.apps/${SERVICE_NAME}-deployment

echo ""
echo "Updated Resources:"
echo "=========================================================="
kubectl --namespace $TARGET_ENV describe -f kustomized.yaml

echo "=========================================================="
echo "Updated Pods:"
echo "=========================================================="
kubectl --namespace $TARGET_ENV get pod | grep $SERVICE_NAME

echo "=========================================================="
echo "Updated Service:"
echo "=========================================================="
kubectl --namespace $TARGET_ENV get svc | grep $SERVICE_NAME
