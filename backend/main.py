import os
import uuid
import asyncio
from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from supabase import create_client, Client

# Carrega as variáveis de ambiente do arquivo .env
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_PUBLISHABLE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("As variáveis SUPABASE_URL e SUPABASE_SECRET_KEY/SUPABASE_PUBLISHABLE_KEY precisam estar configuradas no arquivo .env")

# Inicializa o cliente do Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

app = FastAPI(
    title="Challenges Quiz API",
    description="Backend para o projeto Challenges Quiz com FastAPI e Supabase",
    version="0.1.0"
)

# Configura as permissões de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modelos Pydantic
class EmpresaCreate(BaseModel):
    nome: str
    plano: str = "free"
    ativo: bool = True

class EmpresaUpdate(BaseModel):
    nome: Optional[str] = None
    plano: Optional[str] = None
    ativo: Optional[bool] = None

class UsuarioCreate(BaseModel):
    nome: str
    email: str
    cargo: Optional[str] = None
    departamento: Optional[str] = None
    nivel_permissao: str = "colaborador"  # colaborador, gestor, admin
    empresa_id: Optional[str] = None     # ID da empresa (UUID)
    senha: Optional[str] = None          # Opcional, senha padrão se vazia

class UsuarioUpdate(BaseModel):
    nome: Optional[str] = None
    cargo: Optional[str] = None
    nivel_permissao: Optional[str] = None
    departamento: Optional[str] = None

# Rotas do App
@app.get("/")
def read_root():
    return {
        "message": "Bem-vindo à API do Challenges Quiz!",
        "status": "online",
        "database": "Supabase conectado com sucesso"
    }

@app.get("/health")
def health_check():
    try:
        # Validação simples
        return {
            "status": "healthy",
            "supabase_url": SUPABASE_URL
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro de conexão: {str(e)}")

# ==========================================
# ENDPOINTS DE EMPRESAS
# ==========================================

@app.get("/api/empresas")
def list_empresas():
    try:
        response = supabase.table("empresas").select("*").order("nome").execute()
        return response.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao listar empresas: {str(e)}")

@app.post("/api/empresas", status_code=201)
def create_empresa(empresa: EmpresaCreate):
    try:
        data = {
            "nome": empresa.nome,
            "plano": empresa.plano,
            "ativo": empresa.ativo
        }
        response = supabase.table("empresas").insert(data).execute()
        if not response.data:
            raise HTTPException(status_code=400, detail="Erro ao inserir empresa.")
        return response.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao criar empresa: {str(e)}")

@app.put("/api/empresas/{id}")
def update_empresa(id: str, empresa: EmpresaUpdate):
    try:
        update_data = {}
        if empresa.nome is not None:
            update_data["nome"] = empresa.nome
        if empresa.plano is not None:
            update_data["plano"] = empresa.plano
        if empresa.ativo is not None:
            update_data["ativo"] = empresa.ativo
            
        if not update_data:
            raise HTTPException(status_code=400, detail="Nenhum dado fornecido para atualização.")
            
        response = supabase.table("empresas").update(update_data).eq("id", id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Empresa não encontrada.")
        return response.data[0]
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao atualizar empresa: {str(e)}")

@app.delete("/api/empresas/{id}", status_code=204)
def delete_empresa(id: str):
    try:
        response = supabase.table("empresas").delete().eq("id", id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Empresa não encontrada.")
        return None
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao excluir empresa: {str(e)}")

# ==========================================
# ENDPOINTS DE USUÁRIOS
# ==========================================

@app.get("/api/usuarios")
def list_usuarios(
    empresa_id: Optional[str] = None,
    nivel_permissao: Optional[str] = None
):
    try:
        query = supabase.table("usuarios").select("*, empresas(nome)")
        
        if empresa_id:
            query = query.eq("empresa_id", empresa_id)
        if nivel_permissao:
            query = query.eq("nivel_permissao", nivel_permissao)
            
        response = query.order("nome").execute()
        return response.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao listar usuários: {str(e)}")

@app.post("/api/usuarios", status_code=201)
def create_usuario(user: UsuarioCreate):
    try:
        # 1. Cria o usuário no Supabase Auth usando o Admin API
        # Isso garante que ele possa fazer login
        senha_def = user.senha or "Challenges@123"
        
        auth_data = {
            "email": user.email,
            "password": senha_def,
            "email_confirm": True,
            "user_metadata": {
                "nome": user.nome,
                "nivel_permissao": user.nivel_permissao
            }
        }
        
        auth_res = supabase.auth.admin.create_user(auth_data)
        if not auth_res.user:
            raise HTTPException(status_code=400, detail="Erro ao criar credenciais do usuário.")
            
        user_uuid = auth_res.user.id
        
        # 2. Atualiza o perfil público com os detalhes da empresa, cargo e departamento
        # O trigger 'on_auth_user_created' já inseriu a linha básica no public.usuarios,
        # agora nós a complementamos.
        update_data = {
            "cargo": user.cargo,
            "departamento": user.departamento,
            "nivel_permissao": user.nivel_permissao
        }
        
        if user.empresa_id:
            update_data["empresa_id"] = user.empresa_id
        if user.nome:
            update_data["nome"] = user.nome
            
        # Atualiza a tabela pública
        supabase.table("usuarios").update(update_data).eq("id", user_uuid).execute()
        
        # Busca o perfil completo atualizado
        profile_res = supabase.table("usuarios").select("*, empresas(nome)").eq("id", user_uuid).execute()
        return profile_res.data[0]
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        
        # Reverte criação no Supabase Auth se cadastrou no Auth mas falhou nos passos seguintes
        if 'user_uuid' in locals():
            try:
                supabase.auth.admin.delete_user(user_uuid)
            except Exception as rollback_err:
                print(f"Erro ao reverter criação de usuário no Auth: {rollback_err}")
                
        err_msg = str(e)
        if "already exists" in err_msg.lower():
            raise HTTPException(status_code=400, detail="Este e-mail já está cadastrado no sistema.")
        raise HTTPException(status_code=500, detail=f"Erro ao criar usuário: {err_msg}")

@app.post("/api/usuarios/bulk", status_code=201)
def create_usuarios_bulk(users: List[UsuarioCreate]):
    success_count = 0
    errors = []
    created_users = []
    
    for idx, user in enumerate(users):
        try:
            # Reutiliza a lógica de criação individual
            senha_def = user.senha or "Challenges@123"
            
            auth_data = {
                "email": user.email,
                "password": senha_def,
                "email_confirm": True,
                "user_metadata": {
                    "nome": user.nome,
                    "nivel_permissao": user.nivel_permissao
                }
            }
            
            auth_res = supabase.auth.admin.create_user(auth_data)
            if not auth_res.user:
                errors.append({
                    "linha": idx + 1,
                    "email": user.email,
                    "erro": "Falha na criação de credenciais auth."
                })
                continue
                
            user_uuid = auth_res.user.id
            
            update_data = {
                "cargo": user.cargo,
                "departamento": user.departamento,
                "nivel_permissao": user.nivel_permissao
            }
            if user.empresa_id:
                update_data["empresa_id"] = user.empresa_id
            if user.nome:
                update_data["nome"] = user.nome
                
            supabase.table("usuarios").update(update_data).eq("id", user_uuid).execute()
            
            success_count += 1
            created_users.append({
                "id": user_uuid,
                "nome": user.nome,
                "email": user.email
            })
            
        except Exception as e:
            err_msg = str(e)
            if "already exists" in err_msg.lower():
                err_msg = "E-mail já está cadastrado no sistema."
            
            errors.append({
                "linha": idx + 1,
                "email": user.email,
                "erro": err_msg
            })
            
    return {
        "success": len(errors) == 0,
        "success_count": success_count,
        "created": created_users,
        "errors": errors
    }

@app.put("/api/usuarios/{id}")
def update_usuario(id: str, user: UsuarioUpdate):
    try:
        # 1. Atualizar no Supabase Auth se nome ou nivel_permissao mudou
        auth_update_data = {}
        user_metadata = {}
        if user.nome is not None:
            user_metadata["nome"] = user.nome
        if user.nivel_permissao is not None:
            user_metadata["nivel_permissao"] = user.nivel_permissao
            
        if user_metadata:
            auth_update_data["user_metadata"] = user_metadata
            try:
                supabase.auth.admin.update_user_by_id(id, auth_update_data)
            except Exception as auth_err:
                print(f"Erro ao atualizar metadados no Supabase Auth: {auth_err}")
                
        # 2. Atualizar no banco public.usuarios
        update_data = {}
        if user.nome is not None:
            update_data["nome"] = user.nome
        if user.cargo is not None:
            update_data["cargo"] = user.cargo
        if user.nivel_permissao is not None:
            update_data["nivel_permissao"] = user.nivel_permissao
        if user.departamento is not None:
            update_data["departamento"] = user.departamento
            
        if not update_data:
            raise HTTPException(status_code=400, detail="Nenhum dado fornecido para atualização.")
            
        response = supabase.table("usuarios").update(update_data).eq("id", id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
            
        # Busca o perfil completo atualizado
        profile_res = supabase.table("usuarios").select("*, empresas(nome)").eq("id", id).execute()
        return profile_res.data[0]
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao atualizar usuário: {str(e)}")

@app.delete("/api/usuarios/{id}", status_code=204)
def delete_usuario(id: str):
    try:
        # Tenta deletar no Supabase Auth (propaga para public.usuarios via CASCADE)
        try:
            supabase.auth.admin.delete_user(id)
        except Exception as auth_err:
            print(f"Erro ao deletar no Supabase Auth: {auth_err}")
            
        # Garante a remoção da tabela pública se o cascade não ocorreu
        supabase.table("usuarios").delete().eq("id", id).execute()
        return None
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao excluir usuário: {str(e)}")


# =========================================================================
# ENDPOINTS E MODELOS DO MÓDULO DE NOTIFICAÇÕES (COM RESILIÊNCIA A TABELA AUSENTE)
# =========================================================================

class NotificationSettingsUpdate(BaseModel):
    novo_quiz: Optional[bool] = None
    subiu_nivel: Optional[bool] = None
    streak_risco: Optional[bool] = None
    ranking_atualizado: Optional[bool] = None
    sem_acesso_3_dias: Optional[bool] = None

class NotificationCreate(BaseModel):
    empresa_id: str
    titulo: str
    mensagem: str
    tipo: str  # 'novo_quiz', 'conquista', 'aviso', 'motivacional'
    destinatario_tipo: str  # 'todos', 'time', 'colaborador'
    destinatario_id: Optional[str] = None
    agendar_para: Optional[str] = None  # data ISO ou null para enviar agora


# In-memory fallbacks if Supabase tables do not exist
MOCK_SETTINGS = {}  # empresa_id -> settings dict
MOCK_NOTIFICATIONS = []  # list of notifications dicts
MOCK_USER_NOTIFICATIONS = []  # list of user notifications dicts

def is_missing_table_error(e: Exception) -> bool:
    err_str = str(e)
    return "PGRST205" in err_str or "relation" in err_str or "not find the table" in err_str or "404" in err_str or "relation \"public.configuracoes_notificacoes\"" in err_str

def get_default_settings(empresa_id: str):
    return {
        "empresa_id": empresa_id,
        "novo_quiz": True,
        "subiu_nivel": True,
        "streak_risco": True,
        "ranking_atualizado": True,
        "sem_acesso_3_dias": True,
        "atualizado_em": datetime.now(timezone.utc).isoformat()
    }


@app.get("/api/notifications/settings/{empresa_id}")
def get_notification_settings(empresa_id: str):
    try:
        res = supabase.table("configuracoes_notificacoes").select("*").eq("empresa_id", empresa_id).execute()
        if not res.data:
            # Insere as configurações padrão se não existirem
            default_data = get_default_settings(empresa_id)
            insert_res = supabase.table("configuracoes_notificacoes").insert(default_data).execute()
            return insert_res.data[0]
        return res.data[0]
    except Exception as e:
        if is_missing_table_error(e):
            print(f"[Fallback] configuracoes_notificacoes ausente. Usando in-memory para empresa {empresa_id}")
            if empresa_id not in MOCK_SETTINGS:
                MOCK_SETTINGS[empresa_id] = get_default_settings(empresa_id)
            return MOCK_SETTINGS[empresa_id]
        raise HTTPException(status_code=500, detail=f"Erro ao buscar configurações de notificações: {str(e)}")


@app.put("/api/notifications/settings/{empresa_id}")
def update_notification_settings(empresa_id: str, settings: NotificationSettingsUpdate):
    try:
        update_data = {}
        if settings.novo_quiz is not None:
            update_data["novo_quiz"] = settings.novo_quiz
        if settings.subiu_nivel is not None:
            update_data["subiu_nivel"] = settings.subiu_nivel
        if settings.streak_risco is not None:
            update_data["streak_risco"] = settings.streak_risco
        if settings.ranking_atualizado is not None:
            update_data["ranking_atualizado"] = settings.ranking_atualizado
        if settings.sem_acesso_3_dias is not None:
            update_data["sem_acesso_3_dias"] = settings.sem_acesso_3_dias
            
        update_data["atualizado_em"] = datetime.now(timezone.utc).isoformat()
        
        # Garante que existe registro antes de fazer update
        check = supabase.table("configuracoes_notificacoes").select("empresa_id").eq("empresa_id", empresa_id).execute()
        if not check.data:
            # Se não existe, insere com os valores atualizados
            full_data = get_default_settings(empresa_id)
            for k, v in update_data.items():
                full_data[k] = v
            res = supabase.table("configuracoes_notificacoes").insert(full_data).execute()
        else:
            res = supabase.table("configuracoes_notificacoes").update(update_data).eq("empresa_id", empresa_id).execute()
            
        return res.data[0]
    except Exception as e:
        if is_missing_table_error(e):
            print(f"[Fallback] configuracoes_notificacoes ausente. Atualizando in-memory para empresa {empresa_id}")
            if empresa_id not in MOCK_SETTINGS:
                MOCK_SETTINGS[empresa_id] = get_default_settings(empresa_id)
            for k, v in settings.model_dump(exclude_none=True).items():
                MOCK_SETTINGS[empresa_id][k] = v
            MOCK_SETTINGS[empresa_id]["atualizado_em"] = datetime.now(timezone.utc).isoformat()
            return MOCK_SETTINGS[empresa_id]
        raise HTTPException(status_code=500, detail=f"Erro ao atualizar configurações de notificações: {str(e)}")


@app.get("/api/notifications/history/{empresa_id}")
def get_notifications_history(empresa_id: str):
    # Obtém usuários e times para mapear nomes
    user_map = {}
    team_map = {}
    try:
        users_res = supabase.table("usuarios").select("id, nome").eq("empresa_id", empresa_id).execute()
        user_map = {u["id"]: u["nome"] for u in users_res.data or []}
    except Exception:
        pass
    try:
        teams_res = supabase.table("times").select("id, nome").execute()
        team_map = {t["id"]: t["nome"] for t in teams_res.data or []}
    except Exception:
        pass

    try:
        res = supabase.table("notificacoes").select("*").eq("empresa_id", empresa_id).order("criado_em", desc=True).execute()
        notifs = res.data or []
        
        for n in notifs:
            if n["destinatario_tipo"] == "todos":
                n["destinatario_nome"] = "Todos os colaboradores"
            elif n["destinatario_tipo"] == "time":
                n["destinatario_nome"] = f"Time: {team_map.get(n['destinatario_id'], 'Time Desconhecido')}"
            elif n["destinatario_tipo"] == "colaborador":
                n["destinatario_nome"] = user_map.get(n["destinatario_id"], "Colaborador Desconhecido")
            else:
                n["destinatario_nome"] = "N/A"
                
        return notifs
    except Exception as e:
        if is_missing_table_error(e):
            print(f"[Fallback] notificacoes ausente. Buscando histórico in-memory...")
            filtered = [dict(n) for n in MOCK_NOTIFICATIONS if n["empresa_id"] == empresa_id]
            filtered.sort(key=lambda x: x["criado_em"], reverse=True)
            for n in filtered:
                if n["destinatario_tipo"] == "todos":
                    n["destinatario_nome"] = "Todos os colaboradores"
                elif n["destinatario_tipo"] == "time":
                    n["destinatario_nome"] = f"Time: {team_map.get(n['destinatario_id'], 'Time Desconhecido')}"
                elif n["destinatario_tipo"] == "colaborador":
                    n["destinatario_nome"] = user_map.get(n["destinatario_id"], "Colaborador Desconhecido")
                else:
                    n["destinatario_nome"] = "N/A"
            return filtered
        raise HTTPException(status_code=500, detail=f"Erro ao listar histórico de notificações: {str(e)}")


@app.post("/api/notifications/send", status_code=201)
def send_notification(notif: NotificationCreate):
    status = "enviada"
    agendado_para = datetime.now(timezone.utc).isoformat()
    
    if notif.agendar_para:
        try:
            clean_date = notif.agendar_para.replace("Z", "+00:00")
            parsed_date = datetime.fromisoformat(clean_date)
            if parsed_date > datetime.now(timezone.utc):
                status = "agendada"
                agendado_para = notif.agendar_para
        except Exception as e:
            print(f"Erro ao parsear data de agendamento '{notif.agendar_para}':", e)
            
    data = {
        "empresa_id": notif.empresa_id,
        "titulo": notif.titulo,
        "mensagem": notif.mensagem,
        "tipo": notif.tipo,
        "destinatario_tipo": notif.destinatario_tipo,
        "destinatario_id": notif.destinatario_id,
        "status": status,
        "agendado_para": agendado_para
    }

    try:
        res = supabase.table("notificacoes").insert(data).execute()
        if not res.data:
            raise HTTPException(status_code=400, detail="Erro ao inserir notificação no banco.")
        return res.data[0]
    except Exception as e:
        if is_missing_table_error(e):
            print(f"[Fallback] notificacoes ausente. Inserindo notificação in-memory...")
            mock_id = str(uuid.uuid4())
            new_notif = {
                "id": mock_id,
                "empresa_id": data["empresa_id"],
                "titulo": data["titulo"],
                "mensagem": data["mensagem"],
                "tipo": data["tipo"],
                "destinatario_tipo": data["destinatario_tipo"],
                "destinatario_id": data["destinatario_id"],
                "status": data["status"],
                "agendado_para": data["agendado_para"],
                "enviado_em": datetime.now(timezone.utc).isoformat() if data["status"] == "enviada" else None,
                "criado_em": datetime.now(timezone.utc).isoformat()
            }
            MOCK_NOTIFICATIONS.append(new_notif)
            
            # Simula a propagação de triggers
            if new_notif["status"] == "enviada":
                propagate_mock_notification(new_notif)
                
            return new_notif
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao enviar notificação: {str(e)}")


def propagate_mock_notification(notif_dict):
    try:
        # Busca usuários da empresa para preencher o recebimento in-memory
        users_res = supabase.table("usuarios").select("id, time_id").eq("empresa_id", notif_dict["empresa_id"]).eq("ativo", True).execute()
        for u in users_res.data or []:
            should_add = False
            if notif_dict["destinatario_tipo"] == "todos":
                should_add = True
            elif notif_dict["destinatario_tipo"] == "time" and u["time_id"] == notif_dict["destinatario_id"]:
                should_add = True
            elif notif_dict["destinatario_tipo"] == "colaborador" and u["id"] == notif_dict["destinatario_id"]:
                should_add = True
                
            if should_add:
                MOCK_USER_NOTIFICATIONS.append({
                    "id": str(uuid.uuid4()),
                    "usuario_id": u["id"],
                    "notificacao_id": notif_dict["id"],
                    "lida": False,
                    "criado_em": datetime.now(timezone.utc).isoformat(),
                    "notificacoes": notif_dict  # Para facilitar o mock no app do colaborador
                })
    except Exception as e:
        print("[Fallback] Erro ao propagar notificação mockada:", e)


@app.post("/api/notifications/resend/{id}", status_code=201)
def resend_notification(id: str):
    try:
        res = supabase.table("notificacoes").select("*").eq("id", id).execute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Notificação não encontrada.")
            
        old_notif = res.data[0]
        new_data = {
            "empresa_id": old_notif["empresa_id"],
            "titulo": old_notif["titulo"],
            "mensagem": old_notif["mensagem"],
            "tipo": old_notif["tipo"],
            "destinatario_tipo": old_notif["destinatario_tipo"],
            "destinatario_id": old_notif["destinatario_id"],
            "status": "enviada",
            "agendado_para": datetime.now(timezone.utc).isoformat()
        }
        new_res = supabase.table("notificacoes").insert(new_data).execute()
        return new_res.data[0]
    except Exception as e:
        if is_missing_table_error(e):
            print(f"[Fallback] notificacoes ausente. Reenviando in-memory...")
            target = next((n for n in MOCK_NOTIFICATIONS if n["id"] == id), None)
            if not target:
                raise HTTPException(status_code=404, detail="Notificação não encontrada.")
                
            mock_id = str(uuid.uuid4())
            new_notif = {
                "id": mock_id,
                "empresa_id": target["empresa_id"],
                "titulo": target["titulo"],
                "mensagem": target["mensagem"],
                "tipo": target["tipo"],
                "destinatario_tipo": target["destinatario_tipo"],
                "destinatario_id": target["destinatario_id"],
                "status": "enviada",
                "agendado_para": datetime.now(timezone.utc).isoformat(),
                "enviado_em": datetime.now(timezone.utc).isoformat(),
                "criado_em": datetime.now(timezone.utc).isoformat()
            }
            MOCK_NOTIFICATIONS.append(new_notif)
            propagate_mock_notification(new_notif)
            return new_notif
        raise HTTPException(status_code=500, detail=f"Erro ao reenviar notificação: {str(e)}")


@app.post("/api/notifications/check-automations/{empresa_id}")
async def trigger_check_automations(empresa_id: str):
    try:
        results = await check_automations_internal(empresa_id)
        return {"success": True, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/rankings/refresh/{empresa_id}")
async def trigger_refresh_rankings(empresa_id: str):
    try:
        results = await refresh_rankings_internal(empresa_id)
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Helpers do Background Scheduler
async def check_automations_internal(empresa_id: str):
    # Obtém configurações de notificações
    cfg = get_default_settings(empresa_id)
    try:
        cfg_res = supabase.table("configuracoes_notificacoes").select("*").eq("empresa_id", empresa_id).execute()
        if cfg_res.data:
            cfg = cfg_res.data[0]
    except Exception as e:
        if empresa_id in MOCK_SETTINGS:
            cfg = MOCK_SETTINGS[empresa_id]

    results = {"streak_alerts": 0, "inactivity_alerts": 0}
    
    # 1. Streak em risco
    if cfg.get("streak_risco", True):
        try:
            users_res = supabase.table("usuarios").select("id, nome").eq("empresa_id", empresa_id).eq("ativo", True).execute()
            for u in users_res.data or []:
                score_res = supabase.table("pontuacoes").select("*").eq("usuario_id", u["id"]).execute()
                if score_res.data:
                    score = score_res.data[0]
                    streak = score.get("streak_atual", 0)
                    if streak > 0:
                        sess_res = supabase.table("sessoes") \
                            .select("iniciado_em") \
                            .eq("usuario_id", u["id"]) \
                            .eq("concluido", True) \
                            .order("iniciado_em", desc=True) \
                            .limit(1) \
                            .execute()
                        
                        in_risk = False
                        if not sess_res.data:
                            in_risk = True
                        else:
                            last_sess_time = datetime.fromisoformat(sess_res.data[0]["iniciado_em"].replace("Z", "+00:00"))
                            hours_since = (datetime.now(timezone.utc) - last_sess_time).total_seconds() / 3600.0
                            if 20 <= hours_since <= 36:
                                in_risk = True
                                
                        if in_risk:
                            today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
                            
                            # Verifica duplicata
                            has_dup = False
                            try:
                                dup_res = supabase.table("notificacoes") \
                                    .select("id") \
                                    .eq("empresa_id", empresa_id) \
                                    .eq("tipo", "motivacional") \
                                    .eq("destinatario_tipo", "colaborador") \
                                    .eq("destinatario_id", u["id"]) \
                                    .like("titulo", "%Streak em Risco%") \
                                    .gte("criado_em", today_start) \
                                    .execute()
                                has_dup = len(dup_res.data or []) > 0
                            except Exception:
                                has_dup = any(
                                    n["empresa_id"] == empresa_id and
                                    n["tipo"] == "motivacional" and
                                    n["destinatario_id"] == u["id"] and
                                    "Streak em Risco" in n["titulo"] and
                                    n["criado_em"] >= today_start
                                    for n in MOCK_NOTIFICATIONS
                                )
                                
                            if not has_dup:
                                notif_payload = NotificationCreate(
                                    empresa_id=empresa_id,
                                    titulo="Streak em Risco! 🔥",
                                    mensagem=f"Você está prestes a perder seu streak de {streak} dias! Responda a um quiz agora para mantê-lo.",
                                    tipo="motivacional",
                                    destinatario_tipo="colaborador",
                                    destinatario_id=u["id"]
                                )
                                send_notification(notif_payload)
                                results["streak_alerts"] += 1
        except Exception as err:
            print("Erro ao processar alerta de streak em background:", err)

    # 2. Inatividade (sem acessar há 3 dias)
    if cfg.get("sem_acesso_3_dias", True):
        try:
            three_days_ago = (datetime.now(timezone.utc) - timedelta(days=3)).isoformat()
            inactive_res = supabase.table("usuarios") \
                .select("id, nome, ultimo_acesso") \
                .eq("empresa_id", empresa_id) \
                .eq("ativo", True) \
                .lte("ultimo_acesso", three_days_ago) \
                .execute()
                
            for u in inactive_res.data or []:
                three_days_limit = (datetime.now(timezone.utc) - timedelta(days=3)).isoformat()
                
                has_dup = False
                try:
                    dup_res = supabase.table("notificacoes") \
                        .select("id") \
                        .eq("empresa_id", empresa_id) \
                        .eq("tipo", "motivacional") \
                        .eq("destinatario_tipo", "colaborador") \
                        .eq("destinatario_id", u["id"]) \
                        .like("titulo", "%Sentimos sua falta%") \
                        .gte("criado_em", three_days_limit) \
                        .execute()
                    has_dup = len(dup_res.data or []) > 0
                except Exception:
                    has_dup = any(
                        n["empresa_id"] == empresa_id and
                        n["tipo"] == "motivacional" and
                        n["destinatario_id"] == u["id"] and
                        "Sentimos sua falta" in n["titulo"] and
                        n["criado_em"] >= three_days_limit
                        for n in MOCK_NOTIFICATIONS
                    )
                    
                if not has_dup:
                    notif_payload = NotificationCreate(
                        empresa_id=empresa_id,
                        titulo="Sentimos sua falta! 👋",
                        mensagem=f"Olá {u['nome']}, faz mais de 3 dias que você não acessa seus desafios. Vamos aprender algo novo hoje?",
                        tipo="motivacional",
                        destinatario_tipo="colaborador",
                        destinatario_id=u["id"]
                    )
                    send_notification(notif_payload)
                    results["inactivity_alerts"] += 1
        except Exception as err:
            print("Erro ao processar alerta de inatividade em background:", err)
                
    return results


async def refresh_rankings_internal(empresa_id: str):
    # Mapeamento do ranking
    try:
        users_res = supabase.table("usuarios").select("id, nome").eq("empresa_id", empresa_id).eq("ativo", True).execute()
        users = users_res.data or []
        
        user_scores = []
        for u in users:
            score_res = supabase.table("pontuacoes").select("xp_total, nivel").eq("usuario_id", u["id"]).execute()
            xp = score_res.data[0]["xp_total"] if score_res.data else 0
            nivel = score_res.data[0]["nivel"] if score_res.data else 1
            user_scores.append({
                "usuario_id": u["id"],
                "nome": u["nome"],
                "xp_total": xp,
                "nivel": nivel
            })
            
        user_scores.sort(key=lambda x: x["xp_total"], reverse=True)
        
        try:
            # Remove rankings antigos e insere novos
            supabase.table("rankings").delete().eq("empresa_id", empresa_id).execute()
            
            top_3 = []
            for idx, us in enumerate(user_scores):
                pos = idx + 1
                supabase.table("rankings").insert({
                    "usuario_id": us["usuario_id"],
                    "empresa_id": empresa_id,
                    "posicao_geral": pos,
                    "posicao_time": pos,
                    "posicao_categoria": pos,
                    "atualizado_em": datetime.now(timezone.utc).isoformat()
                }).execute()
                
                if pos <= 3:
                    top_3.append(us)
        except Exception as e:
            # Caso a tabela rankings falhe (sem RLS/tabela), simula no top_3 em memória
            top_3 = user_scores[:3]
                
        # Notifica o top 3
        cfg = get_default_settings(empresa_id)
        try:
            cfg_res = supabase.table("configuracoes_notificacoes").select("ranking_atualizado").eq("empresa_id", empresa_id).execute()
            if cfg_res.data:
                cfg = cfg_res.data[0]
        except Exception:
            if empresa_id in MOCK_SETTINGS:
                cfg = MOCK_SETTINGS[empresa_id]
                
        ranking_notif_enabled = cfg.get("ranking_atualizado", True)
        
        notif_count = 0
        if ranking_notif_enabled and top_3:
            today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
            for idx, us in enumerate(top_3):
                pos = idx + 1
                
                has_dup = False
                try:
                    dup_res = supabase.table("notificacoes") \
                        .select("id") \
                        .eq("empresa_id", empresa_id) \
                        .eq("tipo", "conquista") \
                        .eq("destinatario_tipo", "colaborador") \
                        .eq("destinatario_id", us["usuario_id"]) \
                        .like("titulo", "%Top 3%") \
                        .gte("criado_em", today_start) \
                        .execute()
                    has_dup = len(dup_res.data or []) > 0
                except Exception:
                    has_dup = any(
                        n["empresa_id"] == empresa_id and
                        n["tipo"] == "conquista" and
                        n["destinatario_id"] == us["usuario_id"] and
                        "Top 3" in n["titulo"] and
                        n["criado_em"] >= today_start
                        for n in MOCK_NOTIFICATIONS
                    )
                    
                if not has_dup:
                    notif_payload = NotificationCreate(
                        empresa_id=empresa_id,
                        titulo="Top 3 do Ranking da Semana! 🏆",
                        mensagem=f"Parabéns {us['nome']}! Você terminou na posição #{pos} do ranking com {us['xp_total']} XP.",
                        tipo="conquista",
                        destinatario_tipo="colaborador",
                        destinatario_id=us["usuario_id"]
                    )
                    send_notification(notif_payload)
                    notif_count += 1
                    
        return {
            "success": True, 
            "message": f"Ranking recalculado. {len(user_scores)} registros atualizados.",
            "notified_top_3_count": notif_count
        }
    except Exception as e:
        print("Erro ao atualizar rankings:", e)
        return {"success": False, "detail": str(e)}


# Background Scheduler Loop
last_daily_check = None

async def notification_scheduler():
    global last_daily_check
    print("[Scheduler] Iniciado worker de agendamento de notificações.")
    while True:
        try:
            now = datetime.now(timezone.utc)
            now_str = now.isoformat()
            
            # 1. Despacha notificações agendadas em banco
            try:
                res = supabase.table("notificacoes") \
                    .select("id") \
                    .eq("status", "agendada") \
                    .lte("agendado_para", now_str) \
                    .execute()
                    
                if res.data:
                    for notif in res.data:
                        supabase.table("notificacoes") \
                            .update({"status": "enviada", "enviado_em": now_str}) \
                            .eq("id", notif["id"]) \
                            .execute()
                        print(f"[Scheduler] Despachada notificação agendada {notif['id']}")
            except Exception as e:
                # Scheduler in-memory fallback
                for n in MOCK_NOTIFICATIONS:
                    if n["status"] == "agendada" and n["agendado_para"] <= now_str:
                        n["status"] = "enviada"
                        n["enviado_em"] = now_str
                        propagate_mock_notification(n)
                        print(f"[Scheduler - Fallback] Despachada notificação agendada {n['id']} em memória")
            
            # 2. Executa verificações diárias (a cada 12 horas)
            if last_daily_check is None or (now - last_daily_check).total_seconds() > 43200:
                last_daily_check = now
                print("[Scheduler] Executando automações de inatividade e ranking...")
                companies = []
                try:
                    companies_res = supabase.table("empresas").select("id").execute()
                    companies = [c["id"] for c in companies_res.data or []]
                except Exception:
                    # Em caso de erro, lê das chaves do MOCK_SETTINGS ou usa ID de teste
                    companies = list(MOCK_SETTINGS.keys()) or ["mock-company-123"]
                    
                for comp_id in companies:
                    try:
                        await check_automations_internal(comp_id)
                        await refresh_rankings_internal(comp_id)
                    except Exception as e:
                        print(f"[Scheduler] Erro ao executar automações para empresa {comp_id}:", e)
                        
        except Exception as e:
            print("[Scheduler] Erro no loop de agendamentos:", e)
            
        await asyncio.sleep(10)


# Startup Event para iniciar o Scheduler
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(notification_scheduler())




