unit Types.Produtos;

{ Enumerações, constantes e exceções do assunto. Sem dependência de banco ou tela. }

interface

uses
  System.SysUtils;

type
  TCategoriaProduto = (cpPadaria, cpMercearia, cpHortifruti, cpBebidas);

  /// Regra de negócio violada (vira mensagem para o usuário ou HTTP 400 no servidor)
  EValidacaoProdutos = class(Exception);

const
  NOMES_CATEGORIA: array[TCategoriaProduto] of string = ('Padaria', 'Mercearia', 'Hortifruti', 'Bebidas');

implementation

end.
