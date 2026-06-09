import os
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

class UsuarioCreate(BaseModel):
    nome: str
    email: str
    cargo: Optional[str] = None
    departamento: Optional[str] = None
    nivel_permissao: str = "colaborador"  # colaborador, gestor, admin
    empresa_id: Optional[str] = None     # ID da empresa (UUID)
    senha: Optional[str] = None          # Opcional, senha padrão se vazia

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
        # Se falhou e contiver mensagem amigável, reportamos
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
