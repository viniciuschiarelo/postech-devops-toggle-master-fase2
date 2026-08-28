<div align="center">
  <img src="https://avatars.githubusercontent.com/u/79948663?s=200&v=4" alt="img" width="150"><br>
  <h3>Tech Challenge - Fase 2</h3>
</div><br>

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

## Sobre o Projeto

O **ToggleMaster** é uma plataforma centralizada para gerenciamento e avaliação de **Feature Flags (Feature Toggles)** desenvolvida para a *DevOps Solutions Inc.* Após o sucesso do MVP monolítico na Fase 1, o aumento na demanda exigiu a evolução da plataforma para resolver gargalos de performance e escalabilidade.

Este repositório contém a entrega da **Fase 2 do Tech Challenge**, documentando a decomposição e migração do sistema para uma **arquitetura distribuída de 5 microsserviços**, conteinerizada com Docker (builds multi-stage) e orquestrada em um cluster **Amazon EKS (Kubernetes)** integrado aos serviços gerenciados de persistência, cache e mensageria da AWS.

---

## 🏗️ Arquitetura dos Microsserviços

O ecossistema foi dividido em serviços desacoplados e isolados por **Namespaces** no Kubernetes:

| Microsserviço | Linguagem / Runtime | Responsabilidade Técnica | Camada de Persistência / Integração |
| :--- | :---: | :--- | :--- |
| **`auth-service`** | Go 1.22 | Autenticação, gestão de permissões e chaves de API. | Amazon RDS PostgreSQL (`toggle-auth-db`) |
| **`flag-service`** | Python 3.12 | CRUD e manutenção das definições de feature flags. | Amazon RDS PostgreSQL (`toggle-flag-db`) |
| **`targeting-service`** | Python 3.12 | Regras complexas de segmentação de público e contexto. | Amazon RDS PostgreSQL (`toggle-targeting-db`) |
| **`evaluation-service`** | Go 1.22 | *Hot path* de altíssima performance responsável por retornar a decisão final (`true`/`false`). | Amazon ElastiCache (Redis) + Produtor Amazon SQS |
| **`analytics-service`** | Python 3.12 | Consumo assíncrono de eventos de métricas e telemetria de uso. | Consumidor Amazon SQS + Amazon DynamoDB |

---

## 🛠️ Infraestrutura e Nuvem (AWS & Kubernetes)

A infraestrutura do projeto foi provisionada de forma automatizada e declarativa via **`eksctl`** em conta pessoal (Opção B), permitindo a utilização de recursos nativos de IAM sem as restrições de permissões do ambiente AWS Academy.

### Componentes de Infraestrutura:
* **Amazon EKS (`toggle-master-cluster`):** Cluster Kubernetes v1.29 provisionado via `eksctl`, com Managed Node Group (`t3.medium`) distribuído em auto-scaling (Mín: 1, Desejado: 2, Máx: 4).
* **Amazon ECR:** Repositórios privados dedicados para versionamento das imagens Docker multi-stage de cada um dos 5 serviços.
* **Amazon RDS PostgreSQL (x3):** Três instâncias de banco de dados relacional independentes (`db.t3.micro`), garantindo o completo isolamento da camada de dados entre os domínios de `auth`, `flags` e `targeting`.
* **Amazon ElastiCache for Redis:** Cluster em memória responsável pelo cache de leitura de baixíssima latência no *hot path* do `evaluation-service`.
* **Amazon SQS:** Fila de eventos do tipo *Standard* para o desacoplamento assíncrono entre a produção de eventos de avaliação (`evaluation`) e seu processamento (`analytics`).
* **Amazon DynamoDB:** Tabela NoSQL (`AnalyticsEvents`) operando em modo *On-Demand* para rápida gravação e persistência de dados analíticos.

---

## 🔒 Segurança, Segredos e Ingress

* **Nginx Ingress Controller:** Ponto único de entrada do cluster via AWS Load Balancer, roteando chamadas HTTP diretamente para os serviços ClusterIP por prefixos de rota (`/auth`, `/flags`, `/targeting`, `/evaluate`, `/events`).
* **ConfigMaps & Secrets:** Segregação estrita entre configurações não sensíveis (URLs internas, tabelas) e dados sensíveis (credenciais codificadas em `base64`), gerados dinamicamente no deploy.
* **IAM Roles for Service Accounts (IRSA):** Permissões de acesso aos recursos AWS (SQS e DynamoDB) vinculadas diretamente às *ServiceAccounts* dos pods, eliminando a necessidade de credenciais estáticas (`Access Keys`) no cluster.

---

## ⚡ Escalabilidade Automática (HPA)

O ambiente foi configurado com **Horizontal Pod Autoscaling (HPA)** monitorando a utilização média de CPU e recursos do cluster:
* **`evaluation-service`:** Escalonamento dinâmico ajustado para responder ao aumento de tráfego sintético no *hot path*.
* **`analytics-service`:** Escalonamento configurado para suprir a demanda de processamento de mensagens em momentos de pico na fila SQS.

---

## 🧪 Ambiente Local (Docker Compose)

Para validação e testes de integração local, o arquivo `docker-compose.yml` na raiz do repositório inicializa **9 contêineres** (5 microsserviços + 2 PostgreSQL + 1 Redis + 1 DynamoDB Local):

```bash
# Subir todo o ecossistema localmente
docker compose up -d

# Validar o status de integridade dos serviços
docker compose ps
---

```

## Demonstração Prática

O ciclo completo de execução da aplicação local, validação de regras, infraestrutura implantada na AWS e acesso à API integrada ao banco de dados pode ser visualizado no vídeo de demonstração:

▶️ [Assistir ao Vídeo de Demonstração no YouTube]()

---

## Integrantes — Grupo 25

* **Thiago Souza**
* **Larissa Nunes**
* **Luiz Ferreira**
* **Nicholas Lima**
* **Vinicius Chiarelo**
* **Vinicius Chiarelo**

---

*Agosto de 2026 — Pós-Tech DevOps*
