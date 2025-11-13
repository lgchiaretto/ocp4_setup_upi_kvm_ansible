# Configuração DNS via libvirt Network

## Visão Geral

Esta automação agora suporta duas abordagens para configuração DNS:

### 1. **Método Novo (Recomendado)**: DNS integrado na rede libvirt
- DNS configurado diretamente no XML da rede libvirt
- Semelhante à abordagem do Terraform (issue #12)
- Não requer modificações no NetworkManager do host
- Mais isolado e reversível
- Configuração totalmente contida na rede virtual

### 2. **Método Legado**: dnsmasq via NetworkManager
- DNS configurado através do dnsmasq do NetworkManager no host
- Método original da automação
- Requer modificações no sistema do host

## Como Ativar o Novo Método

No arquivo `ansible-vars-kvm.yaml`, configure:

```yaml
ocp_cluster_use_libvirt_network_dns: true
```

## O que o Novo Método Faz

Quando ativado (`ocp_cluster_use_libvirt_network_dns: true`):

1. **Gera XML da rede libvirt** com configuração DNS embutida incluindo:
   - Entradas DNS para masters (master-0, master-1, master-2)
   - Entradas DNS para etcd (etcd-0, etcd-1, etcd-2)
   - Entradas DNS para API (api, api-int)
   - Entradas DNS para load balancer
   - Entradas DNS para bootstrap
   - Registros SRV para serviço etcd
   - Wildcard DNS para `*.apps.<cluster>.<domain>`
   - Reservas DHCP para todos os nós

2. **Atualiza a rede kvmnetwork** com a nova configuração DNS

3. **Não modifica** o NetworkManager ou dnsmasq do host

## Diferenças entre SNO e 3-node

### SNO (Single Node OpenShift)
- 1 entrada etcd (etcd-0)
- 1 registro SRV para etcd
- DNS aponta api/api-int para o master-0
- Wildcard apps aponta para master-0

### 3-node
- 3 entradas etcd (etcd-0, etcd-1, etcd-2)
- 3 registros SRV para etcd
- DNS aponta api/api-int para load balancer
- Wildcard apps aponta para load balancer
- Inclui entrada DNS para bootstrap (temporária)

## Acessando o Cluster do Host

Para resolver DNS do cluster a partir do host, adicione o gateway da rede libvirt ao `/etc/resolv.conf`:

```bash
# Obter o gateway da rede (será exibido durante a execução do playbook)
virsh net-dumpxml <kvmnetwork> | grep "ip address=" | sed -n "s/.*address='\([^']*\)'.*/\1/p"

# Adicionar ao /etc/resolv.conf
echo "nameserver <gateway-ip>" | sudo tee -a /etc/resolv.conf
```

Exemplo:
```bash
nameserver 192.168.122.1
```

## Compatibilidade

- ✅ Funciona com SNO e 3-node
- ✅ Suporta múltiplos clusters (cada um com seu próprio namespace DNS)
- ✅ Compatível com OpenShift 4.x
- ✅ Não interfere com outras redes libvirt

## Vantagens do Novo Método

1. **Isolamento**: Não modifica configurações do sistema host
2. **Reversível**: Destruir o cluster remove toda a configuração DNS
3. **Múltiplos clusters**: Cada cluster tem sua própria configuração DNS independente
4. **Simplicidade**: Menos componentes envolvidos (sem dnsmasq do NetworkManager)
5. **Padrão Terraform**: Segue o mesmo padrão do provider Terraform libvirt

## Limitações

- Workers precisam ser adicionados manualmente ao DNS (use `add-new-nodes.yaml`)
- Requer libvirt com suporte a opções dnsmasq customizadas
- A rede kvmnetwork será reconfigurada (backup automático criado)

## Troubleshooting

### DNS não está resolvendo do host

Verifique se o gateway da rede está em `/etc/resolv.conf`:
```bash
cat /etc/resolv.conf | grep $(virsh net-dumpxml <kvmnetwork> | grep "ip address=" | sed -n "s/.*address='\([^']*\)'.*/\1/p")
```

### Verificar configuração DNS da rede

```bash
virsh net-dumpxml <kvmnetwork>
```

### Testar resolução DNS

```bash
# Do host (se configurado o nameserver)
nslookup api.<clustername>.<basedomain>

# De dentro de um nó do cluster
oc debug node/<node-name>
chroot /host
nslookup api.<clustername>.<basedomain>
```

## Restaurar Método Legado

Para voltar ao método antigo, configure:

```yaml
ocp_cluster_use_libvirt_network_dns: false
```

E execute o playbook normalmente. A configuração via NetworkManager será aplicada.
