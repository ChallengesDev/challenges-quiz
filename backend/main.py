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

# Configura o Gemini API
import google.generativeai as genai
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

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

class PerguntaBulkItem(BaseModel):
    texto: str
    alternativa_a: str
    alternativa_b: str
    alternativa_c: str
    alternativa_d: str
    resposta_correta: str
    explicacao: Optional[str] = None

class PerguntaBulkRequest(BaseModel):
    perguntas: List[PerguntaBulkItem]
    dificuldade: Optional[str] = None
    tempo_limite: Optional[int] = None
    pontuacao: Optional[int] = None

class GerarPerguntasRequest(BaseModel):
    tema: str
    quantidade: int
    dificuldade: str
    contexto: Optional[str] = None

class GerarTreinaMaisRequest(BaseModel):
    tema: str
    quantidade: int = 10
    contexto: Optional[str] = None

class TreinaMaisItemBulk(BaseModel):
    tipo: str
    texto_dica: Optional[str] = None
    pergunta: Optional[str] = None
    alternativas: Optional[List[str]] = None
    resposta_correta: Optional[str] = None
    explicacao: Optional[str] = None
    categoria_id: Optional[str] = None
    criado_por: str = "ia"

class TreinaMaisBulkRequest(BaseModel):
    empresa_id: str
    itens: List[TreinaMaisItemBulk]

class ResponderPerguntaTreinaMaisRequest(BaseModel):
    usuario_id: str
    conteudo_id: str
    resposta_usuario: str


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

@app.post("/api/desafios/{desafio_id}/perguntas/bulk", status_code=201)
def import_perguntas_bulk(desafio_id: str, request: PerguntaBulkRequest):
    try:
        # Validar se desafio_id é um UUID válido (para suportar IDs mockados do frontend)
        try:
            uuid.UUID(desafio_id)
            is_valid_uuid = True
        except ValueError:
            is_valid_uuid = False

        # 1. Opcionalmente atualizar o desafio
        update_data = {}
        if request.dificuldade:
            dificuldade_lower = request.dificuldade.lower().strip()
            # Remover acentos comuns se houver
            dificuldade_lower = dificuldade_lower.replace('fácil', 'facil').replace('médio', 'medio').replace('difícil', 'dificil')
            if dificuldade_lower in ['facil', 'medio', 'dificil']:
                update_data["dificuldade"] = dificuldade_lower
        if request.tempo_limite is not None and request.tempo_limite > 0:
            update_data["tempo_limite"] = request.tempo_limite
        if request.pontuacao is not None and request.pontuacao >= 0:
            update_data["pontuacao"] = request.pontuacao
        
        if update_data and is_valid_uuid:
            supabase.table("desafios").update(update_data).eq("id", desafio_id).execute()
        
        # 2. Preparar as perguntas para inserção
        perguntas_to_insert = []
        for p in request.perguntas:
            resposta = p.resposta_correta.upper().strip()
            if resposta not in ['A', 'B', 'C', 'D']:
                continue
            
            perguntas_to_insert.append({
                "desafio_id": desafio_id,
                "texto": p.texto.strip(),
                "alternativa_a": p.alternativa_a.strip(),
                "alternativa_b": p.alternativa_b.strip(),
                "alternativa_c": p.alternativa_c.strip(),
                "alternativa_d": p.alternativa_d.strip(),
                "resposta_correta": resposta,
                "explicacao": p.explicacao.strip() if p.explicacao else None
            })
        
        if not perguntas_to_insert:
            return {
                "success": True,
                "success_count": 0,
                "message": "Nenhuma pergunta válida para inserir."
            }
        
        if not is_valid_uuid:
            print(f"Alerta: desafio_id '{desafio_id}' não é um UUID válido. Simulando salvamento bulk com sucesso.")
            return {
                "success": True,
                "success_count": len(perguntas_to_insert),
                "message": f"[Modo de Teste] {len(perguntas_to_insert)} perguntas salvas localmente."
            }

        # 3. Bulk insert no Supabase
        response = supabase.table("perguntas").insert(perguntas_to_insert).execute()
        
        return {
            "success": True,
            "success_count": len(response.data) if response.data else len(perguntas_to_insert),
            "message": f"{len(perguntas_to_insert)} perguntas importadas com sucesso."
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao importar perguntas em lote: {str(e)}")

@app.post("/api/gerar-perguntas")
def gerar_perguntas(request: GerarPerguntasRequest):
    try:
        if not GEMINI_API_KEY:
            raise HTTPException(
                status_code=500,
                detail="A chave GEMINI_API_KEY não está configurada no backend."
            )
        
        prompt = f"""
Gere exatamente {request.quantidade} perguntas de múltipla escolha sobre o tema: "{request.tema}".
Dificuldade exigida: {request.dificuldade}.
{f'Contexto adicional / diretrizes: {request.contexto}' if request.contexto else ''}

Retorne um array JSON no formato exato:
[
  {{
    "pergunta": "Texto da pergunta?",
    "alternativa_a": "Texto da alternativa A",
    "alternativa_b": "Texto da alternativa B",
    "alternativa_c": "Texto da alternativa C",
    "alternativa_d": "Texto da alternativa D",
    "resposta_correta": "A",
    "dificuldade": "{request.dificuldade}",
    "explicacao": "Explicação curta sobre por que a alternativa A é a correta."
  }}
]

Regras importantes:
- Cada pergunta deve ter exatamente 4 alternativas (alternativa_a, alternativa_b, alternativa_c, alternativa_d).
- A chave "resposta_correta" deve ser estritamente uma única letra maiúscula entre 'A', 'B', 'C' ou 'D'.
- O campo "dificuldade" de cada item deve ser exatamente "{request.dificuldade}".
- O campo "explicacao" deve conter uma breve explicação fundamentada de por que a resposta é a correta.
- Não retorne nenhum outro texto explicativo antes ou depois do JSON. Retorne apenas o array JSON puro.
- Idioma: Português (Brasil).
"""
        
        try:
            model = genai.GenerativeModel("gemini-2.5-flash")
            response = model.generate_content(
                prompt,
                generation_config={"response_mime_type": "application/json"}
            )
            import json
            preguntas = json.loads(response.text)
        except Exception as api_err:
            print(f"Alerta: Falha na chamada da API do Gemini ({str(api_err)}). Usando gerador mock inteligente local.")
            
            # Gerador inteligente com base em palavras-chave do tema
            tema_lower = request.tema.lower()
            preguntas = []
            
            for idx in range(1, request.quantidade + 1):
                if "lgpd" in tema_lower or "dados" in tema_lower or "privacidade" in tema_lower:
                    if idx % 2 == 1:
                        preguntas.append({
                            "pergunta": f"De acordo com a LGPD, quem é o profissional responsável por intermediar a comunicação entre a empresa, os titulares e a ANPD?",
                            "alternativa_a": "O Operador de Dados.",
                            "alternativa_b": "O Controlador de Dados.",
                            "alternativa_c": "O Encarregado pelo Tratamento de Dados Pessoais (DPO).",
                            "alternativa_d": "O Auditor Interno de Conformidade.",
                            "resposta_correta": "C",
                            "dificuldade": request.dificuldade
                        })
                    else:
                        preguntas.append({
                            "pergunta": f"Qual destas bases legais da LGPD autoriza o tratamento de dados pessoais para prevenção de fraudes e segurança do titular?",
                            "alternativa_a": "Consentimento explícito e revogável do titular.",
                            "alternativa_b": "Cumprimento de obrigação legal ou regulatória pelo controlador.",
                            "alternativa_c": "Legítimo interesse do controlador, exceto quando prevalecerem direitos do titular.",
                            "alternativa_d": "Execução de políticas públicas previstas em leis e regulamentos.",
                            "resposta_correta": "C",
                            "dificuldade": request.dificuldade
                        })
                elif "segurança" in tema_lower or "phishing" in tema_lower or "senha" in tema_lower or "ataque" in tema_lower:
                    if idx % 2 == 1:
                        preguntas.append({
                            "pergunta": f"O que caracteriza um ataque de Phishing clássico na rede corporativa?",
                            "alternativa_a": "Invasão física ao servidor por meio de roubo de crachás.",
                            "alternativa_b": "Envio de e-mails falsos fingindo ser comunicações reais para roubar credenciais.",
                            "alternativa_c": "Instalação de programas espiões por meio de conexões USB infectadas.",
                            "alternativa_d": "Exploração de vulnerabilidades de portas de rede fechadas no firewall.",
                            "resposta_correta": "B",
                            "dificuldade": request.dificuldade
                        })
                    else:
                        preguntas.append({
                            "pergunta": f"Qual a melhor recomendação corporativa sobre a criação e uso de senhas de acesso?",
                            "alternativa_a": "Utilizar a mesma senha para sistemas pessoais e corporativos.",
                            "alternativa_b": "Anotar as senhas mais complexas em post-its colados no monitor.",
                            "alternativa_c": "Criar senhas fortes exclusivas e usar gerenciador de credenciais seguro.",
                            "alternativa_d": "Compartilhar credenciais apenas com colegas que pertencem ao mesmo departamento.",
                            "resposta_correta": "C",
                            "dificuldade": request.dificuldade
                        })
                else:
                    preguntas.append({
                        "pergunta": f"Questão simulada {idx} sobre {request.tema}: Qual das opções abaixo é a correta?",
                        "alternativa_a": f"Definição clara das diretrizes e conformidade do tema.",
                        "alternativa_b": f"Inconsistência operacional e aumento desnecessário de processos.",
                        "alternativa_c": f"Abordagem superficial sem impacto nos resultados corporativos.",
                        "alternativa_d": f"Ausência de controle e monitoramento periódico de métricas.",
                        "resposta_correta": "A",
                        "dificuldade": request.dificuldade
                    })
            
        return preguntas
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao gerar perguntas com IA: {str(e)}"
        )

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


def _gerar_mock_treina_mais(tema: str, quantidade: int) -> list:
    tema_lower = tema.lower()
    
    # Pre-canned items based on keywords
    mock_dicas = []
    mock_perguntas = []
    
    if "lgpd" in tema_lower or "dados" in tema_lower or "privacidade" in tema_lower:
        mock_dicas = [
            {
                "tipo": "dica",
                "texto_dica": "O consentimento sob a LGPD deve ser livre, informado e inequívoco. Isso significa que caixas pré-marcadas em formulários de aceite não são mais válidas!",
                "explicacao": "O usuário deve ativamente marcar a caixa indicando sua concordância com o tratamento de seus dados.",
                "criado_por": "ia"
            },
            {
                "tipo": "dica",
                "texto_dica": "Dados pessoais sensíveis (origem racial, convicção religiosa, dados de saúde, etc.) possuem regras muito mais rígidas para tratamento na LGPD.",
                "explicacao": "O tratamento desses dados exige consentimento específico e destacado do titular, exceto em hipóteses legais específicas.",
                "criado_por": "ia"
            },
            {
                "tipo": "dica",
                "texto_dica": "Em caso de vazamento de dados, a empresa deve comunicar a ANPD e os titulares afetados em tempo razoável, explicando os riscos envolvidos.",
                "explicacao": "A comunicação rápida ajuda a mitigar danos e é uma obrigação expressa no artigo 48 da LGPD.",
                "criado_por": "ia"
            }
        ]
        mock_perguntas = [
            {
                "tipo": "pergunta",
                "pergunta": "Quem é o encarregado de dados (DPO) segundo a LGPD?",
                "alternativas": [
                    "O profissional que executa diretamente o tratamento de dados no dia a dia.",
                    "O canal de comunicação entre o controlador, os titulares dos dados e a ANPD.",
                    "O representante legal da empresa perante a Receita Federal.",
                    "O profissional de TI que realiza o backup dos servidores da empresa."
                ],
                "resposta_correta": "O canal de comunicação entre o controlador, os titulares dos dados e a ANPD.",
                "explicacao": "O Encarregado pelo Tratamento de Dados Pessoais (DPO) atua como ponte de comunicação entre a organização, os titulares e o órgão regulador (ANPD).",
                "criado_por": "ia"
            },
            {
                "tipo": "pergunta",
                "pergunta": "O que são dados anonimizados perante a LGPD?",
                "alternativas": [
                    "Dados criptografados que podem ser descriptografados a qualquer momento.",
                    "Dados relativos a um titular que não possa ser identificado, considerando meios técnicos razoáveis.",
                    "Dados armazenados em servidores localizados fora do território nacional.",
                    "Dados compartilhados com parceiros comerciais de confiança."
                ],
                "resposta_correta": "Dados relativos a um titular que não possa ser identificado, considerando meios técnicos razoáveis.",
                "explicacao": "Se um dado perder a possibilidade de associação, direta ou indireta, a um indivíduo, ele é considerado anonimizado e não se submete à LGPD.",
                "criado_por": "ia"
            }
        ]
    elif "segurança" in tema_lower or "phishing" in tema_lower or "senha" in tema_lower or "ataque" in tema_lower:
        mock_dicas = [
            {
                "tipo": "dica",
                "texto_dica": "Sempre desconfie de links recebidos por e-mail com senso de urgência ('Sua conta será bloqueada hoje!'). Esse é o gatilho mental mais comum no Phishing.",
                "explicacao": "Os criminosos tentam apressar a vítima para que ela aja por impulso sem verificar a autenticidade do e-mail.",
                "criado_por": "ia"
            },
            {
                "tipo": "dica",
                "texto_dica": "A Autenticação de Dois Fatores (MFA) cria uma camada extra de segurança. Mesmo que alguém descubra sua senha, não conseguirá acessar sua conta sem o segundo fator.",
                "explicacao": "MFA reduz drasticamente a chance de invasões por vazamentos de senhas corporativas.",
                "criado_por": "ia"
            },
            {
                "tipo": "dica",
                "texto_dica": "Nunca compartilhe senhas corporativas nem use a mesma credencial em múltiplos serviços. Se um serviço sofrer vazamento, todas as suas contas estarão vulneráveis.",
                "explicacao": "A reutilização de senhas é uma das maiores brechas de segurança cibernética modernas.",
                "criado_por": "ia"
            }
        ]
        mock_perguntas = [
            {
                "tipo": "pergunta",
                "pergunta": "Você recebe um e-mail urgente da 'equipe de TI' pedindo sua senha para atualizar a conta. O que você deve fazer?",
                "alternativas": [
                    "Responder imediatamente enviando a senha para evitar bloqueios.",
                    "Enviar a senha mas pedir para eles alterarem logo depois.",
                    "Ignorar e reportar o e-mail à equipe de segurança oficial de TI.",
                    "Compartilhar o e-mail com todos os colegas de equipe perguntando o que fazer."
                ],
                "resposta_correta": "Ignorar e reportar o e-mail à equipe de segurança oficial de TI.",
                "explicacao": "Equipes de TI legítimas NUNCA solicitam senhas por e-mail. Este é um golpe clássico de Phishing/Engenharia Social.",
                "criado_por": "ia"
            },
            {
                "tipo": "pergunta",
                "pergunta": "Qual das seguintes opções descreve uma senha corporativa forte e recomendada?",
                "alternativas": [
                    "A data de nascimento do seu pet mais querido.",
                    "Uma frase longa e aleatória (passphrase) contendo números, letras e símbolos.",
                    "A palavra 'Senha123' que é fácil de memorizar e alterar.",
                    "O nome da sua empresa atual seguido do ano de contratação."
                ],
                "resposta_correta": "Uma frase longa e aleatória (passphrase) contendo números, letras e símbolos.",
                "explicacao": "Senhas longas baseadas em frases de fácil memorização pessoal combinadas com caracteres especiais são extremamente difíceis de quebrar por força bruta.",
                "criado_por": "ia"
            }
        ]
    else:
        # Default fallback items for any other topic
        mock_dicas = [
            {
                "tipo": "dica",
                "texto_dica": f"Para se aprimorar em {tema}, a prática constante e o alinhamento com a cultura interna são fundamentais para o sucesso corporativo.",
                "explicacao": "A capacitação contínua ajuda no crescimento pessoal e na melhoria dos indicadores organizacionais.",
                "criado_por": "ia"
            },
            {
                "tipo": "dica",
                "texto_dica": f"A clareza operacional sobre o tema {tema} reduz retrabalhos e minimiza falhas humanas nas rotinas diárias da equipe.",
                "explicacao": "Processos estruturados e documentados servem como base confiável para novos colaboradores.",
                "criado_por": "ia"
            }
        ]
        mock_perguntas = [
            {
                "tipo": "pergunta",
                "pergunta": f"Qual o principal benefício de dominar os conceitos básicos de {tema}?",
                "alternativas": [
                    "Aumento da produtividade e redução de riscos operacionais na empresa.",
                    "Automatização total de todas as decisões sem supervisão humana.",
                    "Eliminação completa de qualquer tipo de auditoria interna ou externa.",
                    "Diminuição dos canais de comunicação com outras áreas de apoio."
                ],
                "resposta_correta": "Aumento da produtividade e redução de riscos operacionais na empresa.",
                "explicacao": "O conhecimento aprofundado permite tomar decisões mais seguras, rápidas e eficientes no ambiente de trabalho.",
                "criado_por": "ia"
            }
        ]
        
    # Interleave to generate requested quantity
    resultado = []
    dica_idx = 0
    pergunta_idx = 0
    for i in range(quantidade):
        # alternate dica and pergunta
        if i % 2 == 0 and len(mock_dicas) > 0:
            item = mock_dicas[dica_idx % len(mock_dicas)].copy()
            dica_idx += 1
        elif len(mock_perguntas) > 0:
            item = mock_perguntas[pergunta_idx % len(mock_perguntas)].copy()
            pergunta_idx += 1
        else:
            item = mock_dicas[dica_idx % len(mock_dicas)].copy()
            dica_idx += 1
            
        # personalize fallback output if general
        if "{tema}" in item.get("texto_dica", ""):
            item["texto_dica"] = item["texto_dica"].replace("{tema}", tema)
        if "{tema}" in item.get("pergunta", ""):
            item["pergunta"] = item["pergunta"].replace("{tema}", tema)
        if "{tema}" in item.get("explicacao", ""):
            item["explicacao"] = item["explicacao"].replace("{tema}", tema)
            
        resultado.append(item)
        
    return resultado


@app.post("/api/treina-mais/gerar")
def gerar_treina_mais(request: GerarTreinaMaisRequest):
    try:
        if not GEMINI_API_KEY:
            print("Chave GEMINI_API_KEY não configurada. Usando mock generator.")
            return _gerar_mock_treina_mais(request.tema, request.quantidade)
            
        prompt = f"""
Gere exatamente {request.quantidade} cartões de aprendizagem rápida e engajadora sobre o tema: "{request.tema}".
{f'Diretrizes ou contexto adicional: {request.contexto}' if request.contexto else ''}

Esses cartões devem ser do tipo "dica" ou "pergunta" (intercale de forma dinâmica, visando um equilíbrio próximo de 50/50).
Retorne um array JSON no formato exato:
[
  {{
    "tipo": "dica",
    "texto_dica": "Texto curto e direto da dica (máximo 2 a 3 frases) com uma curiosidade ou insight valioso.",
    "explicacao": "Uma justificativa ou detalhe extra curto de 1 frase.",
    "criado_por": "ia"
  }},
  {{
    "tipo": "pergunta",
    "pergunta": "Texto da pergunta direta de múltipla escolha?",
    "alternativas": ["Opção A", "Opção B", "Opção C", "Opção D"],
    "resposta_correta": "Opção B",
    "explicacao": "Justificativa curta e direta de 1 frase explicando por que esta é a alternativa correta.",
    "criado_por": "ia"
  }}
]

Regras importantes:
- A propriedade "tipo" deve ser exatamente "dica" ou "pergunta".
- Para o tipo "dica", as propriedades "texto_dica" e "explicacao" são obrigatórias. "pergunta", "alternativas" e "resposta_correta" devem ser nulas.
- Para o tipo "pergunta", as propriedades "pergunta", "alternativas", "resposta_correta" e "explicacao" são obrigatórias. As "alternativas" devem ser uma lista com 2, 3 ou 4 opções de strings. E a "resposta_correta" deve ser a string exata correspondente a uma das opções do array de alternativas. "texto_dica" devem ser nulas.
- As dicas e perguntas devem ser dinâmicas, modernas, adequadas para leitura mobile no estilo Reels/TikTok (diretas, dinâmicas e engajadoras).
- Não retorne nenhum outro texto explicativo antes ou depois do JSON. Retorne apenas o array JSON puro.
- Idioma: Português (Brasil).
"""
        try:
            model = genai.GenerativeModel("gemini-2.5-flash")
            response = model.generate_content(
                prompt,
                generation_config={"response_mime_type": "application/json"}
            )
            import json
            itens = json.loads(response.text)
            return itens
        except Exception as api_err:
            print(f"Alerta: Falha na chamada da API do Gemini ({str(api_err)}). Usando gerador mock inteligente local.")
            return _gerar_mock_treina_mais(request.tema, request.quantidade)
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao gerar conteúdo Treina+ com IA: {str(e)}"
        )


@app.post("/api/treina-mais/bulk", status_code=201)
def bulk_inserir_treina_mais(request: TreinaMaisBulkRequest):
    try:
        to_insert = []
        for item in request.itens:
            # Garante que o tipo é válido
            tipo = item.tipo if item.tipo in ('dica', 'pergunta') else 'dica'
            
            # Se for categoria_id vazia ou nula, definir None
            cat_id = item.categoria_id if item.categoria_id else None
            
            data = {
                "empresa_id": request.empresa_id,
                "tipo": tipo,
                "categoria_id": cat_id,
                "texto_dica": item.texto_dica if tipo == 'dica' else None,
                "pergunta": item.pergunta if tipo == 'pergunta' else None,
                "alternativas": item.alternativas if tipo == 'pergunta' else None,
                "resposta_correta": item.resposta_correta if tipo == 'pergunta' else None,
                "explicacao": item.explicacao,
                "criado_por": item.criado_por if item.criado_por in ('gestor', 'ia') else 'ia',
                "ativo": True
            }
            to_insert.append(data)
            
        if to_insert:
            response = supabase.table("treina_mais_conteudo").insert(to_insert).execute()
            return {"status": "success", "inserted": len(to_insert), "data": response.data}
        return {"status": "success", "inserted": 0, "data": []}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao inserir conteúdo em lote: {str(e)}")


@app.get("/api/treina-mais/feed/{usuario_id}")
def obter_feed_treina_mais(usuario_id: str):
    try:
        # Busca o usuario
        user_res = supabase.table("usuarios").select("empresa_id").eq("id", usuario_id).execute()
        if not user_res.data:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        empresa_id = user_res.data[0]["empresa_id"]
        
        # Busca vistos
        seen_res = supabase.table("usuario_treina_mais_visto").select("conteudo_id").eq("usuario_id", usuario_id).execute()
        seen_ids = [s["conteudo_id"] for s in seen_res.data or []]
        
        # Busca todos os conteúdos ativos da empresa
        contents_res = supabase.table("treina_mais_conteudo").select("*, categorias(nome)").eq("empresa_id", empresa_id).eq("ativo", True).execute()
        all_contents = contents_res.data or []
        
        unseen = [c for c in all_contents if c["id"] not in seen_ids]
        seen = [c for c in all_contents if c["id"] in seen_ids]
        
        # Prioriza não vistos no feed
        feed = []
        for item in (unseen + seen):
            categoria_nome = None
            if item.get("categorias"):
                if isinstance(item["categorias"], dict):
                    categoria_nome = item["categorias"].get("nome")
                elif isinstance(item["categorias"], list) and len(item["categorias"]) > 0:
                    categoria_nome = item["categorias"][0].get("nome")
            
            feed.append({
                "id": item["id"],
                "empresa_id": item["empresa_id"],
                "tipo": item["tipo"],
                "categoria_id": item["categoria_id"],
                "categoria_nome": categoria_nome,
                "texto_dica": item["texto_dica"],
                "pergunta": item["pergunta"],
                "alternativas": item["alternativas"],
                "resposta_correta": item["resposta_correta"],
                "explicacao": item["explicacao"],
                "criado_por": item["criado_por"],
                "visto": item["id"] in seen_ids,
                "criado_em": item["criado_em"]
            })
            
        return feed
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao obter feed: {str(e)}")


@app.post("/api/treina-mais/ver/{usuario_id}/{conteudo_id}")
def registrar_visualizacao(usuario_id: str, conteudo_id: str):
    try:
        data = {
            "usuario_id": usuario_id,
            "conteudo_id": conteudo_id,
            "visto_em": datetime.now(timezone.utc).isoformat()
        }
        response = supabase.table("usuario_treina_mais_visto").upsert(data, on_conflict="usuario_id, conteudo_id").execute()
        return {"status": "success", "data": response.data}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao registrar visualização: {str(e)}")


@app.post("/api/treina-mais/pergunta/responder")
def responder_pergunta_treina_mais(request: ResponderPerguntaTreinaMaisRequest):
    try:
        # Busca o conteúdo para validar a resposta
        conteudo_res = supabase.table("treina_mais_conteudo").select("*").eq("id", request.conteudo_id).execute()
        if not conteudo_res.data:
            raise HTTPException(status_code=404, detail="Conteúdo não encontrado.")
        
        conteudo = conteudo_res.data[0]
        if conteudo["tipo"] != "pergunta":
            raise HTTPException(status_code=400, detail="Este conteúdo não é uma pergunta.")
            
        resposta_correta = conteudo["resposta_correta"]
        explicacao = conteudo["explicacao"]
        
        is_correct = request.resposta_usuario.strip() == resposta_correta.strip()
        
        xp_earned = 0
        if is_correct:
            import random
            xp_earned = random.randint(5, 15)
            
            # Atualiza pontuação
            score_res = supabase.table("pontuacoes").select("*").eq("usuario_id", request.usuario_id).execute()
            if score_res.data:
                curr = score_res.data[0]
                new_xp = curr["xp_total"] + xp_earned
                new_nivel = (new_xp // 500) + 1
                if new_nivel < curr["nivel"]:
                    new_nivel = curr["nivel"]
                supabase.table("pontuacoes").update({
                    "xp_total": new_xp,
                    "nivel": new_nivel
                }).eq("usuario_id", request.usuario_id).execute()
            else:
                supabase.table("pontuacoes").insert({
                    "usuario_id": request.usuario_id,
                    "xp_total": xp_earned,
                    "nivel": 1,
                    "streak_atual": 0,
                    "streak_maximo": 0
                }).execute()
        
        # Registra visualização (visto)
        visto_data = {
            "usuario_id": request.usuario_id,
            "conteudo_id": request.conteudo_id,
            "visto_em": datetime.now(timezone.utc).isoformat()
        }
        supabase.table("usuario_treina_mais_visto").upsert(visto_data, on_conflict="usuario_id, conteudo_id").execute()
        
        return {
            "correta": is_correct,
            "resposta_correta": resposta_correta,
            "xp_ganho": xp_earned,
            "explicacao": explicacao
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao responder pergunta: {str(e)}")


# --- DESAFIO RELÂMPAGO ---

DESAFIO_RELAMPAGO_CACHE = {}

class DesafioRelampagoCompletarRequest(BaseModel):
    usuario_id: str
    acertos: int
    total: int
    xp_ganho: int

@app.get("/api/desafio-relampago/{usuario_id}")
def obter_desafio_relampago(usuario_id: str):
    try:
        # 1. Determine status
        pont_res = supabase.table("pontuacoes").select("*").eq("usuario_id", usuario_id).execute()
        completado_em_str = None
        disponivel_val = True
        
        if pont_res.data:
            pont = pont_res.data[0]
            if "desafio_relampago_completado_em" in pont:
                completado_em_str = pont["desafio_relampago_completado_em"]
            if "desafio_relampago_disponivel" in pont:
                disponivel_val = pont["desafio_relampago_disponivel"]
        
        # If columns not in database, check in-memory cache
        if completado_em_str is None and usuario_id in DESAFIO_RELAMPAGO_CACHE:
            completado_em_str = DESAFIO_RELAMPAGO_CACHE[usuario_id].get("completado_em")
            disponivel_val = DESAFIO_RELAMPAGO_CACHE[usuario_id].get("disponivel", True)
            
        completado_hoje = False
        if completado_em_str:
            try:
                completado_em = datetime.fromisoformat(completado_em_str.replace("Z", "+00:00"))
                if completado_em.date() == datetime.now(timezone.utc).date():
                    completado_hoje = True
            except:
                pass

        # Check if completed at least 1 normal quiz today
        today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        sessoes_res = supabase.table("sessoes") \
            .select("id") \
            .eq("usuario_id", usuario_id) \
            .eq("concluido", True) \
            .gte("finalizado_em", today_start.isoformat()) \
            .execute()
        
        has_completed_normal_quiz = len(sessoes_res.data or []) >= 1
        
        status = "bloqueado"
        if completado_hoje:
            status = "completado"
        elif has_completed_normal_quiz:
            status = "disponivel"
            
        preguntas = []
        if status in ("disponivel", "completado"):
            # Lógica de seleção de perguntas
            thirty_days_ago = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
            
            user_sessoes_res = supabase.table("sessoes") \
                .select("id") \
                .eq("usuario_id", usuario_id) \
                .gte("iniciado_em", thirty_days_ago) \
                .execute()
            
            sess_ids = [s["id"] for s in user_sessoes_res.data or []]
            
            incorrect_q_ids = []
            if sess_ids:
                respostas_res = supabase.table("respostas") \
                    .select("pergunta_id") \
                    .in_("sessao_id", sess_ids) \
                    .eq("correta", False) \
                    .execute()
                incorrect_q_ids = list(set([r["pergunta_id"] for r in respostas_res.data or []]))
            
            questions_list = []
            if incorrect_q_ids:
                q_res = supabase.table("perguntas") \
                    .select("*, desafio:desafios(titulo, topico_id)") \
                    .in_("id", incorrect_q_ids) \
                    .execute()
                questions_list = q_res.data or []
            
            import random
            random.shuffle(questions_list)
            selected_questions = questions_list[:4]
            
            # Top-up if less than 3 incorrect questions
            if len(selected_questions) < 3:
                categoria_id = None
                last_sess_res = supabase.table("sessoes") \
                    .select("desafio_id") \
                    .eq("usuario_id", usuario_id) \
                    .order("iniciado_em", desc=True) \
                    .limit(1) \
                    .execute()
                
                if last_sess_res.data:
                    desafio_id = last_sess_res.data[0]["desafio_id"]
                    des_res = supabase.table("desafios").select("topico_id").eq("id", desafio_id).execute()
                    if des_res.data:
                        topico_id = des_res.data[0]["topico_id"]
                        top_res = supabase.table("topicos").select("categoria_id").eq("id", topico_id).execute()
                        if top_res.data:
                            categoria_id = top_res.data[0]["categoria_id"]
                
                if not categoria_id:
                    user_res = supabase.table("usuarios").select("empresa_id").eq("id", usuario_id).execute()
                    if user_res.data and user_res.data[0]["empresa_id"]:
                        empresa_id = user_res.data[0]["empresa_id"]
                        cat_res = supabase.table("categorias").select("id").eq("empresa_id", empresa_id).eq("ativo", True).limit(1).execute()
                        if cat_res.data:
                            categoria_id = cat_res.data[0]["id"]
                
                if categoria_id:
                    topics_res = supabase.table("topicos").select("id").eq("categoria_id", categoria_id).execute()
                    topic_ids = [t["id"] for t in topics_res.data or []]
                    
                    if topic_ids:
                        chals_res = supabase.table("desafios").select("id").in_("topico_id", topic_ids).execute()
                        chal_ids = [c["id"] for c in chals_res.data or []]
                        
                        if chal_ids:
                            all_q_res = supabase.table("perguntas") \
                                .select("*, desafio:desafios(titulo, topico_id)") \
                                .in_("desafio_id", chal_ids) \
                                .execute()
                            
                            category_questions = all_q_res.data or []
                            random.shuffle(category_questions)
                            
                            existing_ids = {q["id"] for q in selected_questions}
                            for q in category_questions:
                                if len(selected_questions) >= 4:
                                    break
                                if q["id"] not in existing_ids:
                                    selected_questions.append(q)
            
            topic_ids_to_resolve = list(set([q["desafio"]["topico_id"] for q in selected_questions if q.get("desafio")]))
            category_names = {}
            if topic_ids_to_resolve:
                t_res = supabase.table("topicos").select("id, categoria:categorias(nome)").in_("id", topic_ids_to_resolve).execute()
                for t in t_res.data or []:
                    if t.get("categoria"):
                        category_names[t["id"]] = t["categoria"]["nome"]
            
            for q in selected_questions:
                topico_id = q.get("desafio", {}).get("topico_id") if q.get("desafio") else None
                cat_name = category_names.get(topico_id, "Geral")
                
                preguntas.append({
                    "id": q["id"],
                    "texto": q["texto"],
                    "alternativas": [
                        q["alternativa_a"],
                        q["alternativa_b"],
                        q["alternativa_c"],
                        q["alternativa_d"]
                    ],
                    "resposta_correta": q["resposta_correta"],
                    "explicacao": q.get("explicacao"),
                    "categoria": cat_name,
                    "dificuldade": q.get("dificuldade", "facil")
                })
                
        return {
            "status": status,
            "perguntas": preguntas
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao obter desafio relâmpago: {str(e)}")

@app.post("/api/desafio-relampago/completar")
def completar_desafio_relampago(request: DesafioRelampagoCompletarRequest):
    try:
        now_str = datetime.now(timezone.utc).isoformat()
        
        pont_res = supabase.table("pontuacoes").select("*").eq("usuario_id", request.usuario_id).execute()
        
        if pont_res.data:
            pont = pont_res.data[0]
            update_data = {
                "xp_total": pont["xp_total"] + request.xp_ganho,
                "nivel": ((pont["xp_total"] + request.xp_ganho) // 500) + 1
            }
            if "desafio_relampago_completado_em" in pont:
                update_data["desafio_relampago_completado_em"] = now_str
            if "desafio_relampago_disponivel" in pont:
                update_data["desafio_relampago_disponivel"] = False
                
            supabase.table("pontuacoes").update(update_data).eq("usuario_id", request.usuario_id).execute()
        else:
            insert_data = {
                "usuario_id": request.usuario_id,
                "xp_total": request.xp_ganho,
                "nivel": 1,
                "streak_atual": 0,
                "streak_maximo": 0
            }
            supabase.table("pontuacoes").insert(insert_data).execute()
            
        DESAFIO_RELAMPAGO_CACHE[request.usuario_id] = {
            "completado_em": now_str,
            "disponivel": False
        }
        
        return {"status": "success", "message": "Desafio relâmpago registrado com sucesso!"}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Erro ao registrar conclusão do desafio relâmpago: {str(e)}")


ONBOARDING_CACHE = {}

@app.get("/api/usuarios/{usuario_id}/onboarding")
def obter_onboarding_status(usuario_id: str):
    try:
        res = supabase.table("usuarios").select("onboarding_completo").eq("id", usuario_id).execute()
        if res.data:
            val = res.data[0].get("onboarding_completo", False)
            return {"onboarding_completo": bool(val)}
    except Exception as e:
        print(f"Erro ao buscar onboarding_completo no banco (possivelmente coluna nao existe): {e}")
    
    val = ONBOARDING_CACHE.get(usuario_id, False)
    return {"onboarding_completo": val}

@app.post("/api/usuarios/{usuario_id}/onboarding")
def atualizar_onboarding_status(usuario_id: str, payload: dict):
    onboarding_val = payload.get("onboarding_completo", True)
    
    db_success = False
    try:
        res = supabase.table("usuarios").update({"onboarding_completo": onboarding_val}).eq("id", usuario_id).execute()
        if res.data:
            db_success = True
    except Exception as e:
        print(f"Erro ao salvar onboarding_completo no banco: {e}")
    
    ONBOARDING_CACHE[usuario_id] = onboarding_val
    return {"success": True, "db_saved": db_success, "onboarding_completo": onboarding_val}


# Startup Event para iniciar o Scheduler
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(notification_scheduler())




