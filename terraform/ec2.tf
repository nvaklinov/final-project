resource "aws_instance" "ec2" { 
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = local.instance_type
  vpc_security_group_ids = [aws_security_group.sg.id]
  user_data     = <<EOF
        #!/bin/bash

        ###########JENKINS###############
        yum update -y
        sudo wget -O /etc/yum.repos.d/jenkins.repo \
        https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        yum upgrade -y
        amazon-linux-extras install java-openjdk11 -y
        yum install jenkins git jq -y

        ###########DOCKER################
        yum install -y docker
        systemctl start docker
        systemctl enable docker
        usermod -aG docker jenkins
        systemctl enable jenkins
        systemctl start jenkins

        ############KUBECTLandHELM##########
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod 700 get_helm.sh
        ./get_helm.sh

        #############INSTALL KIND###########
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        echo "apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    listenAddress: "0.0.0.0" # Optional, defaults to "0.0.0.0"
    protocol: tcp # Optional, defaults to tcp
- role: worker
- role: worker" > /home/ec2-user/example.yaml
        kind create cluster --config /home/ec2-user/example.yaml
        usermod -s /bin/bash jenkins
        echo -e "123\n123" | sudo passwd jenkins
        mkdir -p /var/lib/jenkins/.kube/
        cp /.kube/config /var/lib/jenkins/.kube/
        chown -R jenkins:jenkins /var/lib/jenkins/.kube/
        kubectl create secret docker-registry regcred --docker-server=058302395964.dkr.ecr.eu-central-1.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region eu-central-1)
EOF
  iam_instance_profile = aws_iam_instance_profile.profile.name
  tags = {
    Name = "Jenkins"
  }
}
