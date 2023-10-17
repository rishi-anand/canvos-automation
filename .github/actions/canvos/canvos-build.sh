# Create reports folder

set -e
set -x

git clone https://github.com/spectrocloud/CanvOS.git
cd CanvOS
ls
if [ -n "$canvos_tag" ]; then
  echo "The environment variable is not empty: $canvos_tag"
  git checkout $canvos_tag
fi

IFS='+' read -ra OS_PARTS <<< "$os_distribution"
echo "CUSTOM_TAG=$custom_image_tag" >> .arg
echo "IMAGE_REGISTRY=$image_registry" >> .arg
echo "IMAGE_REPO=$image_repo" >> .arg
echo "OS_DISTRIBUTION=${OS_PARTS[0]}" >> .arg
echo "OS_VERSION=${OS_PARTS[1]}" >> .arg
echo "K8S_DISTRIBUTION=$k8s_distribution" >> .arg
echo "ISO_NAME=$iso_name" >> .arg
echo "ARCH=$arch" >> .arg

if [ -n "$base_image" ]; then
  echo "The base image variable is not empty: $base_image"
  echo "BASE_IMAGE=$base_image" >> .arg
else
  echo "The base image var is empty"
fi

cat .arg