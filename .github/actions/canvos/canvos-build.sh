# Create reports folder

#set -e
set -x

IFS='+' read -ra OS_PARTS <<< "$os_distribution"

IMAGE_REGISTRY_VAR="${IMAGE_REGISTRY%/*}"
IMAGE_REPO_VAR="${IMAGE_REGISTRY##*/}"

function git_clone() {
  git clone https://github.com/spectrocloud/CanvOS.git
  cd CanvOS
  ls
  if [ -n "$canvos_tag" ]; then
    echo "The environment variable is not empty: $canvos_tag"
    git checkout $canvos_tag
  fi
}

function create_arg_file() {
  echo "CUSTOM_TAG=$custom_image_tag" >> .arg
  echo "IMAGE_REGISTRY=$IMAGE_REGISTRY_VAR" >> .arg
  echo "IMAGE_REPO=$IMAGE_REPO_VAR" >> .arg
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
}

function login_gcr() {
  echo $GCP_SPECTRO_DEV_PUBLIC_BASE64_ENCODED_JSON | base64 -d > /tmp/spectro-dev.json
  docker login -u _json_key --password-stdin https://gcr.io < /tmp/spectro-dev.json
}

function build_artifacts() {
  if [ "$build_type" = "ISO-Provider" ]; then
    echo "Building ISO & Provider Images"
    ./earthly.sh --push +build-all-images
  elif [ "$build_type" = "Provider" ]; then
    echo "Building only Provider Images"
    ./earthly.sh --push +build-provider-images
  fi
}

function clean() {
  rm -rf build/*
  docker system prune -a -y
}

function upload_to_vsphere_datastore() {
  govc datastore.upload "$iso_name".iso ISO/canvos-action/"$iso_name".iso
}

function push_docker_images() {
    image_list=$(docker images | grep $custom_image_tag)
    while read -r line; do
        image_name=$(echo "$line" | awk '{print $1}')
        image_tag=$(echo "$line" | awk '{print $2}')
        docker push "$image_name:$image_tag"
    done <<< "$image_list"
}

git_clone
create_arg_file
login_gcr
build_artifacts
upload_to_vsphere_datastore