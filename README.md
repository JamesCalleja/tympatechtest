# tympatechtest# GKE Helloworld Deployment with Traffic Splitting

This repository contains Terraform configurations and Kubernetes manifests to deploy a single-node Google Kubernetes Engine (GKE) cluster, host a `dockersamples/helloworld-demo-node` application, and demonstrate advanced Ingress features for 50/50 weighted traffic splitting between two versions of the application, combined with Horizontal Pod Autoscaling.

---

## Table of Contents

1.  [Overview](#overview)
2.  [Prerequisites](#prerequisites)
3.  [Google Cloud Project Setup](#google-cloud-project-setup)
4.  [Terraform Deployment](#terraform-deployment)
5.  [Application Verification](#application-verification)
6.  [Key Learnings & Notes](#key-learnings--notes)
7.  [Cleanup](#cleanup)

---

## 1. Overview

This project sets up the following infrastructure on Google Cloud:

* A dedicated **VPC Network and Subnetwork** managed by Terraform.
* A **Single-Node GKE Cluster** within the specified region and zone.
* Two **Kubernetes Deployments** (`hello-v1` and `hello-v2`) running the `dockersamples/helloworld-demo-node` image.
* **Horizontal Pod Autoscalers (HPA)** for each Deployment, ensuring dynamic scaling based on CPU utilization.
* Two **Kubernetes Services** (`helloworld-service-v1` and `helloworld-service-v2`), each targeting a specific application version.
* A **Google Cloud BackendConfig** to define a 50/50 weighted traffic split.
* A **Kubernetes Ingress** leveraging the GKE Ingress controller to expose the application publicly with weighted traffic distribution.

---

## 2. Prerequisites

Before you begin, ensure you have the following installed:

* **Google Cloud SDK (gcloud CLI):**
    * [Installation Guide](https://cloud.google.com/sdk/docs/install)
* **Terraform:**
    * [Installation Guide](https://developer.hashicorp.com/terraform/downloads)
* **kubectl:** (Usually installed with `gcloud SDK` or follow [Kubernetes docs](https://kubernetes.io/docs/tasks/tools/install-kubectl/))

---

## 3. Google Cloud Project Setup

Before running Terraform, you need to authenticate with Google Cloud and enable the necessary APIs for your project.

1.  **Authenticate `gcloud`:**
    ```bash
    gcloud auth login
    ```

2.  **Set your Google Cloud Project:**
    Ensure `gcloud` is configured to interact with your target project. Replace `tympahealth-james-calleja` with your actual project ID.
    ```bash
    gcloud config set project tympahealth-james-calleja
    ```

3.  **Enable Required Google Cloud APIs:**
    The GKE and underlying Compute Engine APIs must be enabled for your project *before* Terraform can interact with them. If these are not enabled, you will encounter `403` errors like `Compute Engine API has not been used...` or `Kubernetes Engine API has not been used...`.

    ```bash
    gcloud services enable container.googleapis.com
    gcloud services enable compute.googleapis.com
    ```
    Allow a few minutes for these changes to propagate after running the commands.

---

## 4. Terraform Deployment

Follow these steps to deploy the GKE cluster and application using Terraform:

1.  **Clone the repo:**
    ```bash
    git clone https://github.com/JamesCalleja/tympatechtest.git
    ```

2.  **Navigate to the Terraform directory:**
    ```bash
    cd terraform
    ```

3.  **Initialize Terraform:**
    This command downloads the necessary providers and modules.
    ```bash
    terraform init
    ```
    *Note: You may encounter provider version conflicts if your local `hashicorp/google` provider version in `versions.tf` is incompatible with the GKE module's requirements. Ensure your `versions.tf` specifies a compatible range (e.g., `version = "~> 6.14"` for the Google provider and `~> 7.5` for the Network module).*

4.  **Review the Plan:**
    Examine the resources Terraform proposes to create, modify, or destroy.
    ```bash
    terraform plan
    ```

5.  **Apply the Configuration:**
    If the plan looks correct, apply the changes to provision the infrastructure. Type `yes` when prompted.
    ```bash
    terraform apply
    ```
    *Note: GKE cluster creation can take 10-15 minutes or longer. If it gets stuck on "Still creating..." for an extended period (e.g., >30 mins), check the Google Cloud Console (Kubernetes Engine -> Clusters) for detailed error messages or status updates.*
    *Common `404 Not Found` errors during node pool creation (e.g., `Failed to fetch local ssd counts from SOT for machine type e2-large`) indicate that the specified machine type (`e2-medium` or `e2-large`) does not support Local SSDs. Ensure `local_ssd_count = 0` is explicitly set in your node pool configuration within the `main.tf` if using E2 series VMs.*

---

## 5. Application Verification

Once `terraform apply` completes, your GKE cluster will be running, and the application deployments, services, BackendConfig, and Ingress will be configured.

1.  **Get the Ingress External IP:**
    The Ingress resource will provision a Google Cloud HTTP(S) Load Balancer. It may take a few minutes for the IP address to become available after `terraform apply` finishes.
    ```bash
    kubectl get ingress helloworld-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    ```
    Copy the IP address that is returned.

2.  **Test 50/50 Traffic Splitting:**
    Replace `34.123.45.67` with the actual Ingress IP you obtained in the previous step.
    ```bash
    for i in {1..20}; do
      echo "Request $i:"
      curl -s [http://34.123.45.67](http://34.123.45.67) | grep "Hello"
      echo "---"
      sleep 0.5
    done
    ```
    You should observe responses from both `hello-v1` and `hello-v2` deployments, approximately evenly distributed, demonstrating the 50/50 traffic split configured via the BackendConfig.

---

## 6. Key Learnings & Notes

* **Required GKE Module Inputs:** The official `terraform-google-modules/kubernetes-engine` module requires explicit inputs for `network`, `subnetwork`, `ip_range_pods`, and `ip_range_services`. It doesn't accept default network/IAM settings; these resources must be created or explicitly referenced. This project uses the `terraform-google-modules/network` module to provision these prerequisites.
* **API Enablement:** Initial `403` (Forbidden) errors during Terraform execution often indicate that essential Google Cloud APIs (like Compute Engine and Kubernetes Engine) aren't yet enabled for the project. These need to be enabled manually via `gcloud services enable` or the Google Cloud Console as a bootstrapping step.
* **Local SSD Incompatibility:** Be aware that E2 machine types (e.g., `e2-medium`, `e2-large`) don't support Local SSDs. If you encounter errors related to Local SSDs, ensure `local_ssd_count = 0` is explicitly set in your node pool configuration.
* **Weighted Ingress Traffic Splitting on GKE:** To achieve weighted traffic distribution (e.g., 50/50) across different application versions using GKE Ingress:
    * Each distinct application version (Deployment) needs its own dedicated Kubernetes `Service` (e.g., `helloworld-service-v1` and `helloworld-service-v2`).
    * A `BackendConfig` resource is used to define the desired traffic weights for these services.
    * One of these Services (e.g., `helloworld-service-v1`) must be annotated with `cloud.google.com/backend-config: '{"default": "YOUR_BACKEND_CONFIG_NAME"}'` to link it to the `BackendConfig`.
    * The `Ingress` resource's `defaultBackend` (or a specific rule) then points to this *annotated* Service. The underlying Google Cloud Load Balancer uses the `BackendConfig` rules via this link to split traffic.
* **Horizontal Pod Autoscaler (HPA):** HPA offers superior horizontal scaling by dynamically adjusting pod replicas based on CPU/memory utilization or custom metrics, leading to better resource utilization and performance than fixed replica counts. When using HPA, generally remove the `replicas` field from your Deployment manifest, as HPA will manage this directly.

---

## 7. Cleanup

To destroy all resources created by Terraform and avoid incurring further costs, run:

```bash
terraform destroy