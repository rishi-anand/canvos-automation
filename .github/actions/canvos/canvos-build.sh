# Create reports folder

set -e
set -x

IFS='+' read -ra OS_PARTS <<< "$os_distribution"

WORKDIR=$(pwd)
CANVOS_REPO=$WORKDIR/CanvOS
IMAGE_BUILDER_REPO=$WORKDIR/stylus-image-builder
OVA_BUILDER_REPO=$WORKDIR/ova
ISO_NAME=canvos-${OS_PARTS[0]}-${OS_PARTS[1]}-$custom_image_tag
S3_FOLDER="s3://rishi-public-bucket/canvos-action/${OS_PARTS[0]}-${OS_PARTS[1]}-$github_user-$canvos_tag"
DOCKER_IMAGES=
ARGS_FILE=

echo "Github username is $github_user"
custom_image_tag=$github_user-$custom_image_tag
echo "Custom github tag is $custom_image_tag & build type is $build_type"

function git_clone_canvos() {
  git clone https://github.com/spectrocloud/CanvOS.git
  cd $CANVOS_REPO
  ls
  if [ -n "$canvos_tag" ]; then
    echo "The environment variable is not empty: $canvos_tag"
    git checkout $canvos_tag
  fi
}

function copy_iso() {
  mkdir -p $CANVOS_REPO/build
  cp /home/ubuntu/data/"$ISO_NAME".iso $CANVOS_REPO/build
}

# -------------------- ISO ------------------
function create_arg_file() {
  echo "CUSTOM_TAG=$custom_image_tag" >> .arg
  echo "IMAGE_REGISTRY=$image_registry" >> .arg
  echo "IMAGE_REPO=${OS_PARTS[0]}-${OS_PARTS[1]}" >> .arg
  echo "OS_DISTRIBUTION=${OS_PARTS[0]}" >> .arg
  echo "OS_VERSION=${OS_PARTS[1]}" >> .arg
  echo "K8S_DISTRIBUTION=$k8s_distribution" >> .arg
  echo "ISO_NAME=$ISO_NAME" >> .arg
  echo "ARCH=$arch" >> .arg

  if [ -n "$base_image" ]; then
    echo "The base image variable is not empty: $base_image"
    echo "BASE_IMAGE=$base_image" >> .arg
  else
    echo "The base image var is empty"
  fi

  cat .arg
  ARGS_FILE=$(cat .arg)
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
  git checkout user-data --
  ls
}

function prepare_image_builder() {
  export EMBED=false
  export REPO=spectrocloud/stylus-image-builder
  export TAG=latest
  export CONTAINER_NAME=stylus-image-builder

  cp $CANVOS_REPO/build/"$ISO_NAME".iso $IMAGE_BUILDER_REPO
  export ISO_URL=https://www.spectrocloud.com/download/"$ISO_NAME".iso
}

function build_image_builder_image() {
  make docker-build
}

function build_vmdk() {
  make vmdk
}

function upload_vmdk_to_s3() {
  if [ "$upload_iso_to_s3" = "true" ]; then
    aws s3 cp $IMAGE_BUILDER_REPO/images/"$ISO_NAME".vmdk $S3_FOLDER/"$ISO_NAME".vmdk
  fi
}

function run_build_vmdk_step() {
  cd $WORKDIR
  git_clone_stylus_image_builder
  prepare_image_builder
  build_image_builder_image
  build_vmdk
  upload_vmdk_to_s3
}

# -------------------- OVA ------------------
function copy_vmdk_to_ova_folder() {
  mkdir -p $OVA_BUILDER_REPO
  cp $IMAGE_BUILDER_REPO/images/"$ISO_NAME".vmdk $OVA_BUILDER_REPO
}

# govc vm.create -dc=$GOVC_DATACENTER -ds=$GOVC_DATASTORE -folder=$GOVC_FOLDER -name=vmdk-test -disk=$GOVC_DATASTORE:stylus-v3.2.1-amd64/stylus-v3.2.1-amd64.vmdk -on=false -net=$GOVC_NETWORK -disk.controller=lsilogic

#govc vm.create -m 8192 -c 8 -disk=stylus-v3.2.1-amd64/stylus-v3.2.1-amd64.vmdk -on=false -disk.controller=lsilogic vmdk-testyy

function upload_vmdk_to_vsphere() {
  cd $OVA_BUILDER_REPO
  govc import.vmdk "$ISO_NAME".vmdk
}

function create_vm_with_vmdk() {
  cd $OVA_BUILDER_REPO
  govc vm.create -m 8192 -c 8 -disk="$ISO_NAME"/"$ISO_NAME".vmdk -on=false -disk.controller=lsilogic "$ISO_NAME"
}

#function download_ovf_from_vm() {
#
#}

function run_build_ova_step() {
  copy_vmdk_to_ova_folder
  upload_vmdk_to_vsphere
  create_vm_with_vmdk
}

# -------------------- Content Push ------------------

function upload_to_vsphere_datastore() {
  govc datastore.upload $CANVOS_REPO/build/"$ISO_NAME".iso ISO/canvos-action/"$ISO_NAME".iso
}

function upload_iso_to_s3() {
  if [ "$upload_iso_to_s3" = "true" ]; then
    aws s3 cp $CANVOS_REPO/build/"$ISO_NAME".iso $S3_FOLDER/canvos-$custom_image_tag.iso
  fi
}

function push_docker_images() {
    image_list=$(docker images | grep $custom_image_tag | grep $image_registry | grep -v linux)
    while read -r line; do
        image_name=$(echo "$line" | awk '{print $1}')
        image_tag=$(echo "$line" | awk '{print $2}')
        echo "Pushing docker image $image_name:$image_tag"
        docker push "$image_name:$image_tag"
        DOCKER_IMAGES="$image_name:$image_tag\n$DOCKER_IMAGES"
    done <<< "$image_list"
    echo "Pushed $DOCKER_IMAGES"
}

notify() {
  TODAY=$(date '+%Y-%m-%d')
  ISO_S3_LINK="Region: us-west-2, AWS Account: Dev User, Bucket: rishi-public-bucket, Path: canvos-action/canvos-installer-"$custom_image_tag".iso"
  ISO=ISO/canvos-action/"$ISO_NAME".iso
  # shellcheck disable=SC2016
  MSG='"ISO (vsanDatastore1): ```'$ISO'```\nISO S3 (ISO is private by default, make it public in s3 bucket to download): ```'$ISO_S3_LINK'```\nProvider Images: ```'$DOCKER_IMAGES'```\nArgs: ```'$ARGS_FILE'```"'
  PAYLOAD='
  {
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*Stylus CanvOS Automation Build - '${TODAY}' - '${custom_image_tag}'*"
        }
      },
      {
        "type": "divider"
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": '$MSG'
        }
      }
    ]
  }'
  curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" $SLACK_CHANNEL_URL
}

function clean() {
  sudo rm -rf $CANVOS_REPO/build/*
  docker system prune -a -f
}

# -------------------- Executions ------------------
git_clone_canvos
create_arg_file
login_gcr
#build_artifacts
#push_docker_images
#
#if [ "$build_type" = "ISO-Provider" ]; then
#  upload_iso_to_s3
#  upload_to_vsphere_datastore
#fi

copy_iso

if [ "$output_artifact" = "ISO" ]; then
  clean
elif [ "$output_artifact" = "VMDK" ]; then
  run_build_vmdk_step
elif [ "$output_artifact" = "OVA" ]; then
  run_build_vmdk_step
  run_build_ova_step
  echo "Not supported yet"
elif [ "$output_artifact" = "RAW" ]; then
  echo "Not supported yet"
fi

notify