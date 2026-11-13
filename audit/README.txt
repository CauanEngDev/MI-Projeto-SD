Sondas usadas na ETAPA 0 (somente leitura; nao fazem parte do build).
Compilar na raiz do projeto, por exemplo:
  gcc -O0 -Iinclude src/minecraft.c audit/probe_fisica.c -o /tmp/probe && /tmp/probe
  gcc -O0 -Iinclude src/minecraft.c audit/probe_chao_plano.c -o /tmp/probe2 && /tmp/probe2
  gcc -Iinclude audit/sizeof.c -o /tmp/sz && /tmp/sz
