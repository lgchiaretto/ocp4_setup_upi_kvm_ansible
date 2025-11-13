# Configuração de Rede Libvirt com DNS Integrado

## Visão Geral

Esta automação configura DNS diretamente na rede libvirt, eliminando a necessidade de modificar o NetworkManager do host. A configuração é completamente isolada e pode ser facilmente revertida.

## Tipos de Rede

### 1. **Rede Dedicada por Cluster (Padrão - Recomendado)**
- Cria uma rede libvirt dedicada chamada `<clustername>-net`
- DNS e DHCP configurados especificamente para o cluster
- **Automaticamente removida** quando o cluster é destruído
- Isolamento completo entre clusters
- Não afeta outras redes ou clusters

### 2. **Rede Compartilhada (Avançado)**
- Usa uma rede libvirt existente especificada por `kvmnetwork`
- Reconfigura temporariamente a rede com DNS do cluster
- Backup automático da configuração original
- **Restaura configuração original** quando o cluster é destruído
- Útil quando você precisa usar uma rede específica existente

## Configuração

### Rede Dedicada (Padrão)

No arquivo `ansible-vars-kvm.yaml`:

```yaml
clustername: 'my-cluster'
basedomain: 'example.com'

# Cria rede dedicada <clustername>-net (recomendado)
ocp_cluster_use_dedicated_network: true

# kvmnetwork não é usado quando dedicated network está ativo
kvmnetwork: 'default'
```

**Resultado**: Cria rede `my-cluster-net` automaticamente removida no destroy.

### Rede Compartilhada

```yaml
clustername: 'my-cluster'
basedomain: 'example.com'

# Usa rede existente (avançado)
ocp_cluster_use_dedicated_network: false

# Nome da rede libvirt existente a ser usada
kvmnetwork: 'default'
```

**Resultado**: Usa rede `default`, faz backup, reconfigura com DNS, restaura no destroy.

## O que é Configurado

### DNS (ambos os modos)

**SNO (Single Node OpenShift):**
- `<clustername>-master-0.<domain>` → Master IP
- `etcd-0.<clustername>.<domain>` → Master IP
- `api.<clustername>.<domain>` → Master IP
- `api-int.<clustername>.<domain>` → Master IP
- `*.apps.<clustername>.<domain>` → Master IP (wildcard)
- 1 registro SRV para etcd

**3-node:**
- `<clustername>-master-{0,1,2}.<domain>` → Master IPs
- `etcd-{0,1,2}.<clustername>.<domain>` → Master IPs
- `api.<clustername>.<domain>` → Load Balancer IP
- `api-int.<clustername>.<domain>` → Load Balancer IP
- `*.apps.<clustername>.<domain>` → Load Balancer IP
- `<clustername>-bootstrap.<domain>` → Bootstrap IP (temporário)
- 3 registros SRV para etcd

### DHCP

Reservas automáticas para:
- Masters (todos)
- Load Balancer (3-node apenas)
- Bootstrap (3-node apenas, temporário)
- Workers (quando adicionados posteriormente)

## Acessando o Cluster do Host

O gateway da rede libvirt atua como servidor DNS. Para resolver nomes do cluster a partir do host:

```bash
# Obter o gateway/DNS da rede (exibido durante o playbook)
virsh net-dumpxml <network-name> | grep "ip address=" | sed -n "s/.*address='\([^']*\)'.*/\1/p"

# Para rede dedicada: <clustername>-net
# Para rede compartilhada: valor de kvmnetwork

# Adicionar ao /etc/resolv.conf
echo "nameserver <gateway-ip>" | sudo tee -a /etc/resolv.conf
```

**Exemplo:**
```bash
# Rede dedicada
$ virsh net-dumpxml my-cluster-net | grep "ip address=" | sed -n "s/.*address='\([^']*\)'.*/\1/p"
192.168.124.1

$ echo "nameserver 192.168.124.1" | sudo tee -a /etc/resolv.conf
```

## Ciclo de Vida da Rede

### Durante Criação do Cluster

**Rede Dedicada:**
1. Cria rede `<clustername>-net`
2. Configura DNS com entradas do cluster
3. Configura DHCP com reservas
4. Inicia rede e define autostart
5. VMs conectam à nova rede

**Rede Compartilhada:**
1. Faz backup da configuração XML da rede existente
2. Para a rede existente
3. Reconfigura com DNS do cluster
4. Reinicia a rede
5. VMs conectam à rede reconfigurada

### Durante Destruição do Cluster

**Rede Dedicada:**
1. Para todas as VMs do cluster
2. Para a rede `<clustername>-net`
3. Remove definição da rede
4. Remove arquivo XML da rede

**Rede Compartilhada:**
1. Para todas as VMs do cluster
2. Para a rede compartilhada
3. Restaura configuração original do backup
4. Reinicia a rede
5. Remove arquivo de backup

## Vantagens

### Rede Dedicada
✅ **Isolamento Total**: Cada cluster tem sua própria rede  
✅ **Cleanup Automático**: Rede removida com o cluster  
✅ **Múltiplos Clusters**: Vários clusters simultaneamente sem conflitos  
✅ **Seguro**: Não modifica redes existentes  
✅ **Simples**: Configuração padrão funciona imediatamente

### Rede Compartilhada
✅ **Integração**: Usa rede existente com outras VMs  
✅ **Reversível**: Restauração automática da configuração original  
✅ **Flexível**: Controle total sobre a rede usada

## Compatibilidade

- ✅ OpenShift 4.x (SNO e multi-node)
- ✅ RHCOS (todas versões suportadas)
- ✅ KVM/libvirt com suporte a dnsmasq options
- ✅ Múltiplos clusters simultâneos (rede dedicada)
- ✅ NetworkManager não é mais necessário

## Estrutura de Arquivos

```
/labs/<clustername>/
├── <network-name>-config.xml    # Configuração XML da rede
├── <kvmnetwork>-original.xml    # Backup (só rede compartilhada)
├── install-config.yaml
├── *.ign
└── ...
```

## Troubleshooting

### DNS não resolve do host

**Sintoma**: `nslookup api.<clustername>.<domain>` falha

**Solução**:
```bash
# Verificar se o gateway está em /etc/resolv.conf
cat /etc/resolv.conf

# Obter gateway da rede
virsh net-dumpxml <network-name> | grep "ip address="

# Adicionar se não estiver presente
echo "nameserver <gateway-ip>" | sudo tee -a /etc/resolv.conf
```

### Rede não inicia

**Sintoma**: `virsh net-start <network-name>` falha

**Solução**:
```bash
# Verificar logs
journalctl -xe | grep libvirt

# Verificar conflito de endereços
ip addr show

# Verificar se a bridge já existe
brctl show

# Remover definição e recriar
virsh net-undefine <network-name>
virsh net-define /labs/<clustername>/<network-name>-config.xml
virsh net-start <network-name>
```

### VMs não obtêm IP

**Sintoma**: VMs ficam sem endereço IP

**Solução**:
```bash
# Verificar se DHCP está ativo na rede
virsh net-dumpxml <network-name> | grep -A 5 dhcp

# Verificar se a VM está conectada à rede correta
virsh domiflist <vm-name>

# Reiniciar a rede
virsh net-destroy <network-name>
virsh net-start <network-name>
```

### Verificar Configuração

```bash
# Ver configuração completa da rede
virsh net-dumpxml <network-name>

# Ver status
virsh net-info <network-name>

# Listar todas as redes
virsh net-list --all

# Ver IPs atribuídos
virsh net-dhcp-leases <network-name>
```

## Migração de Clusters Existentes

Se você tem clusters criados com a versão antiga (dnsmasq do NetworkManager), recomendamos:

1. **Backup** da configuração atual
2. **Destroy** o cluster antigo
3. **Atualizar** para nova versão da automação
4. **Recriar** o cluster (usa rede dedicada automaticamente)

## Exemplos

### Cluster SNO com Rede Dedicada

```yaml
clustername: 'sno-prod'
basedomain: 'company.com'
sno: 'true'
ocp_cluster_use_dedicated_network: true
```

**Rede Criada**: `sno-prod-net`  
**DNS**: `api.sno-prod.company.com` → master-0 IP  
**Destruição**: Rede `sno-prod-net` removida automaticamente

### 3-node com Rede Compartilhada

```yaml
clustername: 'prod-cluster'
basedomain: 'company.com'
sno: 'false'
ocp_cluster_use_dedicated_network: false
kvmnetwork: 'production'
```

**Rede Usada**: `production` (existente)  
**Backup**: Criado em `/labs/prod-cluster/production-original.xml`  
**Destruição**: Rede `production` restaurada do backup

## Referências

- [Libvirt Network XML Format](https://libvirt.org/formatnetwork.html)
- [Dnsmasq Options](https://libvirt.org/formatnetwork.html#dnsmasq-options)
- [OpenShift UPI Requirements](https://docs.openshift.com/container-platform/latest/installing/installing_bare_metal/installing-bare-metal.html)
