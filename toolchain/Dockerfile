FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install git dnsutils software-properties-common gnupg2 curl unzip -y 
RUN curl https://apt.releases.hashicorp.com/gpg | gpg --dearmor > hashicorp.gpg && install -o root -g root -m 644 hashicorp.gpg /etc/apt/trusted.gpg.d/ && apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
RUN apt install terraform && curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd && \
rm argocd-linux-amd64
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
unzip awscliv2.zip && \
/aws/install
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
RUN mkdir -p /nextdemo/terraform
WORKDIR /nextdemo/terraform