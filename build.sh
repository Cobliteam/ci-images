#!/bin/sh

apt_proxy_addr=
if pgrep -n apt-cacher-ng >/dev/null 2>&1; then
    case "$(uname)" in
    Darwin)
        apt_proxy_addr="192.168.65.1"
    ;;
    Linux)
        apt_proxy_addr=$(ip route get 8.8.8.8 | grep -o 'src.*' | cut -d' ' -f2)
    esac
fi

docker_build() {
    if [ -n "$apt_proxy_addr" ]; then
        docker build --build-arg http_proxy="http://$apt_proxy_addr:3142" "$@"
    else
        docker build "$@"
    fi
}

repository="$1"
[ -n "$repository" ] || repository=cobli

pushd sbt
docker_build -t $repository/ci-sbt:latest .
popd
pushd ubuntu-init
docker_build -t $repository/ubuntu-init:14.04 -f Dockerfile-14.04 . 
docker_build -t $repository/ubuntu-init:16.04 -f Dockerfile-16.04 .
popd
pushd ubuntu-init-python
docker_build -t $repository/ubuntu-init-python:14.04 -f Dockerfile-14.04 .
docker_build -t $repository/ubuntu-init-python:16.04 -f Dockerfile-16.04 .
popd
