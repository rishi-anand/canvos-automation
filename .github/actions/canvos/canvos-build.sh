# Create reports folder

#set -e
set -x

IFS='+' read -ra OS_PARTS <<< "$os_distribution"

IMAGE_REGISTRY_VAR="${image_registry%/*}"
IMAGE_REPO_VAR="${image_registry##*/}"
WORKDIR=$(pwd)
CANVOS_REPO=$WORKDIR/CanvOS
IMAGE_BUILDER_REPO=$WORKDIR/stylus-image-builder
DOCKER_IMAGES=

echo "Github username is $github_user"
custom_image_tag=$github_user-$custom_image_tag
echo "Custom github tag is $custom_image_tag"

function git_clone_canvos() {
  git clone https://github.com/spectrocloud/CanvOS.git
  cd $CANVOS_REPO
  ls
  if [ -n "$canvos_tag" ]; then
    echo "The environment variable is not empty: $canvos_tag"
    git checkout $canvos_tag
  fi
}

# -------------------- ISO ------------------

function create_arg_file() {
  echo "CUSTOM_TAG=$custom_image_tag" >> .arg
  echo "IMAGE_REGISTRY=$IMAGE_REGISTRY_VAR" >> .arg
  echo "IMAGE_REPO=$IMAGE_REPO_VAR" >> .arg
  echo "OS_DISTRIBUTION=${OS_PARTS[0]}" >> .arg
  echo "OS_VERSION=${OS_PARTS[1]}" >> .arg
  echo "K8S_DISTRIBUTION=$k8s_distribution" >> .arg
  echo "ISO_NAME=canvos-installer-$custom_image_tag" >> .arg
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
    ./earthly.sh +build-all-images
  elif [ "$build_type" = "Provider" ]; then
    echo "Building only Provider Images"
    ./earthly.sh +build-provider-images
  fi
}

# -------------------- VMDK ------------------
function git_clone_stylus_image_builder() {
  git clone https://github.com/spectrocloud/stylus-image-builder.git
  cd $IMAGE_BUILDER_REPO
  ls
}


# -------------------- Content Push ------------------

function upload_to_vsphere_datastore() {
  govc datastore.upload $CANVOS_REPO/build/canvos-installer-"$custom_image_tag".iso ISO/canvos-action/canvos-installer-"$custom_image_tag".iso
}

function upload_iso_to_s3() {
  if [ "$upload_iso_to_s3" = "true" ]; then
    aws s3 cp $CANVOS_REPO/build/canvos-installer-"$custom_image_tag".iso s3://rishi-public-bucket/canvos-action
  fi
}

function push_docker_images() {
    image_list=$(docker images | grep $custom_image_tag | grep $IMAGE_REGISTRY_VAR | grep -v linux)
    while read -r line; do
        image_name=$(echo "$line" | awk '{print $1}')
        image_tag=$(echo "$line" | awk '{print $2}')
        echo "Pushing docker image $image_name:$image_tag"
        docker push "$image_name:$image_tag"
        DOCKER_IMAGES="$image_name:$image_tag\n$DOCKER_IMAGES"
    done <<< "$image_list"
    echo "Pushed $DOCKER_IMAGES"
}

#notify() {
#  ISO=ISO/canvos-action/canvos-installer-"$custom_image_tag".iso
#  CLI_RUN_CMD='./palette-edge-cli-linux-amd64 generate --os-flavor ubuntu-22 --k8s-flavor kubeadm --push-image-repository gcr.io/spectro-testing --spectro-version '$VERSION
#  # shellcheck disable=SC2016
#  MSG='"CUSTOM_TAG: `'$BRANCH'`\nVersion: `'$VERSION'`,`latest`\nStylus Image: `'$IMG_REPO'/stylus:'$VERSION'`\nISO Location (vsanDatastore1):`'$ISO'`\n\nLinux Palette Edge Content Cli link: '${CONTENT_CLI_LINK}'\n\nGit Head: ```'$GIT_MSG'```\nEdge Cli Sample Cmd: ```'$CLI_RUN_CMD'```"'
#  PAYLOAD='
#  {
#    "blocks": [
#      {
#        "type": "section",
#        "text": {
#          "type": "mrkdwn",
#          "text": "*Stylus Daily Build - '${TODAY}' *"
#        }
#      },
#      {
#        "type": "divider"
#      },
#      {
#        "type": "section",
#        "text": {
#          "type": "mrkdwn",
#          "text": '$MSG'
#        }
#      }
#    ]
#  }'
#  curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" $CHANNEL_URL
#}

function clean() {
  sudo rm -rf $CANVOS_REPO/build/*
  docker system prune -a -f
}

# -------------------- Executions ------------------
git_clone_canvos
create_arg_file
login_gcr
build_artifacts
push_docker_images

if [ "$build_type" = "ISO-Provider" ]; then
  upload_iso_to_s3
  upload_to_vsphere_datastore
fi

if [ "$output_artifact" = "ISO" ]; then
  clean
elif [ "$build_type" = "VMDK" ]; then
  echo "Not supported yet"
elif [ "$build_type" = "OVA" ]; then
  echo "Not supported yet"
elif [ "$build_type" = "RAW" ]; then
  echo "Not supported yet"
fi