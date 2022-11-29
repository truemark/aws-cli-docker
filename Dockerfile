ARG OS_NAME
ARG OS_VERSION

FROM $OS_NAME:$OS_VERSION as build
ARG OS_NAME
ARG OS_VERSION
ARG TARGETARCH
RUN if [ "${OS_NAME}" = "debian" ] || [ "${OS_NAME}" = "ubuntu" ]; then \
      DEBIAN_FRONTEND=noninteractive apt-get update -qq && apt-get install -qq curl ca-certificates unzip --no-install-recommends; \
    elif [ "${OS_NAME}" = "amazonlinux" ]; then \
      yum install -y -q findutils unzip; \
    fi
#RUN DEBIAN_FRONTEND=noninteractive apt-get update -qq && apt-get install -qq curl ca-certificates unzip --no-install-recommends
RUN if [ "$TARGETARCH" = "amd64" ]; then ARCHITECTURE="x86_64"; elif [ "$TARGETARCH" = "arm64" ]; then ARCHITECTURE="aarch64"; else echo "Unsupported architecture: $TARGETARCH" && exit 1; fi && \
    curl -sSLf "https://awscli.amazonaws.com/awscli-exe-linux-${ARCHITECTURE}.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
RUN rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer \
    /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
    /usr/local/aws-cli/v2/current/dist/awscli/examples && \
    find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete
COPY --from=truemark/jq:latest /usr/local/ /usr/local/
COPY helper.sh /usr/local/bin/helper.sh

FROM $OS_NAME:$OS_VERSION as test
COPY --from=build /usr/local/ /usr/local/
COPY test.sh /test.sh
RUN /test.sh

FROM $OS_NAME:$OS_VERSION
COPY --from=test /usr/local/ /usr/local/
RUN echo "source /usr/local/bin/helper.sh && initialize" >> /root/.bashrc && \
    chmod +x /root/.bashrc
ENTRYPOINT ["/bin/bash"]
