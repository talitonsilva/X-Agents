# X-Agents Agent Release Instructions

Este arquivo define o fluxo obrigatorio para qualquer agente que fizer alteracoes no projeto.

## Regra obrigatoria

Toda alteracao no `X-Agents` deve resultar em dois destinos publicados:

1. `source` sem build no repositorio privado
2. `build` publica com frontend e backend ofuscados no repositorio publico

Nao finalize uma tarefa de alteracao sem cumprir os dois pontos acima, salvo se o usuario pedir explicitamente para parar antes.

## Repositorios oficiais

- Repositorio privado source: `https://github.com/talitonsilva/x-agents-rep`
- Repositorio publico buildado: `https://github.com/talitonsilva/X-Agents`

## Fluxo obrigatorio apos qualquer alteracao

1. Validar os arquivos alterados localmente.
2. Salvar o `source` no repositorio privado `x-agents-rep`.
3. Gerar a release oficial com ofuscacao de frontend e backend.
4. Publicar a versao buildada/ofuscada no repositorio publico `X-Agents`.
5. Confirmar para o usuario qual commit e qual versao foram publicados.

## Publicacao do source privado

O repositorio em `/root/xagents` e a arvore source.

Depois de alterar o projeto:

```bash
cd /root/xagents
git status
git add -A
git commit -m "Mensagem objetiva da alteracao"
git push origin main
```

## Build oficial publica

Gerar sempre a build oficial a partir da source:

```bash
cd /root/xagents
bash scripts/build-release.sh
```

Por padrao, este projeto ja gera release com:

- frontend ofuscado
- backend ofuscado

Conferir a versao atual:

```bash
cd /root/xagents
cat VERSION
```

Arquivos esperados apos a build:

- `release/dist/<VERSAO>/xagents-<VERSAO>.tar.gz`
- `release/dist/<VERSAO>/manifest.json`
- `release/dist/<VERSAO>/install.sh`

## Publicacao no repositorio publico X-Agents

O repositorio publico deve refletir a versao buildada/ofuscada, nao a source crua.

Fluxo esperado:

1. Extrair a tarball da release gerada.
2. Sincronizar o conteudo extraido para um clone limpo do repo publico `X-Agents`.
3. Fazer commit no repo publico.
4. Fazer push para `main`.

Exemplo resumido:

```bash
VERSION="$(cat /root/xagents/VERSION)"
PUB_DIR="$(mktemp -d)"
STAGE_DIR="$(mktemp -d)"

git clone https://github.com/talitonsilva/X-Agents.git "$PUB_DIR"
tar -xzf "/root/xagents/release/dist/$VERSION/xagents-$VERSION.tar.gz" -C "$STAGE_DIR"
rsync -a --delete --exclude '.git' "$STAGE_DIR"/ "$PUB_DIR"/

cd "$PUB_DIR"
git checkout -B main origin/main || git checkout -B main
git add -A
git commit -m "Publish public obfuscated release $VERSION"
git push origin main
```

## Regra de conteudo do repo publico

No repo publico `X-Agents` deve subir a versao buildada/ofuscada da release.

Nao subir a source inteira sem build no repo publico.

## Confirmacao minima ao usuario

Ao finalizar, informar:

- commit publicado no repo privado source
- versao buildada publicada
- commit publicado no repo publico
- se houve release/tag publicada tambem

## Se algo falhar

- Se o push do privado falhar, nao diga que a tarefa terminou.
- Se a build oficial falhar, nao improvise release manual sem deixar isso explicito.
- Se o push do publico falhar, nao diga que a versao publica foi publicada.
- Se faltar credencial, token ou rede, informar exatamente o bloqueio.
