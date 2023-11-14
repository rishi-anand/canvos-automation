# Run edge native automation tests

set -e
set -x

WORKDIR=$(pwd)
BDD_REPO=$WORKDIR/teams-edge-native
echo "Github username is $github_user"

function git_clone_teams_edge_native() {
  git clone https://$ACCESS_TOKEN@github.com/spectrocloud/teams-edge-native.git
  cd $BDD_REPO
  pwd
  ls
}

function clean() {
    rm -rf $WORKDIR/*
}

function createConfigYaml() {
PALETTE_URL=$1
PALETTE_API_KEY=$2
PALETTE_PROJECT=$3

cat << EOF > config.yaml
paletteInfo:
  endpoint: $PALETTE_URL
  apiKey: $PALETTE_API_KEY
  projectName: $PALETTE_PROJECT
envs:
  vmWare:
    vCenterURL: $GOVC_URL
    vCenterUserName: $GOVC_USERNAME
    vCenterPassword: $GOVC_PASSWORD
    folderName: $GOVC_FOLDER
    datacenter: $GOVC_DATACENTER
    cluster: "Cluster1"
    network: "VM-NETWORK2"
    datastore: $GOVC_DATASTORE
    datastoreFolder: "0323-workshop"
    resourcePool: $GOVC_RESOURCE_POOL
    templateName: "palette-edge-installer-ubuntu20"
  intelNuc:
imageBuilder:
  kairosVersion: "v2.3.2"
  paletteEdgeVersion: "4.0.4"
  coreImages:
    - name: "ubuntu20"
      location: "http://"
    - name: "ubuntu22"
      location: "http://"
    - name: "opensuse12"
      location: "http://"
  providerImages:
    - name: "ubuntu-pxke-1.0.0-os-x-k8s-x"
      location: "gcr.io/spectro-dev-public/vpitchai/upgradeu20/ubuntu:kubeadm-1.25.2-v4.0.5-upgradeu20"
    - name: "ubuntu-pxke-2.0.0-os-x-k8s-y"
      location: "gcr.io/spectro-dev-public/vpitchai/upgradeu20/ubuntu:kubeadm-1.26.4-v4.0.5-upgradeu20"
    - name: "ubuntu-pxke-3.0.0-os-y-k8s-y"
      location: "gcr.io/spectro-dev-public/vpitchaibdd/ubuntu:kubeadm-1.26.4-v4.0.4-bddupgradetests"
    - name: "ubuntu-k3s-1.0.0-os-x-k8s-x"
      location: "gcr.io/spectro-dev-public/aslam/ubuntu:k3s-1.25.2-v4.0.6-demo"
    - name: "ubuntu-k3s-2.0.0-os-x-k8s-y"
      location: "gcr.io/spectro-dev-public/aslam/ubuntu:k3s-1.26.4-v4.0.6-demo"
    - name: "ubuntu-k3s-3.0.0-os-y-k8s-y"
      location: "gcr.io/spectro-dev-public/aslam/ubuntu:k3s-1.27.2-v4.0.6-demo"

edgeHostConfig:
  edgeHostType: "VMWare"
  netmask: 18
  nodeIpAddresses:
    - "10.10.229.62"
    - "10.10.229.63"
    - "10.10.229.64"
  httpProxy: "http://10.10.180.0:3128"
  httpsProxy: "http://10.10.180.0:3128"
  noProxy: "10.10.128.10,.spectrocloud.dev,10.0.0.0/8"
  nameserver: "10.10.128.8"
  gateway: "10.10.192.1"
  osUser: "kairos"
  osPassword: "kairos"
  certificate: |
    -----BEGIN CERTIFICATE-----
    MIID7zCCAtegAwIBAgIUeYqlsuThQQ1xkon2rKuHSiUaRYUwDQYJKoZIhvcNAQEL
    BQAwgYYxCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJDQTERMA8GA1UEBwwIU2FuIEpv
    c2UxGjAYBgNVBAoMEVNwZWN0cm8gQ2xvdWQgSW5jMRAwDgYDVQQLDAdwYWxldHRl
    MSkwJwYDVQQDDCB3aGl0ZWxpc3QtcHJveHkuc3BlY3Ryb2Nsb3VkLmRldjAeFw0y
    MzA0MDgyMzMzNDBaFw0yNDA0MDcyMzMzNDBaMIGGMQswCQYDVQQGEwJVUzELMAkG
    A1UECAwCQ0ExETAPBgNVBAcMCFNhbiBKb3NlMRowGAYDVQQKDBFTcGVjdHJvIENs
    b3VkIEluYzEQMA4GA1UECwwHcGFsZXR0ZTEpMCcGA1UEAwwgd2hpdGVsaXN0LXBy
    b3h5LnNwZWN0cm9jbG91ZC5kZXYwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
    AoIBAQC/37wjU70aueDp7rOKiS8KqZMjdePDWeVs2TvY5pVEYrYFg3p4aZqNGgNU
    Spxy4Iey+PRXEmz1IkY2lmtrMXapBeI6yT1fKpU8DCJexXCzYZTAloPKXCJgM4Ik
    Y4Y6OgtE9eqIYZIa3xwJNzV12LS90WsrdFGTpiDzn8r4JQ0KPwBdAAp/yAFuFIEl
    alXa+mQH3ni/M4Bswl+zHTPnI1ExQmXzbm2freX1KrnANJvcclKs/zLY6vCxBAIg
    j1jkCyrTd6fVeicjV9l6/UYqVz/l6m0Or/eL6RA7acCdd9B6KRXcRO7SH04abAFw
    LFnoNHcUrChWwfQnxIOYT83+5QTbAgMBAAGjUzBRMB0GA1UdDgQWBBQQ/I29A64y
    QwBacOtNo9Uq+akmPjAfBgNVHSMEGDAWgBQQ/I29A64yQwBacOtNo9Uq+akmPjAP
    BgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQBSG9QkQRKR4xLJ246G
    HYgXk6x41AFmLbdeoS/tYRrzyAIwckc+AT7SfUz6ZnKrMP3anWWJOfwQsWYS9BkM
    15lJ729F9rLVBVBOb/inR23lgxkCHPqwxUSqEj9kdos+gsec7zULIVnx/YVumwgZ
    IWWt/WR6cCODWBm39MzwDyC8r4FyfVsy3BPO7MrHND+E+Uxnmh7S2CyVZp26wm5E
    8wxCbhf21U4P7ODqIXdXNAwfq9tzGhTMI02fbkKvtR99lGKH0A4v8aJzqH2fj3KQ
    IFEiNShRc5LHI+UyZDvSJX3VdUISCM+Nb98mTs2V2H/nuvsQWOMrMN2+ZHxP9AaD
    4JHv
    -----END CERTIFICATE-----
monitoringServer:
  endpoint: ""
createNewEdgeHosts: true
outputDir: "/Users/rishi/work/src/teams-edge-native/local/out"
EOF
}

git_clone_teams_edge_native
createConfigYaml $palette_endpoint $palette_api_key abcdf
ls
pwd
cat config.yaml
echo $features
echo $palette_endpoint
echo $palette_api_key
echo $custom_exec_cmd
#clean



