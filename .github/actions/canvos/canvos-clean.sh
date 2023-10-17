# Create reports folder

#set -e
set -x

function clean() {
  rm -rf build/*
  docker system prune -a -y
}

clean