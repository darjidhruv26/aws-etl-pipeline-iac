# AWS ETL Pipeline with Terraform

This project provisions a complete Extract, Transform, and Load (ETL) pipeline on AWS using Terraform. It is designed to extract data from a source RDS MySQL database, process it with AWS Glue, and load it into a Redshift data warehouse.

The entire infrastructure is defined as code, making it repeatable, versionable, and easy to manage.

## Architecture

<img width="2392" height="1002" alt="ETL_Pipeline_Architecture" src="https://github.com/user-attachments/assets/23db692e-d428-4448-8ff2-e637f9ebf3ef" />

The architecture is designed with security and best practices in mind, utilizing a custom VPC to isolate resources.

1.  **VPC & Networking**:
    *   A custom VPC (`10.0.0.0/16`) to host all resources.
    *   **Public Subnets**: For internet-facing resources like the NAT Gateway and the Bastion Host.
    *   **Private Subnets**: For backend resources like the RDS database, Redshift cluster, and Glue connections, ensuring they are not exposed to the public internet.
    *   **NAT Gateway**: Allows resources in private subnets to initiate outbound traffic to the internet (e.g., for downloading updates) without allowing inbound traffic.
    *   **VPC Endpoints**: For S3, Glue, Secrets Manager, and RDS. This keeps traffic between our resources and these AWS services within the AWS network, enhancing security and performance.

2.  **Data Sources & Destinations**:
    *   **Source**: An AWS RDS (MySQL) instance running in a private subnet.
    *   **Staging**: An S3 bucket is used for storing the Glue ETL script and as a temporary directory for Glue and Redshift operations.
    *   **Destination**: An AWS Redshift cluster for data warehousing, also located in a private subnet.

3.  **ETL & Orchestration**:
    *   **AWS Glue Catalog**: A database to store metadata.
    *   **AWS Glue Crawler**: Automatically crawls the source RDS database to infer the schema and create a table in the Glue Data Catalog.
    *   **AWS Glue Job**: A Python shell job (`etl_job.py`) that reads data from the source (via the catalog), and writes it to the Redshift cluster.
    *   **AWS Glue Connections**: Secure JDBC connections for Glue to connect to RDS and Redshift.

4.  **Security & Management**:
    *   **IAM Roles**: Least-privilege IAM roles for Glue and Redshift to securely access other AWS resources (like S3 and Secrets Manager).
    *   **AWS Secrets Manager**: Securely stores, encrypts, and manages the credentials for the RDS and Redshift databases.
    *   **KMS Key**: A dedicated KMS key is used to encrypt the secrets in Secrets Manager.
    *   **Security Groups**: Firewall rules that control traffic between the different components of the architecture.
    *   **Bastion Host**: An EC2 instance in a public subnet that acts as a secure jump server to access resources in the private subnets (like the RDS instance for initial setup or debugging). An SSH key is automatically generated for access.

## Data Flow

```
[RDS MySQL Source] ---> [Glue Crawler (Catalogs Schema)] ---> [Glue ETL Job] ---> [S3 Staging Bucket (Temp)] ---> [Redshift Destination]
```

## Prerequisites

Before you begin, ensure you have the following installed and configured:

*   **AWS Account**: An active AWS account.
*   **AWS CLI**: Configured with credentials that have sufficient permissions to create the resources defined in this project.
*   **Terraform**: Version 1.0 or later.

## How to Deploy

1.  **Clone the Repository**
    ```sh
    git clone <your-repository-url>
    cd aws-etl-terraform
    ```

2.  **Initialize Terraform**
    This will download the necessary providers (AWS, TLS, etc.).
    ```sh
    terraform init
    ```

3.  **Review the Plan**
    Inspect the execution plan to see what resources Terraform will create.
    ```sh
    terraform plan
    ```

4.  **Apply the Configuration**
    Deploy the infrastructure to your AWS account. This process will take several minutes as it needs to provision the VPC, RDS instance, and Redshift cluster.
    ```sh
    terraform apply --auto-approve
    ```

Upon successful completion, Terraform will create a private key file `etl-etl-key.pem` in your directory and display the outputs.

## Post-Deployment Steps

1.  **Populate the Source Database**:
    *   The RDS database is created empty. You need to connect to it to create and populate the source table.
    *   Use the `bastion_public_ip` output and the generated `etl-etl-key.pem` to SSH into the bastion host.
    *   From the bastion host, connect to the RDS instance using the `rds_endpoint` output and the credentials stored in Secrets Manager.
    *   Create a table named `customers` in the `poc_source_db` database. The ETL job expects the following schema (as defined in `glue.tf`):
        ```sql
        CREATE TABLE customers (
            id INTEGER,
            first_name VARCHAR(50),
            last_name VARCHAR(50),
            email VARCHAR(100),
            registration_date DATE
        );
        ```

2.  **Run the Glue Crawler**:
    *   Navigate to the AWS Glue console.
    *   Find the crawler named `etl-rds-crawler` and run it.
    *   This will populate the `etl_db_catalog` with a metadata table for your `customers` table.

3.  **Run the Glue Job**:
    *   In the Glue console, find the job named `poc-rds-to-redshift` and run it.
    *   Once the job succeeds, the data from your RDS `customers` table will be available in the `public.customers` table in your Redshift cluster.

## Cleaning Up

To avoid ongoing charges, destroy the infrastructure when you are finished.

> **Warning**: This will permanently delete all resources created by Terraform, including the RDS database, Redshift cluster, and S3 bucket contents.

```sh
terraform destroy --auto-approve
```
