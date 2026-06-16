-- =========================================================================
-- SCRIPT DE BANCO DE DADOS: NOTIFICAÇÕES (CHALLENGES QUIZ)
-- Executar este script no editor SQL do Supabase.
-- =========================================================================

-- Adiciona a coluna ultimo_acesso na tabela usuarios se ainda não existir
alter table public.usuarios add column if not exists ultimo_acesso timestamptz not null default now();

-- ==========================================
-- 1. TABELA configuracoes_notificacoes
-- ==========================================
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
-- 2. TABELA notificacoes
-- ==========================================
create table if not exists public.notificacoes (
    id uuid default gen_random_uuid() primary key,
    empresa_id uuid not null references public.empresas(id) on delete cascade,
    titulo text not null,
    mensagem text not null,
    tipo text not null check (tipo in ('novo_quiz', 'conquista', 'aviso', 'motivacional')),
    destinatario_tipo text not null check (destinatario_tipo in ('todos', 'time', 'colaborador')),
    destinatario_id uuid, -- Pode ser null se destinatario_tipo = 'todos'. Caso contrário, ID do time ou do usuário.
    status text not null default 'enviada' check (status in ('enviada', 'agendada', 'falhou')),
    agendado_para timestamptz not null default now(),
    enviado_em timestamptz,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- 3. TABELA usuario_notificacoes (Recebimento individual)
-- ==========================================
create table if not exists public.usuario_notificacoes (
    id uuid default gen_random_uuid() primary key,
    usuario_id uuid not null references public.usuarios(id) on delete cascade,
    notificacao_id uuid not null references public.notificacoes(id) on delete cascade,
    lida boolean not null default false,
    criado_em timestamptz not null default now()
);

-- ==========================================
-- HABILITAR RLS (Row Level Security)
-- ==========================================
alter table public.configuracoes_notificacoes enable row level security;
alter table public.notificacoes enable row level security;
alter table public.usuario_notificacoes enable row level security;

-- ==========================================
-- POLÍTICAS DE SEGURANÇA (RLS POLICIES)
-- ==========================================

-- 1. Configuracoes Notificacoes
create policy "Ver configurações de notificações da própria empresa"
    on public.configuracoes_notificacoes for select
    using (empresa_id = public.get_user_empresa_id());

create policy "Admins e gestores gerenciam configurações de notificações"
    on public.configuracoes_notificacoes for all
    using (empresa_id = public.get_user_empresa_id() and public.get_user_nivel_permissao() in ('gestor', 'admin'));

-- 2. Notificacoes
create policy "Usuários veem notificações da própria empresa"
    on public.notificacoes for select
    using (empresa_id = public.get_user_empresa_id());

create policy "Admins e gestores gerenciam notificações"
    on public.notificacoes for all
    using (empresa_id = public.get_user_empresa_id() and public.get_user_nivel_permissao() in ('gestor', 'admin'));

-- 3. Usuario Notificacoes
create policy "Usuários veem suas próprias notificações recebidas"
    on public.usuario_notificacoes for select
    using (usuario_id = auth.uid());

create policy "Usuários atualizam leitura de suas notificações"
    on public.usuario_notificacoes for update
    using (usuario_id = auth.uid());

-- ==========================================
-- TRIGGERS E FUNÇÕES DE AUTOMAÇÃO
-- ==========================================

-- 1. Trigger para definir enviado_em antes de inserir/atualizar
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

-- Trigger para propagar notificações para os usuários finais após inserir/atualizar
create or replace function public.handle_propagate_notificacao()
returns trigger as $$
begin
  if NEW.status = 'enviada' and (TG_OP = 'INSERT' or OLD.status <> 'enviada') then
    -- Propagar conforme o tipo de destinatário
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

-- 2. Trigger para criar configurações padrão de notificação ao cadastrar nova empresa
create or replace function public.handle_new_empresa_notificacoes()
returns trigger as $$
begin
  insert into public.configuracoes_notificacoes (empresa_id, novo_quiz, subiu_nivel, streak_risco, ranking_atualizado, sem_acesso_3_dias)
  values (NEW.id, true, true, true, true, true)
  on conflict (empresa_id) do nothing;
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists tr_new_empresa_notificacoes on public.empresas;
create trigger tr_new_empresa_notificacoes
  after insert on public.empresas
  for each row execute procedure public.handle_new_empresa_notificacoes();

-- Insere configurações padrão para as empresas já cadastradas
insert into public.configuracoes_notificacoes (empresa_id, novo_quiz, subiu_nivel, streak_risco, ranking_atualizado, sem_acesso_3_dias)
select id, true, true, true, true, true
from public.empresas
on conflict (empresa_id) do nothing;

-- 3. Trigger Automático: Novo quiz disponível (after insert on desafios)
create or replace function public.handle_auto_notif_new_quiz()
returns trigger as $$
declare
  v_empresa_id uuid;
  v_enabled boolean;
begin
  -- Obter a empresa através do tópico/categoria
  select c.empresa_id into v_empresa_id
  from public.topicos t
  join public.categorias c on t.categoria_id = c.id
  where t.id = NEW.topico_id;
  
  if v_empresa_id is not null then
    -- Verificar se a notificação está ativa
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

drop trigger if exists tr_auto_notif_new_quiz on public.desafios;
create trigger tr_auto_notif_new_quiz
  after insert on public.desafios
  for each row execute procedure public.handle_auto_notif_new_quiz();

-- 4. Trigger Automático: Colaborador subiu de nível (after update of nivel on pontuacoes)
create or replace function public.handle_auto_notif_level_up()
returns trigger as $$
declare
  v_empresa_id uuid;
  v_enabled boolean;
begin
  if NEW.nivel > OLD.nivel then
    -- Obter a empresa do usuário
    select empresa_id into v_empresa_id
    from public.usuarios
    where id = NEW.usuario_id;
    
    if v_empresa_id is not null then
      -- Verificar se a notificação está ativa
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

drop trigger if exists tr_auto_notif_level_up on public.pontuacoes;
create trigger tr_auto_notif_level_up
  after update of nivel on public.pontuacoes
  for each row execute procedure public.handle_auto_notif_level_up();
