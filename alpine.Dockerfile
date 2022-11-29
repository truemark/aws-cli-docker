ARG OS_NAME
ARG OS_VERSION

ARG IMAGE
FROM $OS_NAME:$OS_VERSION as build
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake python3 python3-dev
RUN git clone --single-branch --depth 1 -b v2 https://github.com/aws/aws-cli.git
WORKDIR aws-cli
RUN python3 -m venv venv
RUN . venv/bin/activate && scripts/installers/make-exe
RUN unzip -q dist/awscli-exe.zip
RUN aws/install --bin-dir /aws-cli-bin
RUN /aws-cli-bin/aws --version
RUN rm -rf \
    /usr/local/aws-cli/v2/current/dist/aws_completer \
    /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
    /usr/local/aws-cli/v2/current/dist/awscli/examples
RUN find /usr/local/aws-cli/v2/current/dist/awscli/data -name completions-1*.json -delete
RUN find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

FROM $OS_NAME:$OS_VERSION as build2
COPY --from=build /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=truemark/jq:latest /usr/local/ /usr/local/
COPY helper.sh /usr/local/bin/helper.sh
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin

FROM $OS_NAME:$OS_VERSION as test
RUN apk add bash --no-cache
COPY --from=build2 /usr/local/ /usr/local/
COPY test.sh /test.sh
RUN /test.sh

FROM $OS_NAME:$OS_VERSION
COPY --from=test /usr/local/ /usr/local/
RUN apk add bash --no-cache && \
    echo "source /usr/local/bin/helper.sh && initialize" >> /root/.bashrc && \
    chmod +x /root/.bashrc
ENTRYPOINT ["/bin/bash"]
