# FPGAcraft — sandbox 2D em C para DE1-SoC

Protótipo Minecraft-like 2D. A lógica do jogo, renderização e API MMIO estão em C. Não usa `.mif`, `.hex`, imagens externas nem RAM inicializada por arquivos.

## Hardware esperado
- DE1-SoC / Cyclone V, Linux no HPS.
- Coprocessador do projeto com ID `0xC0DE0001` na ponte HPS-to-FPGA Lightweight.
- Resolução lógica 320x240, tilemap 40x30, tiles 8x8, sprites 16x16.
- O hardware deve implementar os opcodes documentados em `cop_api.h` e os registradores de `hps_bridges.h`.

## Controles
- Setas esquerda/direita: mover.
- Espaço/Enter: pular.
- Clique esquerdo: minerar bloco próximo.
- Clique direito: colocar o bloco selecionado (terra).
- ESC: sair.

## Testar no computador
```sh
make host
./fpgacraft-host 180 fpgacraft.ppm
```
O programa executa uma simulação determinística e gera uma captura PPM de 320x240 pixels. Esse alvo de computador é um teste rápido da lógica e da geração do mundo; os controles interativos estão no alvo FPGA. Abra `fpgacraft.ppm` com GIMP, ImageMagick ou outro visualizador.

## Compilar na DE1-SoC
Copie a pasta para a placa e execute:
```sh
make fpga CC=gcc
sudo ./fpgacraft-fpga
```
O acesso a `/dev/mem` normalmente exige root. O teclado/mouse precisam estar acessíveis em `/dev/input/event*`.

## Memória
O mundo ocupa `64*32 = 2048` bytes. O estado do jogador e estruturas auxiliares são pequenos. O framebuffer de teste ocupa cerca de 230 KB temporários no host; ele não é usado no alvo FPGA. O alvo envia tiles e comandos ao coprocessador e não mantém framebuffer de pixels na RAM do HPS.

## Limitações desta primeira versão
- Mundo finito 64x32 blocos; sem inventário visual ainda.
- Mineração e colocação limitadas a 5 blocos de distância.
- Sem crafting, iluminação, água, áudio ou salvamento em disco.
- A renderização FPGA usa tilemap circular 40x30 e scroll por hardware.
- O driver pressupõe que a RTL corresponda à API e aos endereços do projeto fornecido. Não altera RTL nem configuração Platform Designer.

## Observação sobre a capacidade de 512 KB
O limite de 512 KB deve ser confirmado: RAM FPGA (M10K), RAM disponível no HPS ou orçamento do software são coisas diferentes. Este projeto evita reservar um framebuffer de 320x240 no HPS e mantém o mapa em poucos KB.
