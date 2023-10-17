# Create reports folder

#set -e
set -x

function clean() {
  sudo rm -rf build/*
  docker system prune -a -f
}

clean