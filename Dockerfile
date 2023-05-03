ARG OS_NAME
ARG OS_VERSION
FROM $OS_NAME:$OS_VERSION as build
ARG OS_NAME
ARG OS_VERSION
ARG TARGETARCH
RUN if [ "${OS_NAME}" = "debian" ] || [ "${OS_NAME}" = "ubuntu" ]; then \
      apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -qq curl ca-certificates unzip --no-install-recommends; \
    elif [ "${OS_NAME}" = "amazonlinux" ]; then \
      yum install -y -q findutils unzip; \
    fi
RUN if [ "$TARGETARCH" = "amd64" ]; then ARCHITECTURE="x86_64"; elif [ "$TARGETARCH" = "arm64" ]; then ARCHITECTURE="aarch64"; else echo "Unsupported architecture: $TARGETARCH" && exit 1; fi && \
    curl -sSLf "https://awscli.amazonaws.com/awscli-exe-linux-${ARCHITECTURE}.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
COPY --from=truemark/jq:latest /usr/local/ /usr/local/
COPY helper.sh /usr/local/bin/helper.sh

FROM $OS_NAME:$OS_VERSION as test
ARG OS_NAME
ARG OS_VERSION
COPY --from=build /usr/local/ /usr/local/
COPY test.sh /test.sh
RUN if [ "${OS_NAME}" = "debian" ] || [ "${OS_NAME}" = "ubuntu" ]; then \
      apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -qq groff --no-install-recommends && apt-get -qq clean && rm -rf /var/lib/apt/lists; \
    elif [ "${OS_NAME}" = "amazonlinux" ]; then \
      yum install -y -q groff && yum clean all; \
    fi
RUN /test.sh

FROM $OS_NAME:$OS_VERSION
ARG OS_NAME
ARG OS_VERSION
COPY --from=test /usr/local/ /usr/local/
RUN if [ "${OS_NAME}" = "debian" ] || [ "${OS_NAME}" = "ubuntu" ]; then \
      apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -qq groff tar zip unzip gzip bzip2 curl ca-certificates --no-install-recommends && apt-get -qq clean && rm -rf /var/lib/apt/lists; \
    elif [ "${OS_NAME}" = "amazonlinux" ]; then \
      yum install -y -q groff tar zip unzip gzip bzip2 && yum clean all; \
    fi
RUN echo "source /usr/local/bin/helper.sh && initialize" >> /root/.bashrc && \
    chmod +x /root/.bashrc
ENTRYPOINT ["aws"]
