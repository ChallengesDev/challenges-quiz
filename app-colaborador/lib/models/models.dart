class Colaborador {
  final String id;
  final String nome;
  final String email;
  final String? cargo;
  final String? departamento;
  final bool ativo;
  final bool primeiroAcesso;
  final String? empresaId;
  final int metaDiaria;
  final bool metaDiariaDefinida;
  final String? corMascote;
  final String? fotoUrl;
  final bool onboardingCompleto;

  Colaborador({
    required this.id,
    required this.nome,
    required this.email,
    this.cargo,
    this.departamento,
    required this.ativo,
    required this.primeiroAcesso,
    this.empresaId,
    this.metaDiaria = 10,
    this.metaDiariaDefinida = false,
    this.corMascote,
    this.fotoUrl,
    this.onboardingCompleto = false,
  });

  factory Colaborador.fromJson(Map<String, dynamic> json) {
    return Colaborador(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? 'Colaborador',
      email: json['email'] as String? ?? '',
      cargo: json['cargo'] as String?,
      departamento: json['departamento'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      primeiroAcesso: json['primeiro_acesso'] as bool? ?? true,
      empresaId: json['empresa_id'] as String?,
      metaDiaria: json['meta_diaria'] as int? ?? 10,
      metaDiariaDefinida: json['meta_diaria_definida'] as bool? ?? false,
      corMascote: json['cor_mascote'] as String?,
      fotoUrl: json['foto_url'] as String?,
      onboardingCompleto: json['onboarding_completo'] as bool? ?? false,
    );
  }
}

class Categoria {
  final String id;
  final String nome;
  final String? descricao;
  final bool ativo;
cd ~/challenges-quiz && git add . && git commit -m "correções de compilação e ajustes diversos" && git push
  Categoria({
    required this.id,
    required this.nome,
    this.descricao,
    required this.ativo,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      ativo: json['ativo'] as bool? ?? true,
    );
  }
}

class Topico {
  final String id;
  final String categoriaId;
  final String nome;
  final String? descricao;

  Topico({
    required this.id,
    required this.categoriaId,
    required this.nome,
    this.descricao,
  });

  factory Topico.fromJson(Map<String, dynamic> json) {
    return Topico(
      id: json['id'] as String,
      categoriaId: json['categoria_id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
    );
  }
}

class Desafio {
  final String id;
  final String topicoId;
  final String titulo;
  final String dificuldade; // 'facil', 'medio', 'dificil'
  final int tempoLimite; // em segundos
  final int pontuacao; // XP
  final bool ativo;

  Desafio({
    required this.id,
    required this.topicoId,
    required this.titulo,
    required this.dificuldade,
    required this.tempoLimite,
    required this.pontuacao,
    required this.ativo,
  });

  factory Desafio.fromJson(Map<String, dynamic> json) {
    return Desafio(
      id: json['id'] as String,
      topicoId: json['topico_id'] as String,
      titulo: json['titulo'] as String,
      dificuldade: json['dificuldade'] as String? ?? 'medio',
      tempoLimite: json['tempo_limite'] as int? ?? 300,
      pontuacao: json['pontuacao'] as int? ?? 100,
      ativo: json['ativo'] as bool? ?? true,
    );
  }
}

class Pergunta {
  final String id;
  final String desafioId;
  final String texto;
  final String alternativaA;
  final String alternativaB;
  final String alternativaC;
  final String alternativaD;
  final String respostaCorreta; // 'A', 'B', 'C', 'D'
  final String? explicacao;
  final String? dificuldade;

  Pergunta({
    required this.id,
    required this.desafioId,
    required this.texto,
    required this.alternativaA,
    required this.alternativaB,
    required this.alternativaC,
    required this.alternativaD,
    required this.respostaCorreta,
    this.explicacao,
    this.dificuldade,
  });

  factory Pergunta.fromJson(Map<String, dynamic> json) {
    return Pergunta(
      id: json['id'] as String,
      desafioId: json['desafio_id'] as String,
      texto: json['texto'] as String,
      alternativaA: json['alternativa_a'] as String,
      alternativaB: json['alternativa_b'] as String,
      alternativaC: json['alternativa_c'] as String,
      alternativaD: json['alternativa_d'] as String,
      respostaCorreta: json['resposta_correta'] as String,
      explicacao: json['explicacao'] as String?,
      dificuldade: json['dificuldade'] as String?,
    );
  }
}

class Sessao {
  final String id;
  final String usuarioId;
  final String desafioId;
  final DateTime iniciadoEm;
  final DateTime? finalizadoEm;
  final int pontuacaoTotal;
  final bool concluido;
  final int scoreIntegridade;

  Sessao({
    required this.id,
    required this.usuarioId,
    required this.desafioId,
    required this.iniciadoEm,
    this.finalizadoEm,
    required this.pontuacaoTotal,
    required this.concluido,
    required this.scoreIntegridade,
  });

  factory Sessao.fromJson(Map<String, dynamic> json) {
    return Sessao(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      desafioId: json['desafio_id'] as String,
      iniciadoEm: DateTime.parse(json['iniciado_em'] as String),
      finalizadoEm: json['finalizado_em'] != null ? DateTime.parse(json['finalizado_em'] as String) : null,
      pontuacaoTotal: json['pontuacao_total'] as int? ?? 0,
      concluido: json['concluido'] as bool? ?? false,
      scoreIntegridade: json['score_integridade'] as int? ?? 100,
    );
  }
}

class Pontuacao {
  final String id;
  final String usuarioId;
  final int xpTotal;
  final int nivel;
  final int streakAtual;
  final int streakMaximo;
  final bool desafioRelampagoDisponivel;
  final DateTime? desafioRelampagoCompletadoEm;

  Pontuacao({
    required this.id,
    required this.usuarioId,
    required this.xpTotal,
    required this.nivel,
    required this.streakAtual,
    required this.streakMaximo,
    this.desafioRelampagoDisponivel = true,
    this.desafioRelampagoCompletadoEm,
  });

  factory Pontuacao.fromJson(Map<String, dynamic> json) {
    return Pontuacao(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      xpTotal: json['xp_total'] as int? ?? 0,
      nivel: json['nivel'] as int? ?? 1,
      streakAtual: json['streak_atual'] as int? ?? 0,
      streakMaximo: json['streak_maximo'] as int? ?? 0,
      desafioRelampagoDisponivel: json['desafio_relampago_disponivel'] as bool? ?? true,
      desafioRelampagoCompletadoEm: json['desafio_relampago_completado_em'] != null
          ? DateTime.parse(json['desafio_relampago_completado_em'] as String)
          : null,
    );
  }
}

class Conquista {
  final String id;
  final String nome;
  final String descricao;
  final String? icone;
  final Map<String, dynamic> criterio;

  Conquista({
    required this.id,
    required this.nome,
    required this.descricao,
    this.icone,
    required this.criterio,
  });

  factory Conquista.fromJson(Map<String, dynamic> json) {
    return Conquista(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String,
      icone: json['icone'] as String?,
      criterio: json['criterio'] as Map<String, dynamic>? ?? {},
    );
  }
}

class RankingColaborador {
  final String usuarioId;
  final String nome;
  final int posicaoGeral;
  final int xpTotal;
  final int nivel;

  RankingColaborador({
    required this.usuarioId,
    required this.nome,
    required this.posicaoGeral,
    required this.xpTotal,
    required this.nivel,
  });

  factory RankingColaborador.fromJson(Map<String, dynamic> json) {
    return RankingColaborador(
      usuarioId: json['usuario_id'] as String,
      nome: json['usuarios'] != null ? (json['usuarios']['nome'] as String? ?? 'Colaborador') : 'Colaborador',
      posicaoGeral: json['posicao_geral'] as int? ?? 999,
      xpTotal: json['usuarios'] != null && json['usuarios']['pontuacoes'] != null && json['usuarios']['pontuacoes'].isNotEmpty
          ? json['usuarios']['pontuacoes'][0]['xp_total'] as int? ?? 0
          : 0,
      nivel: json['usuarios'] != null && json['usuarios']['pontuacoes'] != null && json['usuarios']['pontuacoes'].isNotEmpty
          ? json['usuarios']['pontuacoes'][0]['nivel'] as int? ?? 1
          : 1,
    );
  }
}

class OcorrenciaFraude {
  final String? id;
  final String usuarioId;
  final String? sessaoId;
  final String tipoOcorrencia; // 'saida_tela', 'clique_ultrarrapido', 'desvio_olhar'
  final String detalhes;
  final DateTime criadoEm;

  OcorrenciaFraude({
    this.id,
    required this.usuarioId,
    this.sessaoId,
    required this.tipoOcorrencia,
    required this.detalhes,
    required this.criadoEm,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'usuario_id': usuarioId,
      if (sessaoId != null) 'sessao_id': sessaoId,
      'tipo_ocorrencia': tipoOcorrencia,
      'detalhes': detalhes,
    };
  }
}

class DailyMission {
  final String id;
  final String titulo;
  final String descricao;
  final int xpReward;

  DailyMission({
    required this.id,
    required this.titulo,
    required this.descricao,
    this.xpReward = 100,
  });
}

class TreinaMaisItem {
  final String id;
  final String empresaId;
  final String tipo; // 'dica' | 'pergunta'
  final String? categoriaId;
  final String? categoriaNome;
  final String? textoDica;
  final String? pergunta;
  final List<String>? alternativas;
  final String? respostaCorreta;
  final String? explicacao;
  final String criadoPor;
  final bool visto;
  final DateTime criadoEm;

  TreinaMaisItem({
    required this.id,
    required this.empresaId,
    required this.tipo,
    this.categoriaId,
    this.categoriaNome,
    this.textoDica,
    this.pergunta,
    this.alternativas,
    this.respostaCorreta,
    this.explicacao,
    required this.criadoPor,
    required this.visto,
    required this.criadoEm,
  });

  factory TreinaMaisItem.fromJson(Map<String, dynamic> json) {
    return TreinaMaisItem(
      id: json['id'] as String,
      empresaId: json['empresa_id'] as String,
      tipo: json['tipo'] as String,
      categoriaId: json['categoria_id'] as String?,
      categoriaNome: json['categoria_nome'] as String?,
      textoDica: json['texto_dica'] as String?,
      pergunta: json['pergunta'] as String?,
      alternativas: json['alternativas'] != null
          ? List<String>.from(json['alternativas'] as List)
          : null,
      respostaCorreta: json['resposta_correta'] as String?,
      explicacao: json['explicacao'] as String?,
      criadoPor: json['criado_por'] as String? ?? 'ia',
      visto: json['visto'] as bool? ?? false,
      criadoEm: json['criado_em'] != null
          ? DateTime.parse(json['criado_em'] as String)
          : DateTime.now(),
    );
  }
}

