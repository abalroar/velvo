# PhilipsTV Menubar

Controle remoto na barra de menus do macOS para a Philips 55PUG7406/78 (Android TV). Inspirado no [LGwebOS-menubar](https://github.com/gabrielgreco1/LGwebOS-menubar), que faz o mesmo para TVs LG.

Funciona com qualquer TV Android TV / Google TV: usa o mesmo protocolo do app Google TV do celular (Android TV Remote v2, portas 6466 e 6467). Nada passa pela nuvem.

## O que faz

- **Início:** app em primeiro plano na TV, volume (slider e +/−, mudo), favoritos com um clique, HDMI 1–4 e lista de fontes.
- **Controle:** direcional, OK, voltar, início, configurações da TV, mídia (play/pausa, avançar, retroceder), legendas, canais, botão do Google Assistente.
- **Teclado do Mac:** com o painel aberto, setas navegam, ↩ confirma, ⌫ volta, espaço pausa, H vai ao início, M silencia, + e − mudam o volume.
- **Digitar na TV:** envia texto para o campo de busca aberto na TV (evita o teclado virtual).
- **Apps:** 16 apps prontos (Netflix, YouTube, Prime Video, Disney+, HBO Max, Globoplay, Apple TV, Spotify…). Abrir qualquer outro app na TV e tocar em **Salvar app** captura o pacote dele.
- **Ligar/desligar:** desliga pela rede; para ligar, use Wake-on-LAN (informe o MAC e ative “Ligar com Wi-Fi/LAN” na TV).

## Instalar

**Opção 1 — baixar pronto.** Em *Actions › philips-tv-menubar*, abra a execução mais recente e baixe o artefato `PhilipsTV-Menubar` (zip). Descompacte, mova para Aplicativos e, na primeira vez, clique com o botão direito › **Abrir** (o app não é notarizado pela Apple).

**Opção 2 — compilar.** Requer macOS 14+ e Xcode Command Line Tools (`xcode-select --install`).

```sh
bash scripts/build.sh
open "dist/PhilipsTV Menubar.app"
```

## Parear com a TV

1. Ligue a TV e deixe o Mac na mesma rede.
2. Clique no ícone de TV na barra de menus › **Ajustes** › **Procurar**. Se a TV não aparecer, digite o IP (na TV: Configurações › Rede e Internet › sua rede).
3. **Salvar**, depois **Parear**. Um código de 6 caracteres aparece na TV; digite-o e confirme.

Se o macOS pedir acesso à rede local, permita. Na primeira conexão o Keychain pode pedir permissão para usar a chave “PhilipsTV Menubar client key”: escolha **Permitir sempre**. Depois de recompilar o app, o pedido pode voltar.

## Limites conhecidos

- **Não testado na 55PUG7406/78 real.** O protocolo foi validado contra um simulador de TV e contra a biblioteca de referência `androidtvremote2` (usada pelo Home Assistant). Se algo falhar na sua TV, rode o diagnóstico abaixo.
- **HDMI direto:** as teclas HDMI 1–4 são padrão Android, mas algumas TVs as ignoram. Nesse caso use **Lista de fontes da TV**.
- **Volume:** o protocolo não define volume absoluto; o slider envia +/− até chegar ao valor.
- **Lista de apps instalados:** o protocolo não informa; por isso o catálogo é fixo mais os apps que você salvar. Abrir um app não instalado leva à página dele na Play Store.
- **Ligar a TV:** só por Wake-on-LAN ou se a TV mantiver a rede ativa em espera.

## Diagnóstico

```sh
BIN="dist/PhilipsTV Menubar.app/Contents/MacOS/PhilipsTVMenubar"
"$BIN" --self-check                                   # testes offline
"$BIN" --status --host 192.168.0.50                    # o que a TV informa (app, volume, energia)
"$BIN" --send-key HOME --host 192.168.0.50             # envia uma tecla
"$BIN" --pair --host 192.168.0.50                      # pareamento pelo terminal
"$BIN" --help
```

Teste completo sem TV (simulador em `scripts/mock_tv.py`):

```sh
bash scripts/build.sh && bash scripts/integration-test.sh
```

## Privacidade

Sem contas, analytics ou servidores. A chave privada do Mac fica no Keychain; o certificado público e as preferências ficam em `~/Library/Application Support/PhilipsTVMenubar/` e nas preferências do macOS (`br.local.PhilipsTVMenubar`). O certificado da TV é fixado no primeiro uso; se mudar, o app pede novo pareamento.

## Créditos

Protocolo baseado em [androidtvremote2](https://github.com/tronikos/androidtvremote2) (Apache 2.0) e na documentação de [Aymkdn](https://github.com/Aymkdn/assistant-freebox-cloud/wiki/Google-TV-(aka-Android-TV)-Remote-Control-(v2)). Layout inspirado em [LGwebOS-menubar](https://github.com/gabrielgreco1/LGwebOS-menubar) (MIT). Nenhum código foi copiado desses projetos; os bytes esperados nos testes vêm das classes protobuf do androidtvremote2.
