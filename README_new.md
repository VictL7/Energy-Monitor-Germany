# Energy Monitor Germany

A comprehensive data pipeline for monitoring Germany's energy market using SMARD API data.

## Features

- **Data Collection**: Automated collection from SMARD (Bundesnetzagentur) API
- **Data Processing**: Kestra-based workflow orchestration
- **Data Storage**: Google Cloud Storage + BigQuery
- **Data Quality**: Temporal integrity checks and validation
- **Infrastructure**: Terraform-managed GCP resources

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Google Cloud Platform account
- Terraform

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/VictL7/Energy-Monitor-Germany.git
   cd Energy-Monitor-Germany
   ```

2. **Configure GCP credentials**
   ```bash
   # Copy your service account key to Terraform/keys/
   cp your-key.json Terraform/keys/
   ```

3. **Update Terraform variables**
   ```bash
   cd Terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. **Start Kestra**
   ```bash
   cd ../kestra
   docker compose up -d
   ```

6. **Access Kestra UI**
   - URL: http://localhost:8080
   - Username: admin
   - Password: admin

## Project Structure

```
Energy-Monitor-Germany/
├── Data/                          # Raw data files
├── Terraform/                     # Infrastructure as Code
│   ├── main.tf                   # GCP resources
│   ├── variables.tf              # Input variables
│   └── outputs.tf                # Output values
├── kestra/                       # Workflow orchestration
│   ├── docker-compose.yml        # Kestra services
│   └── *.yaml                    # Workflow definitions
├── notebooks/                    # Jupyter notebooks for analysis
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Data Flow

1. **SMARD API** → JSON responses with energy data
2. **Kestra Workflows** → Orchestrate data collection and processing
3. **GCS Data Lake** → Store raw Parquet files
4. **BigQuery** → Data warehouse with partitioning and clustering
5. **Analysis** → dbt transformations and visualizations (planned)

## Data Quality Checks

- **Temporal Integrity**: DST handling and timestamp continuity
- **Logic Consistency**: Night-time solar generation validation
- **Data Completeness**: Missing value detection
- **Type Validation**: Schema enforcement

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE.txt file for details.