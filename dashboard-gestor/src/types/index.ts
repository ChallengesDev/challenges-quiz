export interface Empresa {
  id: string;
  nome: string;
  plano: string;
  ativo: boolean;
  criado_em: string;
}

export interface Departamento {
  id: string;
  empresa_id: string;
  nome: string;
  descricao?: string;
  criado_em: string;
}

export interface Time {
  id: string;
  departamento_id: string;
  nome: string;
  descricao?: string;
  criado_em: string;
}

export interface Usuario {
  id: string;
  empresa_id?: string;
  departamento_id?: string;
  time_id?: string;
  nome: string;
  email: string;
  senha?: string;
  cargo?: string;
  departamento?: string; // Nome por extenso
  nivel_permissao: 'colaborador' | 'gestor' | 'admin';
  ativo: boolean;
  primeiro_acesso: boolean;
  criado_em: string;
  empresas?: { nome: string }; // Join relation
  departamento_rel?: Departamento;
  time_rel?: Time;
}

export interface Categoria {
  id: string;
  empresa_id: string;
  nome: string;
  descricao?: string;
  ativo: boolean;
  criado_em: string;
}

export interface Topico {
  id: string;
  categoria_id: string;
  nome: string;
  descricao?: string;
  criado_em: string;
}

export interface Desafio {
  id: string;
  topico_id: string;
  titulo: string;
  dificuldade: 'facil' | 'medio' | 'dificil';
  tempo_limite: number; // segundos
  pontuacao: number; // XP
  ativo: boolean;
  criado_em: string;
  topico_nome?: string; // Join helper
  categoria_nome?: string; // Join helper
}

export interface Pergunta {
  id: string;
  desafio_id: string;
  texto: string;
  alternativa_a: string;
  alternativa_b: string;
  alternativa_c: string;
  alternativa_d: string;
  resposta_correta: 'A' | 'B' | 'C' | 'D';
  criado_em: string;
}

export interface Sessao {
  id: string;
  usuario_id: string;
  desafio_id: string;
  iniciado_em: string;
  finalizado_em?: string;
  pontuacao_total: number;
  concluido: boolean;
}

export interface Resposta {
  id: string;
  sessao_id: string;
  pergunta_id: string;
  alternativa_escolhida: 'A' | 'B' | 'C' | 'D';
  correta: boolean;
  tempo_resposta?: number;
}

export interface Pontuacao {
  id: string;
  usuario_id: string;
  xp_total: number;
  nivel: number;
  streak_atual: number;
  streak_maximo: number;
}

export interface Conquista {
  id: string;
  nome: string;
  descricao: string;
  icone?: string;
  criterio: any;
  criado_em: string;
}

export interface UsuarioConquista {
  id: string;
  usuario_id: string;
  conquista_id: string;
  conquistado_em: string;
}

export interface Ranking {
  id: string;
  usuario_id: string;
  empresa_id: string;
  posicao_geral: number;
  posicao_time?: number;
  posicao_categoria?: number;
  atualizado_em: string;
  usuario?: Usuario;
}
