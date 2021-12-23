FROM amazon/aws-cli:latest
COPY helper.sh /
RUN echo "source /helper.sh && aws_init" >> /root/.bashrc && \
    chmod +x /root/.bashrc && \
    curl -sSL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o /usr/local/bin/jq && \
    chmod +x /usr/local/bin/jq
ENTRYPOINT ["/bin/bash"]
