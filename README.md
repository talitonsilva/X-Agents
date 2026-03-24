# X-AGENTS by MasterDev Taliton Silva

Painel para operar agentes com Codex, contas de IA, chats, tarefas, integrações externas e automações em um único workspace web.

## Instalacao

Via GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/talitonsilva/X-Agents/main/install.sh | bash
```

## O que esta incluso

- `install.sh`
- `manifest.json`
- `xagents-2026.03.24-r17.tar.gz`

## Funcionalidades

- Workspace web para operar agentes em tempo real
- Criação e gerenciamento de agentes
- Contas Codex com autenticação e rate limits
- Chats persistentes por tarefa e sessão
- Composer com texto, imagem, audio e arquivo
- Tasks com fila, re-run, cancelamento e histórico
- Skills para ampliar capacidades dos agentes
- Perfis SSH para execução remota
- Integrações custom API
- Integrações WhatsApp, Telegram e Discord
- Integração Meta Ads
- Auto update por timer do systemd
- Update manual pelo cabeçalho do painel
- Modal de update com progresso e log
- Instalador automático com Node 22+ e Codex CLI
- Compatibilidade com atualização via GitHub raw

## Requisitos

- Ubuntu ou Debian com acesso root
- Internet liberada para baixar dependências
- Porta `8890/tcp` disponível

## Pos-instalacao

Validar serviço:

```bash
systemctl status xagents.service --no-pager -l
```

Validar healthcheck:

```bash
curl -fsS http://127.0.0.1:8890/healthz
```

## Update manual

Reexecutar o instalador:

```bash
curl -fsSL https://raw.githubusercontent.com/talitonsilva/X-Agents/main/install.sh | bash
```

Ou usar o botão de update no cabeçalho do painel quando houver nova versão disponível.
