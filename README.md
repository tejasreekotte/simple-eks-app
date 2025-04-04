### Documentation: EKS Deployment Workflow

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
![image](https://github.com/user-attachments/assets/3ac7266c-23b4-4e01-9857-9babd5be093b)


### **4. Create an Amazon ECR Repository**

1. Run the following command to create an ECR repository in the `ap-south-1` region:

```bash
aws ecr create-repository --repository-name simple-flask-app --region ap-south-1
```
![image](https://github.com/user-attachments/assets/41e1bcd7-a09f-4d49-8ea7-65e10bb3ffb5)

2. Note the repository URI from the output.

---

### **5. Authenticate Docker to ECR**

1. Use the following command to authenticate Docker with the ECR repository:

```bash
aws ecr get-login-password --region ap-south-1 | sudo docker login --username AWS --password-stdin <ECR_REPOSITORY_URI>
```
![image](https://github.com/user-attachments/assets/8d042805-6b43-4713-8f28-74e84a8fbe51)
![image](https://github.com/user-attachments/assets/03173838-9356-4db5-8137-072c83dea3a4)

2. If successful, you will see:

```
Login Succeeded
```
![image](https://github.com/user-attachments/assets/3710795e-73a2-46e8-9d2e-14004fba24d2)

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
![image](https://github.com/user-attachments/assets/8d9a39cc-66f2-4875-82a8-b96622e1625c)

2. Wait for the push to complete. The image will now be available in the ECR repository.


---

### **8. Verify the Image in ECR**

1. Open the [Amazon ECR Console](https://ap-south-1.console.aws.amazon.com/ecr/repositories).
2. Select the repository named `simple-flask-app`.
3. Confirm that the image with the tag `latest` is listed.
![image](https://github.com/user-attachments/assets/c45cfcfa-81fb-4e40-a767-ee48bada5ca0)

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
- **Default region name**: Enter `ap-south-1`.
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
  region = "ap-south-1"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "test-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      "subnet-0d04eb9feada6a767",
      "subnet-0a53809fb1146d783",
      "subnet-0dd91f98cb4d34976"
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy]
}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "test-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [
    "subnet-0d04eb9feada6a767",
    "subnet-0a53809fb1146d783",
    "subnet-0dd91f98cb4d34976"
  ]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy
  ]
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "node_group_name" {
  value = aws_eks_node_group.eks_nodes.node_group_name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ap-south-1 --name test-cluster"
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
![image](https://github.com/user-attachments/assets/0b7d9e31-d04e-4b9a-9629-13ab92cdf59f)
![image](https://github.com/user-attachments/assets/5ebb4b39-2ed1-4615-a52f-5605bdd022e4)

Confirm with `yes` when prompted.

6. Configure `kubectl` to access the cluster:

```bash
aws eks --region ap-south-1 update-kubeconfig --name test-cluster
```
![image](https://github.com/user-attachments/assets/b13d03d4-ae27-42cb-96c1-e810da0547d5)

7. Verify the nodes:

```bash
kubectl get nodes
```
![image](https://github.com/user-attachments/assets/78bf6ee7-c6f0-48b8-bcc7-18f40772b5f1)

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
  name: simple-flask-app
  labels:
    app: simple-flask-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: simple-flask-app
  template:
    metadata:
      labels:
        app: simple-flask-app
    spec:
      containers:
      - name: flask-container
        image: <ECR image URI>:latest
        ports:
        - containerPort: 5000
```
![image](https://github.com/user-attachments/assets/de2eb9ac-7d96-4945-9164-c9d89b5ed9cb)

**`k8s/service.yaml`**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: simple-flask-app-service
spec:
  type: LoadBalancer
  selector:
    app: simple-flask-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
```
![image](https://github.com/user-attachments/assets/ea2c84be-3d98-4627-b937-ed901b23b5e4)

#### **10.2 Apply the Manifests**

1. Deploy the resources:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```
![image](https://github.com/user-attachments/assets/59182ab9-ea48-4ecd-9593-df6003ba5e58)

2. Verify the resources:

```bash
kubectl get pods
kubectl get service flask-service
```
![image](https://github.com/user-attachments/assets/3fdfb3a3-50e1-4d3a-8a8d-b001e172ebca)

3. Access your application using the `EXTERNAL-IP` of the service:

```bash
http://<EXTERNAL-IP>
```
![image](https://github.com/user-attachments/assets/1f625ca6-2173-44da-9a4b-87e0cd3f0593)

---



This guide walks you through creating a Flask application, containerizing it, pushing the image to Amazon ECR, provisioning an EKS cluster with Terraform, deploying the application using Kubernetes, 

