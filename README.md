# demo-app · Kubernetes + Argo CD

Aplicação web bem simples (Nginx + uma página) em duas versões, **1.0** (azul) e **1.1** (verde),
para demonstrar GitOps com o Argo CD: troca-se a versão **com um commit no Git**, sem `kubectl apply`.

```
argocd-demo-app/
├── app/
│   ├── Dockerfile          # nginx:1.28-alpine + a página da versão escolhida
│   ├── nginx.conf          # página, /version e /healthz
│   ├── v1.0/index.html     # versão 1.0 (azul)
│   └── v1.1/index.html     # versão 1.1 (verde, com "o que mudou")
├── k8s/                    # o que o Argo CD aplica no cluster
│   ├── deployment.yaml     # 3 réplicas, rolling update sem downtime
│   └── service.yaml        # NodePort 30080
├── argocd/
│   └── application.yaml    # a "Application" do Argo CD
├── scripts/
│   └── build-push.sh       # gera e publica as imagens 1.0 e 1.1
└── .github/workflows/
    └── build-push.yaml     # (opcional) build automático ao criar tag
```

## Quem faz o quê

| Peça | Guarda | Quem lê |
|---|---|---|
| **GitHub** | código e manifestos (`k8s/`) | Argo CD |
| **Docker Hub** | imagens `demo-app:1.0` e `demo-app:1.1` | o cluster (kubelet) |
| **Argo CD** | nada: compara o Git com o cluster e sincroniza | — |

O que cada versão mostra:

- **Página:** versão grande na tela e o **nome do pod** que respondeu. Recarrega sozinha a cada 5 s.
- **`/version`:** `{"app":"demo-app","version":"1.1","pod":"demo-app-xxxx"}`
- **`/healthz`:** `ok` (usado pelas probes)

---

## 1. Ajustar seus usuários

Troque os marcadores pelos seus usuários (rode na raiz do repositório):

```bash
# Linux
sed -i 's/SEU_USUARIO_DOCKERHUB/joao/g' k8s/deployment.yaml
sed -i 's/SEU_USUARIO_GITHUB/joao/g'    argocd/application.yaml

# macOS
sed -i '' 's/SEU_USUARIO_DOCKERHUB/joao/g' k8s/deployment.yaml
sed -i '' 's/SEU_USUARIO_GITHUB/joao/g'    argocd/application.yaml
```

## 2. Publicar no GitHub

Crie um repositório **público** chamado `argocd-demo-app` (público dispensa configurar credencial no Argo CD) e:

```bash
git init -b main
git add .
git commit -m "demo-app 1.0"
git remote add origin https://github.com/joao/argocd-demo-app.git
git push -u origin main
```

## 3. Publicar as imagens no Docker Hub

**Opção A, na sua máquina** (gera amd64 e arm64):

```bash
docker login
./scripts/build-push.sh joao
```

**Opção B, pelo GitHub Actions:** cadastre os secrets `DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`
(Settings → Secrets and variables → Actions) e crie as tags:

```bash
git tag v1.0 && git push origin v1.0
git tag v1.1 && git push origin v1.1
```

> As imagens precisam ficar **públicas** no Docker Hub (o padrão). Se forem privadas, o cluster
> vai precisar de um `imagePullSecret`.

Teste local rápido, antes do cluster:

```bash
docker run --rm -p 8080:80 joao/demo-app:1.0
# abra http://localhost:8080  e  http://localhost:8080/version
```

## 4. Instalar o Argo CD no lab

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

# senha inicial do usuário admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# interface web em https://localhost:8443 (usuário: admin)
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

## 5. Criar a aplicação no Argo CD

```bash
kubectl apply -f argocd/application.yaml
```

Em alguns segundos a aplicação aparece na interface, sincroniza e sobe 3 pods da **1.0**:

```bash
kubectl get pods -n demo-app
```

## 6. Acessar a aplicação

**No navegador:** `http://<IP-de-um-node>:30080`.

No **kind**, use port-forward:

```bash
kubectl port-forward -n demo-app svc/demo-app 8080:80
```

O port-forward fica preso a **um** pod e cai quando esse pod é trocado no rollout.

**Para a demo, o melhor é um "curl em loop" de dentro do cluster.** Ele passa pelo Service, mostra os
pods se revezando e a versão mudando ao vivo:

```bash
kubectl run -n demo-app curl --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'while true; do curl -s demo-app/version; sleep 1; done'
```

---

## Roteiro da demonstração

### 1) Deploy por commit (1.0 → 1.1)

1. Com o curl em loop rodando, edite `k8s/deployment.yaml`:
   ```yaml
   image: joao/demo-app:1.1
   ```
2. Commit e push:
   ```bash
   git commit -am "demo-app 1.1" && git push
   ```
3. No Argo CD, clique em **Refresh**. Sem isso ele confere o Git sozinho a cada ~3 min.
4. Mostre a aplicação ficando **OutOfSync** e logo **Synced**, os pods sendo trocados um a um, e o loop
   mostrando `1.0` e `1.1` misturados até ficar só `1.1`. **Sem nenhuma requisição falhar.**

### 2) Rollback

- **Jeito GitOps:** `git revert HEAD && git push`. O Git volta e o cluster acompanha.
- **Pela interface:** *History and Rollback*. Com `selfHeal` ligado, o Argo CD volta para o que está no
  Git na próxima sincronização. É um bom gancho para explicar que **o Git é a fonte da verdade**.

### 3) Self-heal (alguém mexeu na mão)

```bash
kubectl scale deploy demo-app -n demo-app --replicas=1
kubectl get pods -n demo-app -w
```

Em segundos o Argo CD percebe a diferença e volta para **3 réplicas**, como está no Git.

### 4) Prune

Apague `k8s/service.yaml` no Git, faça commit e push: o Service some do cluster.
Depois desfaça com `git revert`.
