#/usr/bin/env bash

# This script is only intended to be used for local development on this project.
# It depends on a buildx node called "beta. You can create such an environment
# by executing "docker buildx create --name beta"

set -euo pipefail

docker buildx build \
 --push \
 --platform linux/arm64,linux/amd64 \
 -f amazonlinux2.Dockerfile \
 -t truemark/aws-cli:beta-2-${{github.run_number}}-amazonlinux2 \
 -t truemark/aws-cli:beta-2-amazonlinux2 \
 -t truemark/aws-cli:beta-amazonlinux2 \
 .
docker buildx build \
 --push \
 --platform linux/arm64,linux/amd64 \
 -f amazonlinux2022.Dockerfile \
 -t truemark/aws-cli:beta-2-${{github.run_number}}-amazonlinux2022 \
 -t truemark/aws-cli:beta-2-amazonlinux2022 \
 -t truemark/aws-cli:beta-2 \
 -t truemark/aws-cli:beta-amazonlinux2022 \
 -t truemark/aws-cli:beta \
 .
docker buildx build \
 --push \
 --platform linux/arm64,linux/amd64 \
 -f ubuntu-focal.Dockerfile \
 -t truemark/aws-cli:beta-2-${{github.run_number}}-ubuntu-focal \
 -t truemark/aws-cli:beta-2-ubuntu-focal \
 -t truemark/aws-cli:beta-ubuntu-focal \
 .
docker buildx build \
 --push \
 --platform linux/arm64,linux/amd64 \
 -f ubuntu-jammy.Dockerfile \
 -t truemark/aws-cli:beta-2-${{github.run_number}}-ubuntu-jammy \
 -t truemark/aws-cli:beta-2-ubuntu-jammy \
 -t truemark/aws-cli:beta-ubuntu-jammy \
 -t truemark/aws-cli:beta-2-ubuntu \
 -t truemark/aws-cli:beta-ubuntu \
 .
docker buildx build \
 --push \
 --platform linux/arm64,linux/amd64 \
 -f alpine.Dockerfile \
 -t truemark/aws-cli:beta-2-${{github.run_number}}-alpine \
 -t truemark/aws-cli:beta-2-alpine \
 -t truemark/aws-cli:beta-alpine \
 .
