# Spec: Convert — conversão de arquivos nativa via Finder (v1: Imagens)

Status: `ready-for-agent` (sem issue tracker configurado neste repositório — spec mantida aqui até um for adicionado)

## Context

O repositório `Converter` está em estado inicial: um projeto Xcode padrão (`Converter.xcodeproj`, alvo único `Converter`, SwiftUI, macOS deployment target 26.5, Xcode 26.6 / Swift 6.3, sem remote git, sem dependências) contendo apenas o template "Hello, world!" gerado pelo Xcode. Não há ADRs, glossário de domínio ou issue tracker configurados ainda — este documento estabelece a primeira convenção do projeto.

O usuário quer um app nativo de macOS chamado **Convert** cujo ponto de entrada principal é o menu de contexto do Finder: clicar com o botão direito em um arquivo, escolher **Convert → <formato>**, ajustar opções numa janela compacta e obter o arquivo convertido ao lado do original — sem parecer um app "genérico", e sem nunca enviar arquivos para fora do Mac.

Antes de desenhar a arquitetura, as APIs da Apple foram validadas diretamente nesta máquina (macOS 26.5, Xcode 26.6), em vez de assumidas a partir de documentação genérica. As descobertas relevantes:

- **ImageIO** (`CGImageDestinationCopyTypeIdentifiers()`, verificado ao vivo nesta máquina) escreve `public.png`, `public.jpeg`, `public.tiff`, `public.heic`, `com.adobe.pdf`, `com.compuserve.gif`, `com.microsoft.bmp`, entre outros — mas **não** tem `webp`/`org.webmproject.webp` na lista de destinos, só na de leitura (`CGImageSourceCopyTypeIdentifiers()`). Ou seja: ImageIO **lê** WebP nativamente, mas **não consegue codificar** WebP. PNG→WebP (item 6 da v1) exige uma peça extra.
- HEIC tem escrita nativa via ImageIO (`public.heic` presente nos destinos).
- SVG não aparece em nenhuma das duas listas — não é um formato ImageIO. É tratado à parte, via renderização vetorial do AppKit (`NSImage` sabe desenhar SVG desde macOS 10.15) direto para o tamanho de saída desejado.
- Para o menu de contexto do Finder, a API atual e documentada pela Apple continua sendo o framework **FinderSync** (`FIFinderSync`, método `menu(for:)` com `FIMenuKind.contextualMenuForItems`) — as páginas de referência (`developer.apple.com/documentation/findersync/...`) seguem publicadas e indexadas, sem aviso de depreciação. A única instabilidade real encontrada foi cosmética: a Apple removeu temporariamente a UI de gerenciamento de extensões do Finder em macOS 15.0/15.1 (Sequoia) e a devolveu em 15.2 sob "Login Items & Extensions"; o framework em si nunca saiu de uso (é o que apps como Keka e BetterZip usam hoje).

## Problem Statement

Converter um arquivo de imagem no Mac hoje significa abrir um app separado (Preview, um site online, ou uma ferramenta de linha de comando), importar o arquivo, escolher opções numa interface que não tem nada a ver com o resto do sistema, exportar, e mover o resultado manualmente para a pasta original. Isso quebra o fluxo de quem só quer "essa foto, em WebP, agora, do lado da original" — e para gente com menos afinidade técnica, sequer é óbvio por onde começar. O macOS já tem esse padrão resolvido para outras tarefas (Quick Look, Rotate, Markup) via o menu de contexto do Finder; conversão de arquivo não tem um equivalente nativo.

## Solution

Um app leve (**Convert**) que se registra como Finder Sync Extension e injeta um item **Convert** no menu de contexto do Finder. O submenu é montado dinamicamente a partir do tipo real do arquivo selecionado (ou da interseção de tipos, se houver mais de um selecionado), mostrando só os formatos de saída que fazem sentido. Escolher um formato abre uma janela SwiftUI compacta — pré-visualização, redimensionamento (com presets e valores customizados, aspect ratio travável), e qualidade quando aplicável — e ao confirmar a conversão roda localmente, em background, salvando o resultado na mesma pasta do original sem nunca sobrescrevê-lo silenciosamente. O mesmo motor de conversão atende tanto o fluxo do Finder quanto arrastar arquivos direto para a janela do app (útil para lote), preparando o terreno para os próximos tipos de mídia (vídeo, áudio, PDF, documentos) sem precisar reescrever nada do que existe.

## User Stories

1. Como usuário do Finder, quero clicar com o botão direito em uma imagem e ver a opção **Convert**, para não precisar abrir outro aplicativo.
2. Como usuário, ao passar o mouse sobre **Convert**, quero ver um submenu só com os formatos de saída relevantes para aquele arquivo, para não me perder em opções que não fazem sentido.
3. Como usuário que clicou com o botão direito em um `.png`, quero ver JPEG, WebP, HEIC, TIFF e PDF como opções, e nada além disso.
4. Como usuário que clicou com o botão direito em um `.jpg`/`.jpeg`, quero ver PNG, WebP, HEIC, TIFF e PDF como opções.
5. Como usuário que clicou com o botão direito em um `.heic`/`.heif`, quero ver JPEG, PNG, WebP, TIFF e PDF como opções.
6. Como usuário que clicou com o botão direito em um `.tiff`, quero ver JPEG, PNG, WebP, HEIC e PDF como opções.
7. Como usuário que clicou com o botão direito em um `.gif`, quero ver JPEG, PNG, WebP, TIFF e PDF como opções, sabendo que a conversão usa o primeiro frame (GIF animado não é preservado nesta versão).
8. Como usuário que clicou com o botão direito em um `.bmp`, quero ver JPEG, PNG, WebP, HEIC, TIFF e PDF como opções.
9. Como usuário que clicou com o botão direito em um `.webp`, quero ver JPEG, PNG, HEIC, TIFF e PDF como opções (sem WebP→WebP).
10. Como usuário que clicou com o botão direito em um `.svg`, quero ver PNG, JPEG, WebP, HEIC, TIFF e PDF como opções, sabendo que o SVG é rasterizado no tamanho de saída escolhido.
11. Como usuário, ao clicar com o botão direito em um arquivo de tipo não suportado (ex: `.txt`), não quero ver a opção Convert (ou quero vê-la desabilitada), para não achar que algo quebrou.
12. Como usuário que selecionou vários arquivos do mesmo tipo e clicou em Convert → WebP, quero que todos sejam enfileirados para conversão em lote com aquele formato de destino.
13. Como usuário que selecionou arquivos de tipos diferentes, quero ver apenas os formatos de saída compatíveis com todos os arquivos selecionados (interseção), para não escolher um formato inválido para parte do lote.
14. Como usuário, ao escolher um formato no submenu, quero que uma janela pequena e nativa abra imediatamente, para configurar a conversão sem fricção.
15. Como usuário, quero ver na janela o nome do arquivo, uma miniatura da imagem, as dimensões originais e o tamanho em disco, para confirmar que estou convertendo o arquivo certo.
16. Como usuário, quero escolher entre presets de tamanho (Original, 128×128, 256×256, 512×512, 1024×1024) para redimensionar sem digitar nada.
17. Como usuário, quero uma opção "Custom" que libera os campos de largura e altura para digitação livre.
18. Como usuário, com "Maintain aspect ratio" ativado, quero que alterar a largura recalcule a altura automaticamente (e vice-versa), para não distorcer a imagem sem querer.
19. Como usuário, com "Maintain aspect ratio" desativado, quero definir largura e altura de forma totalmente independente.
20. Como usuário, quero ver as novas dimensões estimadas refletidas na prévia antes de confirmar, para saber exatamente o que vou obter.
21. Como usuário convertendo para um formato com compressão com perdas (JPEG, WebP, HEIC), quero um slider de qualidade de 1 a 100%, com um valor padrão sensato pré-selecionado.
22. Como usuário convertendo para um formato sem conceito de qualidade (PNG, TIFF, PDF), não quero ver o controle de qualidade — ele deve ficar oculto, não desabilitado.
23. Como usuário, quero que o arquivo convertido receba o mesmo nome-base do original com a nova extensão (ex: `foto.png` → `foto.webp`).
24. Como usuário, se já existir um arquivo com o nome de destino, quero que o Convert gere automaticamente `foto (1).webp`, `foto (2).webp` etc. (igual ao comportamento nativo de cópia do Finder), em vez de sobrescrever ou travar.
25. Como usuário, nunca quero que o arquivo original seja apagado ou sobrescrito sem uma ação explícita minha — o comportamento padrão sempre preserva o original.
26. Como usuário, quero poder abrir o app Convert diretamente (fora do Finder) e ver uma área "Drop files here", para converter arquivos sem passar pelo menu de contexto.
27. Como usuário, quero poder arrastar um ou vários arquivos para essa área e, em seguida, escolher o formato de destino e as opções antes de converter.
28. Como usuário convertendo vários arquivos de uma vez (via Finder ou drag-and-drop), quero ver uma barra de progresso com contagem ("7 of 10 files"), para acompanhar o andamento.
29. Como usuário, quero poder cancelar uma conversão em andamento (de um arquivo único ou de um lote), e ver o processo parar de forma limpa, sem arquivos parciais/corrompidos deixados para trás.
30. Como usuário, quero que a interface nunca trave enquanto uma conversão roda, mesmo com arquivos grandes.
31. Como usuário, se uma conversão falhar, quero uma mensagem em linguagem simples ("Couldn't convert this file. The selected format isn't supported for this image.") em vez de um erro técnico, com uma ação clara como "Try another format".
32. Como usuário avançado ou desenvolvedor, quero que os detalhes técnicos do erro fiquem registrados em log local, para diagnóstico, sem me forçar a vê-los na interface.
33. Como usuário, quero que o app funcione igualmente bem em Dark Mode e Light Mode, seguindo a aparência do sistema.
34. Como usuário que navega por teclado, quero conseguir preencher e confirmar a janela de conversão (Tab entre campos, Enter para confirmar, Esc para cancelar) sem precisar do mouse.
35. Como usuário de tecnologia assistiva (VoiceOver), quero que os controles da janela de conversão (sliders, campos, checkboxes, botões) tenham rótulos compreensíveis.
36. Como usuário, quero que a janela de conversão seja compacta por padrão mas redimensionável, para casos em que eu precise de mais espaço (ex: nomes de arquivo longos, telas menores).
37. Como usuário preocupado com privacidade, quero ter certeza de que nenhum arquivo meu é enviado para qualquer servidor — toda conversão deve acontecer localmente.
38. Como usuário, não quero que o app colete analytics, telemetria ou dados de uso de qualquer tipo.
39. Como usuário, na primeira vez que uso o recurso, quero ser orientado sobre como habilitar a extensão do Finder nas Configurações do Sistema, caso ela ainda não esteja ativa.
40. Como usuário, quero uma tela de Settings simples onde eu possa (no futuro) escolher onde salvar os arquivos convertidos (mesma pasta / perguntar sempre / pasta customizada), se devo ser avisado antes de sobrescrever, se o original deve sempre ser mantido, e qual a qualidade padrão — mesmo que só "mesma pasta" e "manter original sempre" estejam realmente funcionais nesta versão.
41. Como usuário técnico que futuramente vai converter vídeo, áudio, PDF ou documentos, quero que a arquitetura do Convert já preveja esses tipos de conversor sem precisar reescrever a base (detecção de tipo, motor de conversão, integração com Finder, UI).
42. Como usuário, quero que uma eventual ação futura "Convert → Resize..." (redimensionar sem converter o formato) seja viável de adicionar sem grandes mudanças estruturais, mesmo que não exista ainda nesta versão.

## Implementation Decisions

### Arquitetura e módulos

O projeto Xcode passa a ter três alvos (targets), todos compartilhando um módulo comum:

- **ConvertCore** — Swift Package local (dependência de código-fonte, sem publicação externa), sem UI e sem AppKit/SwiftUI, importado tanto pelo app quanto pela extensão. Contém: `FileTypeDetector`, a tabela de formatos de entrada→saída suportados, os modelos de domínio (`ConversionJob`, `ConversionResult`, `ResizeSpec`, `OutputFormat`, `ConversionError`), `ConversionEngine`, `ImageConverter`, `ResizeEngine`, `OutputPathResolver`, `BatchProcessor`, e os protocolos-esqueleto `VideoConverter`/`AudioConverter`/`PDFConverter`/`DocumentConverter` (não implementados nesta versão, só a interface e um registro no `ConversionEngine` preparado para plugá-los). Este é o módulo que recebe teste automatizado.
- **Converter** (app principal, SwiftUI) — depende de `ConvertCore`. Contém a `UI` (janela principal "Drop files here", janela compacta de configuração de conversão, tela de Settings), o handler do custom URL scheme que recebe jobs vindos da extensão, e a camada `Settings` (persistência via `UserDefaults`/`@AppStorage` num App Group compartilhado com a extensão).
- **ConvertFinderExtension** (Finder Sync Extension, `FIFinderSync`) — depende de `ConvertCore` só para consultar `FileTypeDetector` (que formatos oferecer no submenu). É deliberadamente burra: monta o `NSMenu` (`Convert` → itens de formato) e, na ação de clique, escreve um `ConversionJob` pendente no container compartilhado do App Group e abre o app principal via um custom URL scheme (`convert://open-job?id=<uuid>`) passando `NSWorkspace.shared.open(_:)`. Nenhum trabalho de decodificação/conversão roda no processo da extensão.

`FinderIntegration` (citado na estrutura de pastas pedida pelo usuário) corresponde ao alvo `ConvertFinderExtension` mais a fatia de `ConvertCore` que ele consome — não é um módulo Swift separado, é o agrupamento lógico desse alvo no projeto Xcode.

### Integração com o Finder

Mecanismo escolhido: **Finder Sync Extension** (`FIFinderSync`, framework `FinderSync`), usando `menu(for kind: FIMenuKind) -> NSMenu?` com `kind == .contextualMenuForItems`. É o único mecanismo atual da Apple que permite construir um item de menu real com submenu customizado ("Convert" → lista de formatos), com controle total do conteúdo por item selecionado — diferente de Quick Actions/Serviços (Automator/Shortcuts), que aparecem afundados dentro de um submenu genérico "Quick Actions"/"Services" e não dão o mesmo controle dinâmico por tipo de arquivo. Motivo da escolha, documentado brevemente: é a API oficial, atualmente publicada e sem aviso de depreciação na documentação da Apple, e é o padrão usado por utilitários reais de terceiros para exatamente esse tipo de item de menu.

`FIFinderSyncController.default().directoryURLs` é configurado para observar a pasta pessoal do usuário (`~`) e cada volume montado (atualizado quando volumes são montados/desmontados), para que "Convert" apareça em praticamente qualquer lugar — igual à sensação de recurso nativo do sistema, e o padrão que apps como Keka/BetterZip usam para esse mesmo propósito. Esse escopo não fica hardcoded: fica atrás de uma função só (ex: `watchedDirectoryURLs()`), preparado para virar configurável nas Settings numa versão futura sem tocar no resto da extensão.

Consideração operacional a documentar para o usuário: em algumas versões específicas do Sequoia (15.0–15.1) a Apple removeu temporariamente a UI de "Extensions" das Configurações do Sistema; isso foi corrigido em 15.2 e não deve afetar o macOS 26.5 (target deste projeto), mas o app deve detectar se a extensão está habilitada e, se não estiver, mostrar instruções (não é possível habilitá-la programaticamente).

### Handoff Extension → App

Como a extensão do Finder roda num processo separado, leve, e não é o lugar certo para abrir uma janela SwiftUI completa nem para rodar a conversão pesada, o fluxo é:

1. Extensão monta um `ConversionJob` (lista de URLs de origem, formato de destino, valores padrão de resize/quality vindos das Settings) e grava como JSON num container de App Group compartilhado (`group.<bundle-id>`), identificado por um UUID.
2. Extensão chama `NSWorkspace.shared.open(URL)` com o custom scheme (`convert://open-job?id=<uuid>`) para abrir/focar o app principal.
3. App principal, no handler do URL scheme, lê o job do container compartilhado, apaga o arquivo temporário do job, e abre a janela de configuração de conversão já pré-preenchida com aqueles arquivos e aquele formato de destino.

Esse mesmo modelo `ConversionJob` é reaproveitado para o fluxo de drag-and-drop dentro do app (a única diferença é que, nesse caminho, o formato de destino é escolhido dentro do próprio app antes de abrir a mesma janela de configuração, já que não veio pré-selecionado de um clique no Finder).

### Matriz de formatos e APIs por formato

| Entrada | Saídas oferecidas | API de decodificação |
|---|---|---|
| PNG | JPEG, WebP, HEIC, TIFF, PDF | ImageIO |
| JPEG/JPG | PNG, WebP, HEIC, TIFF, PDF | ImageIO |
| HEIC/HEIF | JPEG, PNG, WebP, TIFF, PDF | ImageIO |
| TIFF | JPEG, PNG, WebP, HEIC, PDF | ImageIO |
| GIF (frame único) | JPEG, PNG, WebP, TIFF, PDF | ImageIO |
| BMP | JPEG, PNG, WebP, HEIC, TIFF, PDF | ImageIO |
| WebP | JPEG, PNG, HEIC, TIFF, PDF | ImageIO (leitura nativa) |
| SVG | PNG, JPEG, WebP, HEIC, TIFF, PDF | AppKit (`NSImage`, rasterização vetorial no tamanho de saída) |

Codificação de saída por formato:
- **JPEG, PNG, TIFF, HEIC** — `CGImageDestination` (ImageIO), nativamente suportado (confirmado neste Mac).
- **PDF** — PDFKit (`PDFDocument` + `PDFPage(image:)`), por ser a API que o próprio usuário pediu para PDF e por ser mais direta que montar um destino ImageIO manualmente para um único frame.
- **WebP** — ImageIO não codifica WebP (confirmado empiricamente nesta máquina). Decisão: adicionar **libwebp** (biblioteca oficial do Google, licença BSD) como dependência via Swift Package Manager, usada exclusivamente no encoder de WebP (a leitura de `.webp` de entrada continua 100% ImageIO). Evita embutir o FFmpeg inteiro só por causa de um formato, reservando o FFmpeg para quando módulos futuros (vídeo/áudio) realmente precisarem dele. O wrapper SwiftPM concreto a usar é decidido na implementação, após checar qual opção mantida atualmente empacota o libwebp de forma mais enxuta.

Controle de qualidade (slider 1–100%) visível apenas quando o formato de destino é **JPEG, WebP ou HEIC**; oculto (não desabilitado) para PNG/TIFF/PDF.

### Redimensionamento

`ResizeEngine` expõe uma função pura que recebe uma imagem decodificada e um `ResizeSpec` (modo: original/preset/custom; largura; altura; manter proporção) e devolve a imagem redimensionada via Core Graphics (`CGContext` com `interpolationQuality = .high`). Para origem SVG, a rasterização acontece direto no tamanho de saída pedido (não redimensiona um raster intermediário), para melhor qualidade.

A lógica de "travar aspect ratio" (recalcular altura ao mudar largura e vice-versa) vive como um tipo de valor simples dentro de `ConvertCore` (não é código de UI) para poder ser testada isoladamente e reaproveitada tanto pelos presets quanto pelo modo "Custom".

### Nomenclatura de saída e proteção contra sobrescrita

`OutputPathResolver` resolve sempre para a mesma pasta do arquivo original, trocando só a extensão. Se o destino já existir, acrescenta ` (1)`, ` (2)`, ... até achar o primeiro número livre (sem reaproveitar números "vagos" no meio, sempre soma a partir do maior existente) — mesmo padrão visual do Finder ao duplicar arquivos. Essa é a política padrão e silenciosa da v1 (necessária de qualquer forma para lote, onde perguntar por arquivo seria péssima UX); o toggle "Overwrite existing files → Ask before replacing" da tela de Settings fica desenhado mas não funcional nesta versão — é o gancho para trocar esse comportamento no futuro sem mexer no resto do pipeline.

### Motor de conversão, lote e cancelamento

`ConversionEngine.convert(job:)` é `async throws`, roda fora da main thread (Swift Concurrency), e é o único ponto de entrada usado tanto pelo fluxo do Finder quanto pelo drag-and-drop. `BatchProcessor` recebe uma lista de jobs (um por arquivo do lote) e os processa concorrentemente com uma `TaskGroup`, reportando progresso (arquivo atual / total) por meio de um stream de eventos que a UI observa para desenhar a barra "Converting... X of Y". Cancelamento é cooperativo: `Task.checkCancellation()` é checado entre as etapas (decodificar / redimensionar / codificar / escrever), e o botão Cancel cancela a `TaskGroup` inteira; nenhum arquivo parcial é deixado na pasta de destino (escrita para um arquivo temporário e `move` atômico só ao final).

### Erros amigáveis

`ConversionError` é um enum com casos como `unsupportedOutputFormat`, `sourceUnreadable`, `insufficientDiskSpace`, `destinationWriteFailed` e `cancelled`, cada um carregando um título e uma mensagem curta em linguagem simples (o exemplo do próprio usuário — "Couldn't convert this file. The selected format isn't supported for this image." — é literalmente um desses casos) e, quando fizer sentido, uma ação sugerida ("Try another format"). O erro técnico original (ex: a mensagem bruta do `CGImageDestinationFinalize`) é preservado só no log local (`os.Logger`, subsystem próprio do app), nunca mostrado na UI nem enviado a lugar nenhum.

### Configurações

Tela de Settings em SwiftUI, persistida via `@AppStorage` num `UserDefaults(suiteName:)` do App Group compartilhado com a extensão. Nesta versão, apenas "Same folder as original" (fixo) e "Always keep original" (fixo, sempre ligado) estão realmente em vigor; "Ask every time"/"Custom folder" para local de saída, "Ask before replacing" para sobrescrita, e a qualidade padrão (85%) ficam desenhados e com estado persistido, mesmo que só a qualidade padrão realmente influencie o comportamento (pré-seleciona o slider na janela de conversão).

### Segurança e sandboxing

App e extensão local-only: nenhuma chamada de rede, nenhum SDK de analytics/tracking. App Sandbox habilitado em ambos os alvos (entitlements de leitura/escrita em arquivos selecionados pelo usuário + App Group compartilhado), seguindo o padrão que a própria Apple assume na documentação de extensões — independentemente do canal de distribuição final (App Store vs. build assinado/notarizado direto), que fica em aberto para decidir depois.

## Testing Decisions

**Seam principal (único, de alto nível):** `ConversionEngine.convert(job:) async throws -> ConversionResult`, dentro do módulo `ConvertCore`. Os testes chamam só esse método, com arquivos reais de fixture (PNG/JPEG pequenos gerados ou embutidos no bundle de testes) em um diretório temporário real (`FileManager.default.temporaryDirectory`), e verificam comportamento externo: o arquivo de saída existe, tem o UTI/extensão correto, as dimensões batem com o `ResizeSpec` pedido, o tamanho em bytes é maior que zero, e — importante — o arquivo original continua existindo e byte-a-byte idêntico ao que era antes (isso transforma "nunca destruir o original" em uma asserção de teste, não só uma promessa de UX). Nenhuma API da Apple é mockada; ImageIO/PDFKit rodam de verdade, são determinísticos e baratos localmente.

**Seams secundários (pequenos, justificados por serem contratos compartilhados entre dois pontos de entrada independentes — extensão e app — e não por preferência de granularidade):**
- `FileTypeDetector`/tabela de formatos disponíveis: testes tabulares que fixam exatamente a matriz descrita acima (mesma fonte de verdade usada pelo submenu do Finder e pelo picker de formato do drag-and-drop; se um dos dois se desviar da tabela, é aqui que quebra).
- `OutputPathResolver`: testes puros sobre a sequência de colisão de nomes (sem conflito, primeiro conflito, conflitos em sequência), sem I/O real necessário.
- Round-trip de codificação/decodificação (`Codable`) do `ConversionJob`: é o contrato exato que atravessa o processo da extensão e o processo do app via o container do App Group; uma quebra de schema aqui falha silenciosamente em produção (o app simplesmente não abre o job) se não for testada isoladamente.

Não é um seam de teste automatizado: a construção do `NSMenu` em si dentro de `FIFinderSync.menu(for:)` (é uma casca fina sobre AppKit, verificada manualmente clicando de verdade no Finder) nem as `View`s SwiftUI (verificadas manualmente rodando o app).

**Framework:** Swift Testing (`@Test`/`#expect`, o padrão atual da Apple para projetos novos em Xcode 16+/Swift 6, que é o toolchain já em uso aqui) para os testes de `ConvertCore`. Não há testes de UI automatizados nesta versão.

**Prior art:** nenhum — este é o primeiro código de teste do repositório; a suíte de `ConvertCore` estabelece a convenção para os módulos futuros (VideoConverter, AudioConverter, PDFConverter, DocumentConverter), que devem seguir o mesmo padrão de "um seam de alto nível por área, exercitado com arquivos reais".

## Out of Scope

- Conversores de Vídeo (`AVFoundation`), Áudio (`AVFoundation`), PDF-como-entrada e Documentos: só a interface/protocolo fica preparada em `ConvertCore`; nenhuma implementação real nesta versão.
- Ação separada "Convert → Resize..." no Finder (redimensionar sem converter formato): a arquitetura (mesmo `ConversionJob`/`ConversionEngine`) já suporta, mas o item de menu e a UI dedicada não são construídos agora.
- Preservação de animação em GIF/WebP animado — conversão usa o primeiro frame.
- SVG→PDF como vetor real (passthrough sem rasterizar) — nesta versão SVG sempre passa pelo pipeline raster comum.
- "Ask every time" / "Custom folder" como local de saída realmente funcionais, e "Ask before replacing" como comportamento realmente ativo — ficam desenhados nas Settings, sem lógica por trás.
- Qualquer forma de analytics, telemetria, crash reporting remoto ou chamada de rede.
- Escolha final entre distribuição via Mac App Store ou build assinado/notarizado direto — impacta detalhes de sandbox/entitlements e fica para decidir antes do release, não bloqueia a implementação da v1.

## Further Notes

- Fontes usadas para validar as decisões de plataforma: documentação da Apple sobre o framework `FinderSync` (`developer.apple.com/documentation/findersync`, incluindo as páginas de `FIFinderSync`/`menu(for:)`/`FIMenuKind`) e o guia arquivado *Finder Sync - App Extension Programming Guide*; e verificação empírica direta, nesta máquina, de `CGImageDestinationCopyTypeIdentifiers()`/`CGImageSourceCopyTypeIdentifiers()` para confirmar suporte real de leitura/escrita por formato em vez de assumir a partir de documentação desatualizada.
- Este documento cobre deliberadamente só a v1 (itens 1–17 da lista original do usuário: app + integração Finder + PNG/JPEG/WebP + resize + qualidade + janela compacta + proteção contra sobrescrita + Dark Mode + erros amigáveis). HEIC e TIFF como formatos de saída adicionais e a tela de Settings ficam desenhados neste spec porque a estrutura de dados/matriz já precisa contemplá-los desde o início, mas a ordem de implementação sugerida é: (1) `ConvertCore` + testes, (2) app principal com janela de conversão e drag-and-drop, (3) extensão do Finder + handoff, (4) Settings.

## Verificação (como testar de ponta a ponta)

1. `swift test` no pacote `ConvertCore` — cobre o seam principal (`ConversionEngine.convert`) e os seams secundários descritos acima.
2. Build do app + extensão no Xcode; rodar o app uma vez para registrar a extensão do sistema.
3. Habilitar a extensão em Configurações do Sistema → Geral → Itens de Login e Extensões (ou o caminho equivalente na versão exata do macOS instalada).
4. No Finder, clicar com o botão direito numa imagem PNG real → Convert → WebP, confirmar que a janela compacta abre, ajustar tamanho/qualidade, confirmar, e checar que `foto.webp` aparece ao lado de `foto.png` (original intacto).
5. Repetir o passo 4 já existindo um `foto.webp` na pasta, para confirmar que vira `foto (1).webp`.
6. Selecionar múltiplos arquivos no Finder → Convert → JPEG, confirmar a barra de progresso "X of Y" e testar o botão Cancel no meio do lote.
7. Abrir o app diretamente e arrastar arquivos para "Drop files here", repetindo uma conversão pelo fluxo de drag-and-drop.
8. Alternar Dark Mode/Light Mode do sistema com a janela de conversão aberta, e navegar a janela inteira só com teclado.
9. Forçar um erro (ex: tentar converter um arquivo corrompido) e confirmar que a mensagem exibida é a amigável, não a técnica.
