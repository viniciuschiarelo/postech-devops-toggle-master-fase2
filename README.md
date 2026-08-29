<div align="center">
  <img src="https://avatars.githubusercontent.com/u/79948663?s=200&v=4" alt="FIAP" width="150"><br>
  <h3>Tech Challenge — Fase 2 (Pós-Tech DevOps)</h3>
</div>

# ToggleMaster — Ecossistema de Microsserviços em Kubernetes (AWS EKS)

<p align="center">
  <img src="https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white" alt="AWS">
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" alt="Kubernetes">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis">
  <img src="https://img.shields.io/badge/DynamoDB-4053D6?style=for-the-badge&logo=amazondynamodb&logoColor=white" alt="DynamoDB">
</p>

## 1. Sobre o Projeto

O **ToggleMaster** é uma plataforma centralizada para gerenciamento e avaliação de **Feature Flags (Feature Toggles)** desenvolvida para a *DevOps Solutions Inc.* Após o sucesso do MVP monolítico na Fase 1, a alta demanda exigiu a evolução da solução para resolver gargalos de performance e escalabilidade.

Esta entrega documenta a decomposição e migração do monólito para um **ecossistema distribuído de 5 microsserviços**, conteinerizados com Docker (builds multi-stage em Go e otimizações em Python) e orquestrados em um cluster **Amazon EKS (Kubernetes)** integrado aos serviços gerenciados de persistência, cache e mensageria da AWS.

---

## 2. Arquitetura dos Microsserviços

O ecossistema foi dividido em serviços desacoplados e isolados por **Namespaces** no Kubernetes:

| Microsserviço | Linguagem / Runtime | Responsabilidade Técnica | Camada de Persistência / Integração |
| :--- | :---: | :--- | :--- |
| **`auth-service`** | Go 1.22 | Autenticação, gestão de permissões e chaves de API. | Amazon RDS PostgreSQL (`toggle-auth-db`) |
| **`flag-service`** | Python 3.12 | CRUD e manutenção das definições de feature flags. | Amazon RDS PostgreSQL (`toggle-flag-db`) |
| **`targeting-service`** | Python 3.12 | Regras complexas de segmentação de público e contexto. | Amazon RDS PostgreSQL (`toggle-targeting-db`) |
| **`evaluation-service`** | Go 1.22 | *Hot path* de alta performance que retorna a decisão final (`true`/`false`). | Amazon ElastiCache (Redis) + Produtor Amazon SQS |
| **`analytics-service`** | Python 3.12 | Consumo assíncrono de eventos de métricas e telemetria de uso. | Consumidor Amazon SQS + Amazon DynamoDB |

---

## 3. Subindo a Aplicação Localmente (Docker Compose)

Para validação e testes de integração local, o projeto conta com um arquivo `docker-compose.yml` que inicializa **9 contêineres** (5 microsserviços + 2 PostgreSQL + 1 Redis + 1 DynamoDB Local).

### Execução Local:

```bash
# Subir todo o ecossistema localmente em background
docker compose up -d

# Validar o status de integridade dos 9 contêineres
docker compose ps

```

---

## 4. Orquestração e Implantação no Kubernetes (AWS EKS)

A infraestrutura foi provisionada via `eksctl` em conta pessoal (Opção B), permitindo a utilização de recursos nativos de IAM via IRSA (*IAM Roles for Service Accounts*) para segurança e granularidade de acesso.

### Principais Componentes de Infraestrutura

- **Cluster EKS**: Cluster Kubernetes `v1.29` com *Managed Node Group* (`t3.medium`) e *Auto Scaling* (Mín: 1, Desejado: 2, Máx: 4).
- **Metrics Server**: Instalado no cluster para coleta de métricas de CPU/Memória, essencial para o funcionamento do HPA.
- **ConfigMaps & Secrets**: Segregação estrita de variáveis não sensíveis e credenciais codificadas em `base64`.

### Comandos de Implantação Local/Kubeconfig

```bash
# 1. Configurar o contexto do kubectl para o cluster EKS
aws eks update-kubeconfig --region us-east-1 --name toggle-master-cluster

# 2. Aplicar os manifestos de cada microsserviço
kubectl apply -f k8s/

# 3. Verificar o status dos Pods em todos os namespaces
kubectl get pods -A
```

---

## 5. Acesso Externo e Roteamento (Nginx Ingress)

O Nginx Ingress Controller foi implantado via Helm, provisionando automaticamente um Load Balancer na AWS como ponto único de entrada da aplicação.

### Tabela de Roteamento (Ingress Rules)

| Rota Externa | Serviço Destino (ClusterIP) | Porta |
| :--- | :--- | :---: |
| `/auth` | `auth-service` | `8080` |
| `/flags` | `flag-service` | `8000` |
| `/targeting` | `targeting-service` | `8000` |
| `/evaluate` | `evaluation-service` | `8080` |
| `/events` | `analytics-service` | `8000` |

### Teste de Acesso Externo

```bash
# Obter o endereço do Load Balancer
INGRESS_HOST=$(kubectl get ingress -n evaluation -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Validar o healthcheck do caminho quente (evaluation-service)
curl -i http://$INGRESS_HOST/evaluate/health
```

---

## 6. Escalabilidade Automática (HPA) e Teste de Carga

A escalabilidade horizontal foi configurada utilizando o *Horizontal Pod Autoscaler* (HPA), que monitora a utilização média de CPU dos Pods.

### Configurações de HPA

- **`evaluation-service`**: Mínimo de 2 réplicas, Máximo de 6 réplicas (alvo: `70%` de uso de CPU).
- **`analytics-service`**: Mínimo de 1 réplica, Máximo de 5 réplicas (alvo: `65%` de uso de CPU).

### Como Executar o Teste de Carga com `hey`

Para testar a automação e visualizar os Pods escalando dinamicamente:

```bash
# 1. Em um terminal, acompanhe o HPA em tempo real
kubectl get hpa -n evaluation -w

# 2. Em outro terminal, envie tráfego sintético para o evaluation-service
hey -z 2m -c 50 -q 10 http://$INGRESS_HOST/evaluate
```

Observe o aumento no consumo de CPU e a criação de novas réplicas no cluster.

---

## 7. Demonstração em Vídeo

O ciclo completo de execução da aplicação local, validação de regras, infraestrutura na AWS e testes de carga pode ser acompanhado no vídeo de demonstração:

Assistir ao Vídeo de Demonstração no YouTube.

---

## 8. Integrantes - Grupo 13

- Larissa Nunes - RM 367056
- Luiz Ferreira - RM 375308
- Nicholas Lima - RM 374429
- Thiago Souza - RM 374954
- Vinicius Chiarelo - RM 375311

FIAP - Pós-Tech DevOps & Cloud Architecture - 2026
