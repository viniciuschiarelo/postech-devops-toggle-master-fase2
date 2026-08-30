# Checklist  — ToggleMaster - POSTECH - FIAP - Fase 2

# Nosso Grupo

- Larissa N.
- Luiz F.
- Nicholas L.
- Thiago S.
- Vinícius C.



---

## 1. Validar ambiente local

- [ ] Confirmar que os containers locais estão em execução:

```powershell
docker compose ps

curl.exe http://localhost:8001/health
curl.exe http://localhost:8002/health
curl.exe http://localhost:8003/health
curl.exe http://localhost:8004/health
curl.exe http://localhost:8005/health

curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
curl http://localhost:8004/health
curl http://localhost:8005/health
```

- [ ] Validar se os serviços aparecem como `Up` / `Running`.

---

## 2. Validar os Pods no Kubernetes

- [ ] Verificar namespace `auth`:

```powershell
kubectl get pods -n auth
```

- [ ] Verificar namespace `flag`:

```powershell
kubectl get pods -n flag
```

- [ ] Verificar namespace `targeting`:

```powershell
kubectl get pods -n targeting
```

- [ ] Verificar namespace `evaluation`:

```powershell
kubectl get pods -n evaluation
```

- [ ] Verificar namespace `analytics`:

```powershell
kubectl get pods -n analytics
```

- [ ] Exibir visão geral de todos os Pods e nodes onde estão executando:

```powershell
kubectl get pods -A -o wide
```

**Validar:** Pods devem estar preferencialmente em `Running` e com `READY` completo.

---

## 3. Demonstrar o NGINX Ingress

- [ ] Mostrar o Service do NGINX Ingress Controller:

```powershell
kubectl get service ingress-nginx-controller -n ingress-nginx
```

- [ ] Confirmar que existe um `EXTERNAL-IP` / Load Balancer AWS associado.

### Testar o auth-service

- [ ] Executar:

```powershell
curl.exe "http://a3c39eb4b583f4026ba817e8a57009bc-1765681797.us-east-1.elb.amazonaws.com/auth/health"
```

- [ ] Confirmar retorno de saúde do serviço.

### Testar o analytics-service

- [ ] Executar:

```powershell
curl.exe "http://a3c39eb4b583f4026ba817e8a57009bc-1765681797.us-east-1.elb.amazonaws.com/analytics/health"
```

- [ ] Confirmar retorno de saúde do serviço.

### Testar o evaluation-service

- [ ] Executar:

```powershell
curl.exe "http://a3c39eb4b583f4026ba817e8a57009bc-1765681797.us-east-1.elb.amazonaws.com/evaluate?user_id=aluno-1&flag_name=nova-tela"
```

- [ ] Confirmar que a avaliação da feature flag retorna corretamente.

---

## 4. Demonstrar o HPA do `evaluation-service`

### Terminal 1 — HPA

- [ ] Acompanhar o HPA:

```powershell
kubectl get hpa -n evaluation -w
```

### Terminal 2 — Pods

- [ ] Acompanhar a criação/remoção de Pods:

```powershell
kubectl get pods -n evaluation -w
```

### Terminal 3 — Gerar carga

- [ ] Executar carga durante 1 minuto com 100 conexões concorrentes:

```powershell
hey -z 1m -c 100 "http://a3c39eb4b583f4026ba817e8a57009bc-1765681797.us-east-1.elb.amazonaws.com/evaluate?user_id=teste-carga&flag_name=nova-tela"
```

- [ ] Observar aumento de CPU/uso no HPA.
- [ ] Demonstrar o aumento do número de réplicas.
- [ ] Após finalizar a carga, mostrar a estabilização e posterior redução das réplicas.

---

## 5. Enviar mensagens manualmente para o Amazon SQS

### Consultar a fila antes do teste

- [ ] Verificar quantidade de mensagens disponíveis e em processamento:

```powershell
aws sqs get-queue-attributes --queue-url "https://sqs.us-east-1.amazonaws.com/565393067303/togglemaster-events" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --region us-east-1
```

### Enviar 50 mensagens

- [ ] Executar:

```powershell
1..50 | ForEach-Object { $body = @{user_id="manual-$_";flag_name="nova-tela";result=$true;timestamp=(Get-Date).ToUniversalTime().ToString("o")} | ConvertTo-Json -Compress; aws sqs send-message --queue-url "https://sqs.us-east-1.amazonaws.com/565393067303/togglemaster-events" --message-body $body --region us-east-1 | Out-Null }; Write-Host "50 mensagens enviadas"
```

- [ ] Confirmar a mensagem:

```text
50 mensagens enviadas
```

- [ ] Consultar novamente os atributos da fila:

```powershell
aws sqs get-queue-attributes --queue-url "https://sqs.us-east-1.amazonaws.com/565393067303/togglemaster-events" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --region us-east-1
```

- [ ] Demonstrar que o `analytics-service` está consumindo as mensagens.

---

## 6. Demonstrar o HPA do `analytics-service`

### Reduzir temporariamente o threshold de CPU

&#x20;kubectl get hpa analytics-hpa -n analytics

- [ ] Alterar o HPA para escalar com `10%` de utilização:

```powershell
kubectl edit hpa analytics-hpa -n analytics

```

### Monitorar o HPA

- [ ] Terminal 1:

```powershell
kubectl get hpa -n analytics -w
```

### Monitorar os Pods

- [ ] Terminal 2:

```powershell
kubectl get pods -n analytics -w
```

### Monitorar CPU

- [ ] Terminal 3:

```powershell
kubectl top pods -n analytics
```

### Gerar 5.000 mensagens no SQS

- [ ] Terminal 4:

```powershell
1..5000 | ForEach-Object { $body = @{user_id="carga-analytics-$_";flag_name="nova-tela";result=$true;timestamp=(Get-Date).ToUniversalTime().ToString("o")} | ConvertTo-Json -Compress; aws sqs send-message --queue-url "https://sqs.us-east-1.amazonaws.com/565393067303/togglemaster-events" --message-body $body --region us-east-1 | Out-Null }; Write-Host "5000 mensagens enviadas"
```

- [ ] Observar o aumento de utilização.
- [ ] Mostrar o HPA aumentando a quantidade de réplicas.
- [ ] Mostrar novos Pods sendo criados.
- [ ] Mostrar o consumo das mensagens pelo `analytics-service`.

### IMPORTANTE — Restaurar o HPA

- [ ] Ao finalizar a demonstração, restaurar o threshold para `70%`:

```powershell
kubectl get hpa analytics-hpa -n analytics

kubectl edit hpa analytics-hpa -n analytics


```

Confirmar configuração restaurada:

```powershell
kubectl get hpa analytics-hpa -n analytics

```

---

## 7. Demonstrar os dados gravados no DynamoDB

### Mostrar exemplos de registros

- [ ] Consultar até 10 itens da tabela:

```powershell
aws dynamodb scan --table-name ToggleMasterAnalytics --max-items 10 --region us-east-1
```

- [ ] Demonstrar campos como `user_id`, `flag_name`, `result` e `timestamp`, caso estejam presentes no modelo.

### Mostrar quantidade total de registros

- [ ] Executar:

```powershell
$contagens = aws dynamodb scan --table-name ToggleMasterAnalytics --select COUNT --region us-east-1 --query Count --output text
($contagens | ForEach-Object { [int]$_ } | Measure-Object -Sum).Sum
```

- [ ] Registrar a quantidade retornada.
- [ ] Relacionar os registros do DynamoDB com as mensagens processadas pelo `analytics-service`.

