#!/bin/bash

NAMESPACE="cicd"
ARGO_NAMESPACE="argocd"
APP_NAMESPACE="weather-app"

echo "=== Argo CD CI/CD Pipeline Setup ==="

# 1. Create application namespace
echo "[1/6] Creating application namespace..."
kubectl create namespace $APP_NAMESPACE 2>/dev/null || echo "Namespace $APP_NAMESPACE already exists"

# 2. Apply ConfigMap and basic resources
echo "[2/6] Applying ConfigMap and resources..."
cat > /tmp/weather-app-resources.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: weather-app-config
  namespace: weather-app
data:
  PORT: "3000"
  ENV: "dev"
  APP_VERSION: "1.0.0"
  LOG_LEVEL: "info"
---
apiVersion: v1
kind: Service
metadata:
  name: weather-app
  namespace: weather-app
  labels:
    app: weather-app
spec:
  type: ClusterIP
  selector:
    app: weather-app
  ports:
  - port: 80
    targetPort: 3000
    name: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather-app
  namespace: weather-app
  labels:
    app: weather-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: weather-app
  template:
    metadata:
      labels:
        app: weather-app
    spec:
      containers:
      - name: weather-app
        image: nginx:1.25
        ports:
        - containerPort: 3000
EOF
kubectl apply -f /tmp/weather-app-resources.yaml -n $APP_NAMESPACE

# 3. Create RBAC for workflow
echo "[3/6] Creating RBAC..."
kubectl create serviceaccount argo-workflow -n $NAMESPACE 2>/dev/null || true
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-workflow-deploy
  namespace: $APP_NAMESPACE
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services", "configmaps"]
  verbs: ["get", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-workflow-deploy-binding
  namespace: $APP_NAMESPACE
subjects:
- kind: ServiceAccount
  name: argo-workflow
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: argo-workflow-deploy
  apiGroup: rbac.authorization.k8s.io
EOF

# 4. Deploy Argo CD Application
echo "[4/6] Deploying Argo CD Application..."
cat > /tmp/argocd-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: weather-app
  namespace: argocd
  labels:
    app: weather-app
    environment: dev
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argo-cd.git
    targetRevision: master
    path: applicationset/examples/applications-sync-policies/guestbook/engineering-dev
  destination:
    server: https://kubernetes.default.svc
    namespace: weather-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Add repo if not exists
argocd repo add https://github.com/argoproj/argo-cd.git --insecure 2>/dev/null || true
kubectl apply -f /tmp/argocd-app.yaml -n $ARGO_NAMESPACE

# 5. Create workflow
echo "[5/6] Creating CI/CD WorkflowTemplate..."
cat > /tmp/ci-workflow.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ci-pipeline-local
  namespace: cicd
spec:
  arguments:
    parameters:
    - name: image-name
      value: weatherlab/weather-app
    - name: image-tag
      value: "v1.0.0"
  entrypoint: main
  serviceAccountName: argo-workflow
  templates:
  - name: main
    dag:
      tasks:
      - name: run-tests
        templateRef:
          name: run-tests
          template: unit-tests
        arguments:
          parameters:
          - name: repo-path
            value: /workspace/repo
      - name: build-image
        templateRef:
          name: docker-build
          template: build
        arguments:
          parameters:
          - name: image-name
            value: '{{workflow.parameters.image-name}}'
          - name: image-tag
            value: '{{workflow.parameters.image-tag}}'
          - name: repo-path
            value: /workspace/repo
        dependencies:
        - run-tests
EOF
kubectl apply -f /tmp/ci-workflow.yaml -n $NAMESPACE

echo "[6/6] Setup complete!"
echo ""
echo "=== Next Steps ==="
echo "1. Access Argo CD UI:"
echo "   open https://localhost:8080/applications"
echo ""
echo "2. Application Status:"
argocd app list
echo ""
echo "3. Run CI workflow:"
echo "   argo submit -n cicd -f /tmp/ci-workflow.yaml -p image-tag=v1.0.0-$(date +%Y%m%d)"
echo ""
echo "4. View pods:"
echo "   kubectl get pods -n weather-app"