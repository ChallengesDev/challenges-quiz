-- Ativar a extensão UUID se ainda não estiver ativa
create extension if not exists "uuid-ossp";

-- ==========================================
-- 1. TABELA empresas
-- ==========================================
create table public.empresas (
    id uuid default gen_random_uuid() primary key,
    nome text not null,
    plano text not null default 'free',
    ativo boolean not null default true,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 3. TABELA departamentos
-- ==========================================
create table public.departamentos (
    id uuid default gen_random_uuid() primary key,
    empresa_id uuid not null references public.empresas(id) on delete cascade,
    nome text not null,
    descricao text,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 4. TABELA times
-- ==========================================
create table public.times (
    id uuid default gen_random_uuid() primary key,
    departamento_id uuid not null references public.departamentos(id) on delete cascade,
    nome text not null,
    descricao text,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 2. TABELA usuarios (Perfis públicos conectados ao Supabase Auth)
-- ==========================================
create table public.usuarios (
    id uuid primary key references auth.users(id) on delete cascade,
    empresa_id uuid references public.empresas(id) on delete set null,
    departamento_id uuid references public.departamentos(id) on delete set null,
    time_id uuid references public.times(id) on delete set null,
    nome text not null,
    email text not null unique,
    senha text, -- Nota: Para uso legado/customizado. Recomendado usar o Supabase Auth integrado.
    cargo text,
    departamento text, -- Nome do departamento por extenso
    nivel_permissao text not null default 'colaborador' check (nivel_permissao in ('colaborador', 'gestor', 'admin')),
    ativo boolean not null default true,
    primeiro_acesso boolean not null default true,
    meta_diaria integer not null default 10,
    meta_diaria_definida boolean not null default false,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 5. TABELA categorias
-- ==========================================
create table public.categorias (
    id uuid default gen_random_uuid() primary key,
    empresa_id uuid not null references public.empresas(id) on delete cascade,
    nome text not null,
    descricao text,
    ativo boolean not null default true,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 6. TABELA topicos
-- ==========================================
create table public.topicos (
    id uuid default gen_random_uuid() primary key,
    categoria_id uuid not null references public.categorias(id) on delete cascade,
    nome text not null,
    descricao text,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 7. TABELA desafios
-- ==========================================
create table public.desafios (
    id uuid default gen_random_uuid() primary key,
    topico_id uuid not null references public.topicos(id) on delete cascade,
    titulo text not null,
    dificuldade text not null default 'medio' check (dificuldade in ('facil', 'medio', 'dificil')),
    tempo_limite integer not null default 600, -- Tempo limite em segundos
    pontuacao integer not null default 100,     -- XP concedido por completar
    ativo boolean not null default true,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 8. TABELA perguntas
-- ==========================================
create table public.perguntas (
    id uuid default gen_random_uuid() primary key,
    desafio_id uuid not null references public.desafios(id) on delete cascade,
    texto text not null,
    alternativa_a text not null,
    alternativa_b text not null,
    alternativa_c text not null,
    alternativa_d text not null,
    resposta_correta char(1) not null check (resposta_correta in ('A', 'B', 'C', 'D')),
    explicacao text,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 9. TABELA sessoes (Tentativa ou execução de desafios)
-- ==========================================
create table public.sessoes (
    id uuid default gen_random_uuid() primary key,
    usuario_id uuid not null references public.usuarios(id) on delete cascade,
    desafio_id uuid not null references public.desafios(id) on delete cascade,
    iniciado_em timestamptz not null default now(),
    finalizado_em timestamptz,
    pontuacao_total integer not null default 0,
    concluido boolean not null default false,
    score_integridade integer not null default 100
);

-- ==========================================
-- 10. TABELA respostas
-- ==========================================
create table public.respostas (
    id uuid default gen_random_uuid() primary key,
    sessao_id uuid not null references public.sessoes(id) on delete cascade,
    pergunta_id uuid not null references public.perguntas(id) on delete cascade,
    alternativa_escolhida char(1) not null check (alternativa_escolhida in ('A', 'B', 'C', 'D')),
    correta boolean not null,
    tempo_resposta integer -- Tempo em segundos levado para responder
);

-- ==========================================
-- 11. TABELA pontuacoes
-- ==========================================
create table public.pontuacoes (
    id uuid default gen_random_uuid() primary key,
    usuario_id uuid not null unique references public.usuarios(id) on delete cascade,
    xp_total integer not null default 0,
    nivel integer not null default 1,
    streak_atual integer not null default 0,
    streak_maximo integer not null default 0
);

-- ==========================================
-- 12. TABELA conquistas
-- ==========================================
create table public.conquistas (
    id uuid default gen_random_uuid() primary key,
    nome text not null unique,
    descricao text not null,
    icone text,
    criterio jsonb not null default '{}'::jsonb,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 13. TABELA usuario_conquistas
-- ==========================================
create table public.usuario_conquistas (
    id uuid default gen_random_uuid() primary key,
    usuario_id uuid not null references public.usuarios(id) on delete cascade,
    conquista_id uuid not null references public.conquistas(id) on delete cascade,
    conquistado_em timestamptz not null default now(),
    unique(usuario_id, conquista_id)
);

-- ==========================================
-- 14. TABELA rankings
-- ==========================================
create table public.rankings (
    id uuid default gen_random_uuid() primary key,
    usuario_id uuid not null references public.usuarios(id) on delete cascade,
    empresa_id uuid not null references public.empresas(id) on delete cascade,
    posicao_geral integer not null,
    posicao_time integer,
    posicao_categoria integer,
    atualizado_em timestamptz not null default now()
);

-- ==========================================
-- TRIGGERS E FUNÇÕES DE SEGURANÇA E AUTOMAÇÃO
-- ==========================================

-- Função auxiliar com 'security definer' para obter a empresa do usuário logado
-- sem causar recursão infinita em políticas RLS.
create or replace function public.get_user_empresa_id()
returns uuid as $$
  select empresa_id from public.usuarios where id = auth.uid();
$$ language sql security definer;

-- Função auxiliar com 'security definer' para obter o nível de permissão do usuário
create or replace function public.get_user_nivel_permissao()
returns text as $$
  select nivel_permissao from public.usuarios where id = auth.uid();
$$ language sql security definer;

-- Função auxiliar com 'security definer' para obter o time do usuário
create or replace function public.get_user_time_id()
returns uuid as $$
  select time_id from public.usuarios where id = auth.uid();
$$ language sql security definer;

-- Trigger para criar perfil público automaticamente quando um novo usuário se cadastrar no Supabase Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.usuarios (id, email, nome, nivel_permissao, ativo, primeiro_acesso)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'nome', new.raw_user_meta_data->>'full_name', 'Colaborador'),
    coalesce(new.raw_user_meta_data->>'nivel_permissao', 'colaborador'),
    true,
    true
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Trigger para inicializar a tabela de pontuações de um usuário recém-criado
create or replace function public.handle_new_usuario_pontuacao()
returns trigger as $$
begin
  insert into public.pontuacoes (usuario_id, xp_total, nivel, streak_atual, streak_maximo)
  values (new.id, 0, 1, 0, 0)
  on conflict (usuario_id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_usuario_created
  after insert on public.usuarios
  for each row execute procedure public.handle_new_usuario_pontuacao();


-- ==========================================
-- HABILITAR ROW LEVEL SECURITY (RLS)
-- ==========================================
alter table public.empresas enable row level security;
alter table public.usuarios enable row level security;
alter table public.departamentos enable row level security;
alter table public.times enable row level security;
alter table public.categorias enable row level security;
alter table public.topicos enable row level security;
alter table public.desafios enable row level security;
alter table public.perguntas enable row level security;
alter table public.sessoes enable row level security;
alter table public.respostas enable row level security;
alter table public.pontuacoes enable row level security;
alter table public.conquistas enable row level security;
alter table public.usuario_conquistas enable row level security;
alter table public.rankings enable row level security;


-- ==========================================
-- POLÍTICAS DE SEGURANÇA (RLS POLICIES)
-- ==========================================

-- 1. Empresas
create policy "Usuários podem ver a própria empresa"
    on public.empresas for select
    using (id = public.get_user_empresa_id());

create policy "Admins podem atualizar a empresa"
    on public.empresas for update
    using (id = public.get_user_empresa_id() and public.get_user_nivel_permissao() = 'admin');

-- 2. Usuários
create policy "Usuários podem visualizar perfis da mesma empresa"
    on public.usuarios for select
    using (empresa_id = public.get_user_empresa_id());

create policy "Usuários podem atualizar o próprio perfil"
    on public.usuarios for update
    using (id = auth.uid());

create policy "Admins e gestores podem atualizar usuários da mesma empresa"
    on public.usuarios for update
    using (empresa_id = public.get_user_empresa_id() and public.get_user_nivel_permissao() in ('gestor', 'admin'));

-- 3. Departamentos
create policy "Usuários podem visualizar departamentos da mesma empresa"
    on public.departamentos for select
    using (empresa_id = public.get_user_empresa_id());

create policy "Admins podem gerenciar departamentos da mesma empresa"
    on public.departamentos for all
    using (empresa_id = public.get_user_empresa_id() and public.get_user_nivel_permissao() = 'admin');

-- 4. Times
create policy "Usuários podem visualizar times do mesmo departamento da empresa"
    on public.times for select
    using (
        exists (
            select 1 from public.departamentos d
            where d.id = departamento_id and d.empresa_id = public.get_user_empresa_id()
        )
    );

create policy "Admins e Gestores podem gerenciar times da sua empresa"
    on public.times for all
    using (
        exists (
            select 1 from public.departamentos d
            where d.id = departamento_id and d.empresa_id = public.get_user_empresa_id()
        ) and public.get_user_nivel_permissao() in ('gestor', 'admin')
    );

-- 5. Categorias
create policy "Usuários podem visualizar categorias da mesma empresa"
    on public.categorias for select
    using (empresa_id = public.get_user_empresa_id());

create policy "Admins e Gestores podem gerenciar categorias da mesma empresa"
    on public.categorias for all
    using (empresa_id = public.get_user_empresa_id() and public.get_user_nivel_permissao() in ('gestor', 'admin'));

-- 6. Tópicos
create policy "Usuários podem visualizar tópicos de categorias da mesma empresa"
    on public.topicos for select
    using (
        exists (
            select 1 from public.categorias c
            where c.id = categoria_id and c.empresa_id = public.get_user_empresa_id()
        )
    );

create policy "Admins e Gestores podem gerenciar tópicos de categorias da mesma empresa"
    on public.topicos for all
    using (
        exists (
            select 1 from public.categorias c
            where c.id = categoria_id and c.empresa_id = public.get_user_empresa_id()
        ) and public.get_user_nivel_permissao() in ('gestor', 'admin')
    );

-- 7. Desafios
create policy "Usuários podem visualizar desafios ativos da mesma empresa"
    on public.desafios for select
    using (
        exists (
            select 1 from public.topicos t
            join public.categorias c on t.categoria_id = c.id
            where t.id = topico_id and c.empresa_id = public.get_user_empresa_id()
        )
    );

create policy "Admins e Gestores podem gerenciar desafios"
    on public.desafios for all
    using (
        exists (
            select 1 from public.topicos t
            join public.categorias c on t.categoria_id = c.id
            where t.id = topico_id and c.empresa_id = public.get_user_empresa_id()
        ) and public.get_user_nivel_permissao() in ('gestor', 'admin')
    );

-- 8. Perguntas
create policy "Usuários podem visualizar perguntas de desafios da mesma empresa"
    on public.perguntas for select
    using (
        exists (
            select 1 from public.desafios d
            join public.topicos t on d.topico_id = t.id
            join public.categorias c on t.categoria_id = c.id
            where d.id = desafio_id and c.empresa_id = public.get_user_empresa_id()
        )
    );

create policy "Admins e Gestores podem gerenciar perguntas"
    on public.perguntas for all
    using (
        exists (
            select 1 from public.desafios d
            join public.topicos t on d.topico_id = t.id
            join public.categorias c on t.categoria_id = c.id
            where d.id = desafio_id and c.empresa_id = public.get_user_empresa_id()
        ) and public.get_user_nivel_permissao() in ('gestor', 'admin')
    );

-- 9. Sessões
create policy "Usuários podem gerenciar suas próprias sessões"
    on public.sessoes for all
    using (usuario_id = auth.uid());

create policy "Gestores e Admins podem ver sessões de usuários da empresa"
    on public.sessoes for select
    using (
        exists (
            select 1 from public.usuarios u
            where u.id = usuario_id and u.empresa_id = public.get_user_empresa_id()
        ) and public.get_user_nivel_permissao() in ('gestor', 'admin')
    );

-- 10. Respostas
create policy "Usuários podem gerenciar suas próprias respostas enviadas"
    on public.respostas for all
    using (
        exists (
            select 1 from public.sessoes s
            where s.id = sessao_id and s.usuario_id = auth.uid()
        )
    );

-- 11. Pontuações
create policy "Usuários podem ver pontuações da mesma empresa"
    on public.pontuacoes for select
    using (
        exists (
            select 1 from public.usuarios u
            where u.id = usuario_id and u.empresa_id = public.get_user_empresa_id()
        )
    );

create policy "Permitir atualização interna de pontuações"
    on public.pontuacoes for update
    using (true); -- Controle fino de escrita pode ser acoplado à service role do backend ou triggers do banco.

-- 12. Conquistas
create policy "Todos os usuários autenticados podem ver conquistas"
    on public.conquistas for select
    using (auth.role() = 'authenticated');

-- 13. Usuário Conquistas
create policy "Usuários podem ver suas próprias conquistas e as de colegas da empresa"
    on public.usuario_conquistas for select
    using (
        exists (
            select 1 from public.usuarios u
            where u.id = usuario_id and u.empresa_id = public.get_user_empresa_id()
        )
    );

create policy "Sistema e usuários podem adicionar conquistas desbloqueadas"
    on public.usuario_conquistas for insert
    with check (usuario_id = auth.uid());

-- 14. Rankings
create policy "Usuários podem visualizar ranking da própria empresa"
    on public.rankings for select
    using (empresa_id = public.get_user_empresa_id());

-- ==========================================
-- 15. TABELA ocorrencias_fraude
-- ==========================================
create table public.ocorrencias_fraude (
    id uuid default gen_random_uuid() primary key,
    usuario_id uuid not null references public.usuarios(id) on delete cascade,
    sessao_id uuid references public.sessoes(id) on delete cascade,
    tipo_ocorrencia text not null, -- 'saida_tela', 'clique_ultrarrapido', 'desvio_olhar'
    detalhes text,
    criado_em timestamptz not null default now()
);

alter table public.ocorrencias_fraude enable row level security;

create policy "Usuários podem visualizar suas próprias ocorrências de fraude"
    on public.ocorrencias_fraude for select
    using (usuario_id = auth.uid());

create policy "Usuários podem registrar suas próprias ocorrências de fraude"
    on public.ocorrencias_fraude for insert
    with check (usuario_id = auth.uid());

create policy "Admins e Gestores podem gerenciar todas as ocorrências de fraude"
    on public.ocorrencias_fraude for all
    using (public.get_user_nivel_permissao() in ('gestor', 'admin'));


-- =========================================================================
-- 16. TABELA configuracoes_notificacoes (Módulo de Notificações)
-- =========================================================================
alter table public.usuarios add column if not exists ultimo_acesso timestamptz not null default now();

create table if not exists public.configuracoes_notificacoes (
    empresa_id uuid primary key references public.empresas(id) on delete cascade,
    novo_quiz boolean not null default true,
    subiu_nivel boolean not null default true,
    streak_risco boolean not null default true,
    ranking_atualizado boolean not null default true,
    sem_acesso_3_dias boolean not null default true,
    atualizado_em timestamptz not null default now()
);

-- ==========================================
-- 17. TABELA notificacoes
-- ==========================================
create table if not exists public.notificacoes (
    id uuid default gen_random_uuid() primary key,
    empresa_id uuid not null references public.empresas(id) on delete cascade,
    titulo text not null,
    mensagem text not null,
    tipo text not null check (tipo in ('novo_quiz', 'conquista', 'aviso', 'motivacional')),
    destinatario_tipo text not null check (destinatario_tipo in ('todos', 'time', 'colaborador')),
    destinatario_id uuid,
    status text not null default 'enviada' check (status in ('enviada', 'agendada', 'falhou')),
    agendado_para timestamptz not null default now(),
    enviado_em timestamptz,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 18. TABELA usuario_notificacoes
-- ==========================================
create table if not exists public.usuario_notificacoes (
    id uuid default gen_random_uuid() primary key,
    usuario_id uuid not null references public.usuarios(id) on delete cascade,
    notificacao_id uuid not null references public.notificacoes(id) on delete cascade,
    lida boolean not null default false,
    criado_em timestamptz not null default now()
);

alter table public.configuracoes_notificacoes enable row level security;
alter table public.notificacoes enable row level security;
alter table public.usuario_notificacoes enable row level security;

-- Políticas
create policy "Ver configurações de notificações da própria empresa"
    on public.configuracoes_notificacoes for select
    using (empresa_id = public.get_user_empresa_id());

create policy "Admins e gestores gerenciam configurações de notificações"
    on public.configuracoes_notificacoes for all
    using (empresa_id = public.get_user_empresa_id() and public.get_user_nivel_permissao() in ('gestor', 'admin'));

create policy "Usuários veem notificações da própria empresa"
    on public.notificacoes for select
    using (empresa_id = public.get_user_empresa_id());

create policy "Admins e gestores gerenciam notificações"
    on public.notificacoes for all
    using (empresa_id = public.get_user_empresa_id() and public.get_user_nivel_permissao() in ('gestor', 'admin'));

create policy "Usuários veem suas próprias notificações recebidas"
    on public.usuario_notificacoes for select
    using (usuario_id = auth.uid());

create policy "Usuários atualizam leitura de suas notificações"
    on public.usuario_notificacoes for update
    using (usuario_id = auth.uid());

-- Triggers
create or replace function public.handle_set_enviado_em()
returns trigger as $$
begin
  if NEW.status = 'enviada' and (TG_OP = 'INSERT' or OLD.status <> 'enviada') then
    if NEW.enviado_em is null then
      NEW.enviado_em := now();
    end if;
  end if;
  return NEW;
end;
$$ language plpgsql;

drop trigger if exists tr_set_enviado_em on public.notificacoes;
create trigger tr_set_enviado_em
  before insert or update of status on public.notificacoes
  for each row execute procedure public.handle_set_enviado_em();

create or replace function public.handle_propagate_notificacao()
returns trigger as $$
begin
  if NEW.status = 'enviada' and (TG_OP = 'INSERT' or OLD.status <> 'enviada') then
    if NEW.destinatario_tipo = 'todos' then
      insert into public.usuario_notificacoes (usuario_id, notificacao_id, lida, criado_em)
      select id, NEW.id, false, now()
      from public.usuarios
      where empresa_id = NEW.empresa_id and ativo = true;
      
    elsif NEW.destinatario_tipo = 'time' then
      insert into public.usuario_notificacoes (usuario_id, notificacao_id, lida, criado_em)
      select id, NEW.id, false, now()
      from public.usuarios
      where time_id = NEW.destinatario_id and ativo = true;
      
    elsif NEW.destinatario_tipo = 'colaborador' then
      insert into public.usuario_notificacoes (usuario_id, notificacao_id, lida, criado_em)
      values (NEW.destinatario_id, NEW.id, false, now());
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer;

drop trigger if exists tr_propagate_notificacao on public.notificacoes;
create trigger tr_propagate_notificacao
  after insert or update of status on public.notificacoes
  for each row execute procedure public.handle_propagate_notificacao();

create or replace function public.handle_new_empresa_notificacoes()
returns trigger as $$
begin
  insert into public.configuracoes_notificacoes (empresa_id, novo_quiz, subiu_nivel, streak_risco, ranking_atualizado, sem_acesso_3_dias)
  values (NEW.id, true, true, true, true, true)
  on conflict (empresa_id) do nothing;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger tr_new_empresa_notificacoes
  after insert on public.empresas
  for each row execute procedure public.handle_new_empresa_notificacoes();

create or replace function public.handle_auto_notif_new_quiz()
returns trigger as $$
declare
  v_empresa_id uuid;
  v_enabled boolean;
begin
  select c.empresa_id into v_empresa_id
  from public.topicos t
  join public.categorias c on t.categoria_id = c.id
  where t.id = NEW.topico_id;
  
  if v_empresa_id is not null then
    select novo_quiz into v_enabled
    from public.configuracoes_notificacoes
    where empresa_id = v_empresa_id;
    
    if v_enabled is null or v_enabled = true then
      insert into public.notificacoes (empresa_id, titulo, mensagem, tipo, destinatario_tipo, status, agendado_para)
      values (v_empresa_id, 'Novo Quiz Disponível!', 'Um novo quiz "' || NEW.titulo || '" foi publicado. Venha responder!', 'novo_quiz', 'todos', 'enviada', now());
    end if;
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger tr_auto_notif_new_quiz
  after insert on public.desafios
  for each row execute procedure public.handle_auto_notif_new_quiz();

create or replace function public.handle_auto_notif_level_up()
returns trigger as $$
declare
  v_empresa_id uuid;
  v_enabled boolean;
begin
  if NEW.nivel > OLD.nivel then
    select empresa_id into v_empresa_id
    from public.usuarios
    where id = NEW.usuario_id;
    
    if v_empresa_id is not null then
      select subiu_nivel into v_enabled
      from public.configuracoes_notificacoes
      where empresa_id = v_empresa_id;
      
      if v_enabled is null or v_enabled = true then
        insert into public.notificacoes (empresa_id, titulo, mensagem, tipo, destinatario_tipo, destinatario_id, status, agendado_para)
        values (v_empresa_id, 'Parabéns pelo Nível ' || NEW.nivel || '!', 'Você subiu de nível! Continue assim para acumular mais conquistas.', 'conquista', 'colaborador', NEW.usuario_id, 'enviada', now());
      end if;
    end if;
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger tr_auto_notif_level_up
  after update of nivel on public.pontuacoes
  for each row execute procedure public.handle_auto_notif_level_up();