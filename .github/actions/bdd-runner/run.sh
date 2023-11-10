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



git_clone_teams_edge_native
bash create_config.sh $palette_endpoint $palette_api_key abcdf



