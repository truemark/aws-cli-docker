FROM amazon/aws-cli:latest
COPY helper.sh /
RUN echo "source /helper.sh && aws_init" >> /root/.bashrc && chmod +x /root/.bashrc
ENTRYPOINT ["/bin/bash"]
