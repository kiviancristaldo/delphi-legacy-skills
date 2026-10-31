# Roteiro de atualização do ACBr

## Antes
- [ ] Anotar a versão/revisão atual do ACBr usada em produção.
- [ ] Guardar o executável de produção atual (plano de volta).
- [ ] Gerar e guardar XMLs de referência na versão atual (golden master): uma nota de cada
      tipo de operação relevante (venda, devolução, transferência, com ST, com desconto...).
- [ ] Listar bibliotecas externas usadas hoje (SSL, XML, DLLs de TEF/impressora) e a bitagem.
- [ ] Ler o changelog do intervalo de versões e as mensagens fixadas no Fórum ACBr sobre
      mudanças que quebram compatibilidade.

## Durante
- [ ] Branch dedicado.
- [ ] Fontes novos em pasta separada; library path do Delphi apontando para eles.
- [ ] Pacotes recompilados e instalados no IDE.
- [ ] `Test-CompatibilidadeACBr.ps1` rodado e tabela de mudanças aprovada.
- [ ] Ajustes de código e DFM feitos em commits pequenos.
- [ ] Projeto compilando (skill `delphi-compile-loop`).

## Configuração para revisar sempre
- [ ] Bibliotecas de criptografia/SSL e de XML configuradas conforme a versão nova.
- [ ] Certificado digital (arquivo, senha, número de série, repositório do Windows).
- [ ] Caminho dos schemas atualizado para os schemas que acompanham a versão nova.
- [ ] Ambiente (homologação × produção) e UF.
- [ ] Versão do documento fiscal (layout) configurada.
- [ ] Timeouts e proxy.
- [ ] Caminhos de salvamento de XML, PDF e logs.

## Homologação (por tipo de documento usado)
- [ ] Status do serviço
- [ ] Emissão (cada cenário de negócio do golden master)
- [ ] Consulta
- [ ] Cancelamento
- [ ] Carta de correção / eventos usados
- [ ] Inutilização
- [ ] Contingência (se o sistema usa)
- [ ] Impressão (DANFE / DANFCE / DACTE...) e envio de e-mail
- [ ] TEF: venda, cancelamento, reimpressão, pendências (se usa)

## Comparando XMLs
Normalize antes de comparar (remova assinatura, chave, datas de emissão, número e protocolo)
e compare o restante. Diferenças em tags de valores e impostos são críticas; diferenças de
versão de schema e tags novas obrigatórias são esperadas e devem ser documentadas.

## Liberação
- [ ] Cliente piloto escolhido (operação representativa, contato próximo).
- [ ] Passo a passo de volta testado (trocar o executável e as DLLs).
- [ ] Acompanhamento das primeiras emissões em produção.
- [ ] Liberação geral após o período combinado sem problemas.
