# STATUS — FPGA Craft

Atualizado: 2026-11-12

## Etapa atual
**ETAPA 0 — AUDITORIA: CONCLUÍDA. Aguardando autorização do usuário para a ETAPA 1.**

## Etapas concluídas
- [x] ETAPA 0 — Auditoria (`AUDITORIA.md`)
- [ ] ETAPA 1 — Núcleo do jogo
- [ ] ETAPA 2 — Simulador Windows
- [ ] ETAPA 3 — Interface FPGA (BLOQUEADA: faltam RTL e driver.zip/api.S)
- [ ] ETAPA 4 — Integração
- [ ] ETAPA 5 — Otimização e finalização

## Arquivos criados (nesta etapa)
- `AUDITORIA.md`
- `STATUS.md`
- `audit/probe_fisica.c`, `audit/probe_chao_plano.c`, `audit/sizeof.c`, `audit/README.txt` (sondas; fora do build)

## Arquivos modificados
- Nenhum. Código-fonte original intacto (`src/`, `include/`, `Makefile`, `README.md`).

## Funcionalidades implementadas
- Nenhuma nova. Estado herdado documentado em `AUDITORIA.md` §7.

## Testes executados e resultados
| Teste | Resultado |
|-------|-----------|
| Compilar `host` com `-Wall -Wextra -std=c11` | OK, 0 avisos |
| Compilar `fpga` nativo x86-64 (só sintaxe/link) | OK, 0 avisos (NÃO executado; NÃO testado em ARM) |
| Host com ASan+UBSan, 600 quadros | OK, sem erros |
| Sonda de física (queda em repouso) | **FALHA do jogo**: oscila 15 px, `on_ground` pisca |
| Sonda de terreno | **FALHA do jogo**: degrau máx. 8 blocos; pulo máx. 1,88 bloco |
| Sonda de colocação de bloco | **FALHA do jogo**: bloco aceito dentro do jogador |
| `nm`: declarado x implementado em `cop_api` | 6 funções declaradas sem implementação |
| Hardware real / RTL | NÃO TESTADO / NÃO VERIFICÁVEL (arquivos ausentes) |

## Problemas conhecidos (resumo; detalhes em AUDITORIA.md §3)
- N1 pouso incorreto (crítico) · N2 terreno intransponível (crítico)
- V1 host não jogável · D1 hardware inverificável (sem RTL/api.S)
- D2 funções da API não implementadas · D3 flags ERROR/OVERFLOW ignoradas
- V2 dois renderizadores divergentes · V3 sem cursor na FPGA
- Sem testes automatizados

## Pendências do usuário (necessárias)
1. Enviar `driver.zip` (api.S, headers, Makefile) e todo o Verilog/SystemVerilog.
2. Esclarecer o escopo dos 512 KB.
3. Aprovar Win32/GDI para o simulador Windows.
4. Aprovar reescrita do núcleo.
5. Confirmar descarte de `fpgacraft-host.exe` e `fpgacraft.ppm`.

## Próxima tarefa exata
Após autorização: **ETAPA 1, subtarefa 1.1** — criar `core/` (world, player, terrain, inventory, game) sem dependência de hardware e um `tests/` com `make test`; depois 1.2 (corrigir pouso/colisão, N1).

## Como retomar em outra conversa
Envie o ZIP `fpgacraft_etapa0_auditoria.zip`, aponte `STATUS.md` e `AUDITORIA.md` e escreva: "Continue o FPGA Craft pela ETAPA 1, subtarefa 1.1, conforme STATUS.md. Aprovo as perguntas da seção 9 da auditoria: <suas respostas>."
