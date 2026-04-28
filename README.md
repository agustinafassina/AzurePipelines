# 🚀 Azure Pipelines – Docker Build & Push

## English
Collection of **Azure DevOps** pipelines to build Docker images and push them to **Azure Container Registry (ACR)** or **Amazon Elastic Container Registry (ECR)**, with optional metadata and vulnerability scanning via Trivy.

### Table of contents
- [Included pipelines](#included-pipelines)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage](#usage)
- [Repository structure](#repository-structure)

### Included pipelines
| Pipeline | Registry | Description |
|----------|----------|-------------|
| **ACR (basic)** | Azure Container Registry | Build and push Docker image to ACR. |
| **ACR (complete)** | Azure Container Registry | Build, push, and metadata (commit, author, version from `package.json`). |
| **ECR (basic)** | Amazon ECR | Build and push Docker image to ECR. |
| **ECR (complete)** | Amazon ECR | Build, push, and metadata. |
| **Scanning** | Amazon ECR | Build, **Trivy** scan (CRITICAL/HIGH/MEDIUM/LOW), push only if no vulnerabilities. |
| **Inspector SBOM report** | Amazon Inspector + S3 | Generates an SBOM report via **Amazon Inspector**, stores it in S3, and maintains a stable `latest.json` + `metadata.json` for API consumption. |

### Prerequisites
- **Azure DevOps** project.
- **Dockerfile** in the repo root (or path specified in the pipeline).
- For ACR: **Service Connection** (Azure Resource Manager) in the project.
- For ECR: AWS credentials (Access Key ID and Secret Access Key) or AWS Service Connection.

### Configuration
**Azure Container Registry (ACR)**

1. **Project Settings** → **Service connections** → **New** → **Azure Resource Manager**.
2. Configure the connection and name it `AzureSubscription` (or update the YAML).
3. Pipeline variables:
   - `DOCKER_REPOSITORY_NAME`: ACR name **without** `.azurecr.io` (e.g. `myregistry`).
   - `DOCKER_IMAGE`: image name (e.g. `my-app`).

**Amazon ECR (ECR)**

Pipeline variables (mark credentials as **secret**):

- `AWS_ACCOUNTID` – AWS account ID.
- `AWS_REGION` – Region (e.g. `us-east-1`).
- `AWS_ACCESS_KEY_ID` – Access Key (secret).
- `AWS_SECRET_ACCESS_KEY` – Secret Access Key (secret).
- `DOCKER_REPOSITORYNAME` – ECR repository name.

**Scanning (Trivy)**

Same variables as ECR. Trivy is installed on the agent; version is fetched dynamically from GitHub.

**Inspector SBOM report (Amazon Inspector → S3)**

This pipeline runs `generate-packages-report/script.sh` which:
- Starts an `inspector2 create-sbom-export` job
- Polls until it completes
- Copies the generated JSON to a stable `latest.json`
- Uploads `metadata.json` describing the run (reportId, status, prefixes, etc.)

Pipeline variables (mark credentials as **secret**):
- `AWS_ACCESS_KEY_ID` – Access Key (secret).
- `AWS_SECRET_ACCESS_KEY` – Secret Access Key (secret).
- `AWS_SESSION_TOKEN` – Session token (secret, optional).

Run parameters (passed as env vars to the script):
- `awsRegion` (default `us-east-1`) → `AWS_REGION`
- `s3Bucket` (**required**) → `S3_BUCKET`
- `s3Prefix` (default `inspector/sbom`) → `S3_PREFIX`
- `ecrRepository` (optional) → `ECR_REPOSITORY`
- `kmsKeyArn` (optional) → `KMS_KEY_ARN`
- `reportFormat` (default `CYCLONEDX_1_4`) → `REPORT_FORMAT`

<img src="generate-packages-report/diagram/diagram.jpg" alt="Inspector SBOM report flow" width="100%" height="350" />

### Usage
1. Copy the pipeline YAML you need into your repo (or use the path in this repo).
2. In Azure DevOps: **Pipelines** → **New pipeline** → choose repo → select the `.yml` file.
3. Set variables and Service Connection as above.
4. Run the pipeline (manually or via trigger).

Pipelines are set to trigger on the `main` branch; you can change the `trigger` in each file.

### Repository structure
```
AzurePipelines/
├── README.md
├── acr.png
├── ecr.png
├── azure-container-registries/
│   ├── azure-pipelines-acr.yml           # ACR basic
│   └── azure-pipelines-complete-acr.yml  # ACR + metadata
├── elastic-container-registry/
│   ├── azure-pipelines-basic-erc.yml     # ECR basic
│   └── azure-pipelines-complete-ecr.yml  # ECR + metadata
├── generate-packages-report/
│   ├── azure-pipelines.yml               # Amazon Inspector SBOM → S3 (latest.json + metadata.json)
│   └── script.sh
└── scaning-docker/
    ├── azure-pipelines.yml               # Build + Trivy + push to ECR
    └── README.md
```

### Diagrams
**Pipeline with Azure Container Registry (ACR)**

<img src="acr.png" alt="Pipeline ACR" width="70%" height="300" />

**Pipeline with Amazon Elastic Container Registry (ECR)**

<img src="ecr.png" alt="Pipeline ECR" width="70%" height="300" />

### Quick summary
- **ACR**: build + push to Azure; “complete” adds metadata (commit, author, version).
- **ECR**: build + push to AWS; “complete” adds metadata.
- **Scanning**: build → Trivy (CRITICAL/HIGH/MEDIUM/LOW) → push to ECR only if scan passes.

---
## Español
Colección de pipelines de **Azure DevOps** para construir imágenes Docker y publicarlas en **Azure Container Registry (ACR)** o **Amazon Elastic Container Registry (ECR)**, con opciones de metadata y escaneo de vulnerabilidades con Trivy.

### Tabla de contenidos
- [Pipelines incluidos](#pipelines-incluidos)
- [Requisitos previos](#requisitos-previos)
- [Configuración](#configuración-1)
- [Uso](#uso)
- [Estructura del repositorio](#estructura-del-repositorio)

### Pipelines incluidos
| Pipeline | Registro | Descripción |
|----------|----------|-------------|
| **ACR (básico)** | Azure Container Registry | Build y push de imagen Docker a ACR. |
| **ACR (completo)** | Azure Container Registry | Build, push y generación de metadata (commit, autor, versión desde `package.json`). |
| **ECR (básico)** | Amazon ECR | Build y push de imagen Docker a ECR. |
| **ECR (completo)** | Amazon ECR | Build, push y generación de metadata. |
| **Scanning** | Amazon ECR | Build, escaneo con **Trivy** (CRITICAL/HIGH/MEDIUM/LOW) y push solo si no hay vulnerabilidades. |
| **Inspector SBOM report** | Amazon Inspector + S3 | Genera un reporte SBOM con **Amazon Inspector**, lo guarda en S3 y mantiene un `latest.json` + `metadata.json` estable para consumir desde una API. |

### Requisitos previos
- **Azure DevOps** con un proyecto configurado.
- **Dockerfile** en la raíz del repo (o ruta indicada en el pipeline).
- Para ACR: **Service Connection** de tipo *Azure Resource Manager* en el proyecto.
- Para ECR: credenciales AWS (Access Key ID y Secret Access Key) o Service Connection de AWS.

### Configuración
**Azure Container Registry (ACR)**

1. En el proyecto: **Project Settings** → **Service connections** → **New service connection** → **Azure Resource Manager**.
2. Configura la conexión con tu suscripción de Azure y nómbrala `AzureSubscription` (o ajusta el nombre en el YAML).
3. Variables de pipeline:
   - `DOCKER_REPOSITORY_NAME`: nombre del ACR **sin** `.azurecr.io` (ej: `miregistry`).
   - `DOCKER_IMAGE`: nombre de la imagen (ej: `mi-app`).

**Amazon ECR (ECR)**

Variables de pipeline (marcar como **secretas** las credenciales):

- `AWS_ACCOUNTID` – ID de la cuenta AWS.
- `AWS_REGION` – Región (ej: `us-east-1`).
- `AWS_ACCESS_KEY_ID` – Access Key (secreto).
- `AWS_SECRET_ACCESS_KEY` – Secret Access Key (secreto).
- `DOCKER_REPOSITORYNAME` – Nombre del repositorio en ECR.

**Pipeline de scanning (Trivy)**

Usa las mismas variables que los pipelines de ECR. Trivy se instala en el agente; la versión se obtiene dinámicamente desde GitHub.

**Inspector SBOM report (Amazon Inspector → S3)**

Este pipeline ejecuta `generate-packages-report/script.sh`, que:
- Dispara un `inspector2 create-sbom-export`
- Hace polling hasta que termine
- Copia el JSON generado a un `latest.json` estable
- Sube `metadata.json` con información de la corrida (reportId, status, prefixes, etc.)

Variables de pipeline (marcar credenciales como **secretas**):
- `AWS_ACCESS_KEY_ID` – Access Key (secreto).
- `AWS_SECRET_ACCESS_KEY` – Secret Access Key (secreto).
- `AWS_SESSION_TOKEN` – Session token (secreto, opcional).

Parámetros de ejecución (se pasan como env vars al script):
- `awsRegion` (default `us-east-1`) → `AWS_REGION`
- `s3Bucket` (**obligatorio**) → `S3_BUCKET`
- `s3Prefix` (default `inspector/sbom`) → `S3_PREFIX`
- `ecrRepository` (opcional) → `ECR_REPOSITORY`
- `kmsKeyArn` (opcional) → `KMS_KEY_ARN`
- `reportFormat` (default `CYCLONEDX_1_4`) → `REPORT_FORMAT`

<img src="generate-packages-report/diagram/diagram.jpg" alt="Flujo Inspector SBOM report" width="100%" height="350" />

### Uso
1. Copia el YAML del pipeline que necesites a tu repositorio (o usa la ruta existente en este repo).
2. Crea un **nuevo pipeline** en Azure DevOps: *Pipelines* → *New pipeline* → *Azure Repos Git* (o GitHub, etc.) → selecciona el `.yml` correspondiente.
3. Configura las variables y la Service Connection según la tabla anterior.
4. Ejecuta el pipeline (manual o con el trigger definido en el YAML).

Los pipelines están configurados para dispararse en la rama `main`; puedes cambiar el `trigger` en cada archivo.

### Estructura del repositorio
```
AzurePipelines/
├── README.md
├── acr.png
├── ecr.png
├── azure-container-registries/
│   ├── azure-pipelines-acr.yml           # ACR básico
│   └── azure-pipelines-complete-acr.yml  # ACR + metadata
├── elastic-container-registry/
│   ├── azure-pipelines-basic-erc.yml     # ECR básico
│   └── azure-pipelines-complete-ecr.yml  # ECR + metadata
├── generate-packages-report/
│   ├── azure-pipelines.yml               # Amazon Inspector SBOM → S3 (latest.json + metadata.json)
│   └── script.sh
└── scaning-docker/
    ├── azure-pipelines.yml               # Build + Trivy + push a ECR
    └── README.md
```

### Diagramas

**Pipeline con Azure Container Registry (ACR)**

<img src="acr.png" alt="Pipeline ACR" width="70%" height="300" />

**Pipeline con Amazon Elastic Container Registry (ECR)**

<img src="ecr.png" alt="Pipeline ECR" width="70%" height="300" />

### Resumen rápido

- **ACR**: build + push a Azure; versión “completa” con metadata (commit, autor, versión).
- **ECR**: build + push a AWS; versión “completa” con metadata.
- **Scanning**: build → Trivy (CRITICAL/HIGH/MEDIUM/LOW) → push a ECR solo si el escaneo pasa.
