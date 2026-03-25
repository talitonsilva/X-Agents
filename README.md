# X-Agents

Painel standalone focado em gerenciamento de agentes de IA.

## Instalacao

```bash
cd /root/xagents
bash scripts/install.sh
```

Padrao:

- base: `/www/server/xagents`
- porta: `8890`
- servico: `xagents.service`

## Update

```bash
cd /root/xagents
bash scripts/update.sh
```

## Release

```bash
cd /root/xagents
bash scripts/build-release.sh
```

## Fluxo Para Agentes

Instrucoes obrigatorias para agentes que alterarem o projeto:

- [AGENT_RELEASE_INSTRUCTIONS.md](/root/xagents/AGENT_RELEASE_INSTRUCTIONS.md)
