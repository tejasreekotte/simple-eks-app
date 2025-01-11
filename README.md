### Documentation: Running a Flask Application in Docker, Pushing to Amazon ECR, and Creating an EKS Cluster

This guide outlines the steps to create, containerize, and push a simple Flask application to Amazon Elastic Container Registry (ECR), provision an Amazon EKS cluster using Terraform, and set up monitoring with Prometheus and Grafana.

---

### **Directory Structure**

The project structure is organized as follows:

```
project-root/
|-- k8s/
|   |-- deployment.yaml
|   |-- service.yaml
|-- terraform/
|   |-- main.tf
|   |-- variables.tf
|-- Dockerfile
|-- app.py
```

Navigate to the appropriate directories to access specific files. Clone the project repository and follow the steps below to deploy the application.

---

### **1. Create the Flask Application**

1. Create a file named `app.py` with the following content:

```python
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello, Docker!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

This is a basic Flask application that listens on port `5000` and returns "Hello, Docker!" when accessed at the root URL (`/`).

---

### **2. Create a Dockerfile**

1. In the same directory as `app.py`, create a file named `Dockerfile` with the following content:

```Dockerfile
# Use the official Python image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container
COPY . /app

# Install the Python dependencies
RUN pip install flask

# Expose port 5000
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]
```

This `Dockerfile` defines the environment and steps required to build a Docker image for the Flask application.

---

### **3. Build the Docker Image**

1. Use the `docker build` command to create a Docker image:

```bash
sudo docker build -t simple-flask-app .
```

- The `-t` option tags the image with the name `simple-flask-app`.
- The `.` specifies the current directory as the build context.

---

### **4. Create an Amazon ECR Repository**

1. Run the following command to create an ECR repository in the `us-west-2` region:

```bash
aws ecr create-repository --repository-name simple-flask-app --region us-west-2
```

2. Note the repository URI from the output.

---

### **5. Authenticate Docker to ECR**

1. Use the following command to authenticate Docker with the ECR repository:

```bash
aws ecr get-login-password --region us-west-2 | sudo docker login --username AWS --password-stdin <ECR_REPOSITORY_URI>
```

2. If successful, you will see:

```
Login Succeeded
```

---

### **6. Tag the Docker Image**

1. Tag the Docker image to prepare it for pushing to ECR:

```bash
sudo docker tag simple-flask-app:latest <ECR_REPOSITORY_URI>:latest
```

---

### **7. Push the Docker Image to ECR**

1. Push the tagged Docker image to the ECR repository:

```bash
sudo docker push <ECR_REPOSITORY_URI>:latest
```

2. Wait for the push to complete. The image will now be available in the ECR repository.

---

### **8. Verify the Image in ECR**

1. Open the [Amazon ECR Console](https://us-west-2.console.aws.amazon.com/ecr/repositories).
2. Select the repository named `simple-flask-app`.
3. Confirm that the image with the tag `latest` is listed.

---

### **9. Provision an Amazon EKS Cluster Using Terraform**

#### **9.1 Prerequisites**

Ensure the following tools are installed on your local machine:

- **AWS CLI**: [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **Terraform**: [Install Terraform](https://www.terraform.io/downloads)
- **kubectl**: [Install kubectl](https://kubernetes.io/docs/tasks/tools/)

#### **9.2 Configure AWS CLI**

Before executing Terraform commands, configure the AWS CLI with your credentials:

```bash
aws configure
```

You will be prompted to provide the following details:

- **AWS Access Key ID**: Enter your access key.
- **AWS Secret Access Key**: Enter your secret key.
- **Default region name**: Enter `us-west-2`.
- **Default output format**: Enter `json` (or leave blank).

Verify the configuration with:

```bash
aws sts get-caller-identity
```

This command should return your AWS account details if the configuration is successful.

#### **9.3 Terraform Configuration**

Create the following Terraform files to provision an EKS cluster:

**`terraform/main.tf`**:
```hcl
provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Example = var.cluster_name
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  intra_subnets   = var.intra_subnets

  enable_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.1"

  cluster_name                   = var.cluster_name
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["m5.large"]

    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    ascode-cluster-wg = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

      tags = {
        ExtraTag = "helloworld"
      }
    }
  }

  tags = local.tags
}
```

**`terraform/variables.tf`**:
```hcl
variable "aws_region" {
  description = "AWS region for the infrastructure"
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  default     = "ascode-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.123.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  default     = ["us-west-2a", "us-west-2b"]
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  default     = ["10.123.1.0/24", "10.123.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  default     = ["10.123.3.0/24", "10.123.4.0/24"]
}

variable "intra_subnets" {
  description = "Intra subnet CIDRs"
  default     = ["10.123.5.0/24", "10.123.6.0/24"]
}
```

#### **9.4 Deploy the Infrastructure**

1. Navigate to the `terraform` directory:

```bash
cd terraform
```

2. Initialize Terraform:

```bash
terraform init
```

3. Validate the configuration:

```bash
terraform validate
```

4. Plan the deployment:

```bash
terraform plan
```

5. Apply the configuration:

```bash
terraform apply
```

Confirm with `yes` when prompted.

6. Configure `kubectl` to access the cluster:

```bash
aws eks --region us-west-2 update-kubeconfig --name ascode-cluster
```

7. Verify the nodes:

```bash
kubectl get nodes
```

---

### **10. Kubernetes Deployment Files**

Navigate to the `k8s` directory to access the deployment files:

```bash
cd ../k8s
```

#### **10.1 Create Deployment and Service Files**

**`k8s/deployment.yaml`**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
  labels:
    app: flask-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-container
        image: <ECR_REPOSITORY_URI>:latest
        ports:
        - containerPort: 5000
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
      imagePullSecrets:
      - name: ecr-secret
```

**`k8s/service.yaml`**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: flask-service
  labels:
    app: flask-app
spec:
  selector:
    app: flask-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
  type: LoadBalancer
```

#### **10.2 Apply the Manifests**

1. Deploy the resources:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

2. Verify the resources:

```bash
kubectl get pods
kubectl get service flask-service
```

3. Access your application using the `EXTERNAL-IP` of the service:

```bash
http://<EXTERNAL-IP>
```

---

### **11. Set Up Monitoring with Prometheus and Grafana**

#### **11.1 Prerequisites**

- An EKS cluster should be up and running.
- Install Helm 3.
- Ensure an EC2 instance or a local machine has access to the EKS cluster.

#### **11.2 Implementation Steps**

1. Add Helm Stable Charts:

```bash
helm repo add stable https://charts.helm.sh/stable
```

2. Add the Prometheus Helm repository:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

3. Search for Prometheus Helm charts:

```bash
helm search repo prometheus-community
```

4. Create a namespace for Prometheus:

```bash
kubectl create namespace prometheus
```

5. Install kube-prometheus-stack:

```bash
helm install stable prometheus-community/kube-prometheus-stack -n prometheus
```

6. Verify the Prometheus and Grafana pods:

```bash
kubectl get pods -n prometheus
```

7. Verify services:

```bash
kubectl get svc -n prometheus
```

8. Expose Prometheus and Grafana using LoadBalancer or NodePort:

- Edit Prometheus service:

```bash
kubectl edit svc stable-kube-prometheus-sta-prometheus -n prometheus
```

- Edit Grafana service:

```bash
kubectl edit svc stable-grafana -n prometheus
```

9. Get the LoadBalancer URL and access the Grafana UI in the browser:

- Default credentials:
  - **Username**: `admin`
  - **Password**: `admin`

10. Create Grafana Dashboards:

- For Kubernetes Monitoring:
  1. Click the `+` button on the left panel and select `Import`.
  2. Enter the dashboard ID `12740`.
  3. Click `Load`.
  4. Select `Prometheus` as the data source.
  5. Click `Import`.

- For Cluster Monitoring:
  1. Follow the same steps as above but use dashboard ID `3119`.
---

### **12. Summary**

This guide walks you through creating a Flask application, containerizing it, pushing the image to Amazon ECR, provisioning an EKS cluster with Terraform, deploying the application using Kubernetes, and setting up monitoring with Prometheus and Grafana. For further assistance, feel free to reach out!

