FROM amazonlinux:2022 as builder
COPY --from=amazon/aws-cli:latest /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=truemark/jq:latest /usr/local/ /usr/local/
COPY helper.sh /usr/local/bin/helper.sh
RUN yum install findutils -y && \
    rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer \
    /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
    /usr/local/aws-cli/v2/current/dist/awscli/examples && \
    find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete && \
    ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin

FROM amazonlinux:2022
COPY --from=builder /usr/local/ /usr/local/
RUN echo "source /usr/local/bin/helper.sh && initialize" >> /root/.bashrc && \
    chmod +x /root/.bashrc
ENTRYPOINT ["/bin/bash"]
