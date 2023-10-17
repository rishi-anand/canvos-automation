# Create reports folder

set -e
set -x

git clone https://github.com/spectrocloud/CanvOS.git
cd CanvOS
ls
if [ -n "$CANVOS_TAG" ]; then
  echo "The environment variable is not empty: $CANVOS_TAG"
  git checkout $CANVOS_TAG
fi

IFS='+' read -ra OS_PARTS <<< "$OS_DISTRIBUTION"
echo "CUSTOM_TAG=$CUSTOM_IMAGE_TAG" >> .arg
echo "IMAGE_REGISTRY=$IMAGE_REGISTRY" >> .arg
echo "IMAGE_REPO=$IMAGE_REPO" >> .arg
echo "OS_DISTRIBUTION=${OS_PARTS[0]}" >> .arg
echo "OS_VERSION=${OS_PARTS[1]}" >> .arg
echo "K8S_DISTRIBUTION=$K8S_DISTRIBUTION" >> .arg
echo "ISO_NAME=$ISO_NAME" >> .arg
echo "ARCH=$ARCH" >> .arg

if [ -n "$BASE_IMAGE" ]; then
  echo "The base image variable is not empty: $BASE_IMAGE"
  echo "BASE_IMAGE=$BASE_IMAGE" >> .arg
else
  echo "The base image var is empty"
fi

cat .arg