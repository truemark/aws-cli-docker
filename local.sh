#/usr/bin/env bash

# This script is only intended to be used for local development on this project.
# It depends on a buildx node called "beta. You can create such an environment
# by executing "docker buildx create --name beta"

set -euo pipefail

export BUILDKIT_PROGRESS=plain

#docker image build -t moo --build-arg OS_NAME="ubuntu" --build-arg OS_VERSION="focal" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="ubuntu" --build-arg OS_VERSION="jammy" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="debian" --build-arg OS_VERSION="bullseye" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="debian" --build-arg OS_VERSION="bullseye-slim" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="debian" --build-arg OS_VERSION="bookworm" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="debian" --build-arg OS_VERSION="bookworm-slim" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="amazonlinux" --build-arg OS_VERSION="2" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="amazonlinux" --build-arg OS_VERSION="2022" -f Dockerfile .
docker image build -t moo --build-arg OS_NAME="amazonlinux" --build-arg OS_VERSION="2023" -f Dockerfile .
#docker image build -t moo --build-arg OS_NAME="alpine" --build-arg OS_VERSION="3.16" -f alpine.Dockerfile .
#docker image build -t moo --build-arg OS_NAME="alpine" --build-arg OS_VERSION="3.17" -f alpine.Dockerfile .

#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="ubuntu" \
#  --build-arg OS_VERSION="focal" \
#  -f Dockerfile \
#  -t truemark/aws-cli:beta-ubuntu-focal \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="ubuntu" \
#  --build-arg OS_VERSION="jammy" \
#  -f Dockerfile \
#  -t truemark/aws-cli:beta-ubuntu-jammy \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="debian" \
#  --build-arg OS_VERSION="buster" \
#  -f Dockerfile \
#  -t truemark/aws-cli:beta-debian-buster \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="debian" \
#  --build-arg OS_VERSION="bullseye" \
#  -f Dockerfile \
#  -t truemark/aws-cli:beta-debian-bullseye \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="debian" \
#  --build-arg OS_VERSION="bookworm" \
#  -f Dockerfile \
#  -t truemark/aws-cli:beta-debian-bookworm \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="amazonlinux" \
#  --build-arg OS_VERSION="2" \
#  -f Dockerfile \
#  -t truemark/aws-cli:beta-amazonlinux-2 \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="amazonlinux" \
#  --build-arg OS_VERSION="2022" \
#  -f Dockerfile \
#  -t truemark/aws-cli:beta-amazonlinux-2022 \
#  --no-cache \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="alpine" \
#  --build-arg OS_VERSION="3.16" \
#  -f alpine.Dockerfile \
#  -t truemark/aws-cli:beta-alpine-3.16 \
#  .
#
#docker buildx build \
#  --push \
#  --builder beta \
#  --platform linux/arm64,linux/amd64 \
#  --build-arg OS_NAME="alpine" \
#  --build-arg OS_VERSION="3.17" \
#  -f alpine.Dockerfile \
#  -t truemark/aws-cli:beta-alpine-3.17 \
#  .
