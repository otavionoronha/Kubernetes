# Parâmetros de configuração
$RKE2_SERVER_IP = "192.168.31.150"  # Substitua pelo IP do servidor RKE2
$RKE2_TOKEN = "X5l3kSeuHpPEFGke"     # Substitua pelo token de ingresso

# 1. Habilitar o recurso de contêineres no Windows
if ((Get-WindowsFeature -Name Containers).Installed -eq $false){
	Write-Host "Habilitando o recurso de contêineres..."
	Enable-WindowsOptionalFeature -Online -FeatureName Containers -All 
	Restart-Computer -Force
}

# 3. Baixar e instalar os binários do Kubernetes
Write-Host "Baixando os binários do Kubernetes..."
Invoke-WebRequest -Uri "https://dl.k8s.io/v1.25.0/kubernetes-node-windows-amd64.tar.gz" -OutFile "$env:TEMP\kubernetes.tar.gz"
Expand-Archive -Path "$env:TEMP\kubernetes.tar.gz" -DestinationPath "C:\k"
$env:Path += ";C:\k"

# 4. Configurar o kubelet
Write-Host "Configurando o kubelet..."
@"
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
clusterDNS:
  - 10.96.0.10
clusterDomain: cluster.local
"@ | Out-File -FilePath "C:\k\kubelet-config.yaml"

# 5. Configurar o kubeadm para ingressar no cluster
Write-Host "Configurando o kubeadm..."
@"
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: $RKE2_SERVER_IP:6443
    token: $RKE2_TOKEN
nodeRegistration:
  kubeletExtraArgs:
    node-labels: "kubernetes.io/os=windows"
"@ | Out-File -FilePath "C:\k\kubeadm-config.yaml"

# 6. Executar o kubeadm join
Write-Host "Ingressando no cluster RKE2..."
kubeadm join $RKE2_SERVER_IP:6443 --token $RKE2_TOKEN --discovery-token-ca-cert-hash sha256:$RKE2_CERT_HASH

# 7. Instalar o Calico
Write-Host "Baixando e instalando o Calico..."
Invoke-WebRequest -Uri "https://github.com/projectcalico/calico/releases/download/v3.29.2/calico-windows-v3.29.2.zip" -OutFile "$env:TEMP\calico-windows.zip"
Expand-Archive -Path "$env:TEMP\calico-windows.zip" -DestinationPath "C:\Calico"

# 8. Configurar o Calico
Write-Host "Configurando o Calico..."
@"
`$env:CALICO_NETWORKING_BACKEND = "vxlan"
`$env:KUBE_NETWORK = "Calico"
`$env:SERVICE_CIDR = "10.96.0.0/12"
`$env:DNS_SERVER_IP = "10.96.0.10"
"@ | Out-File -FilePath "C:\Calico\config.ps1"

# 9. Iniciar o Calico
Write-Host "Iniciando o Calico..."
Start-Process -FilePath "powershell.exe" -ArgumentList "-File C:\Calico\start-calico.ps1" -Wait

Write-Host "Instalação concluída! O nó Windows foi adicionado ao cluster RKE2."
