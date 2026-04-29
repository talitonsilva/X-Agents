# X-Agents

Distribuicao publica do X-Agents.

Este repositorio publica somente os artefatos finais da release ofuscada:

- `xagents-<versao>.tar.gz`
- `install.sh`
- `manifest.json`

## Instalacao

Em uma VPS limpa:

```bash
curl -fsSL https://raw.githubusercontent.com/talitonsilva/X-Agents/main/install.sh | bash
```

Padrao:

- base: `/www/server/xagents`
- porta: `8890`
- servico: `xagents.service`

## Atualizacao

O runtime instalado consulta o `manifest.json` deste repositorio para baixar novas versoes publicas.


