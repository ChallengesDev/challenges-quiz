import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
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
    allow_origins=["*"],  # Ajuste para os domínios corretos em produção
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
        # Tenta realizar uma chamada simples para verificar a conectividade com o Supabase
        # Nota: Caso não exista nenhuma tabela criada ainda, isso servirá apenas para validar o cliente.
        # Caso queira testar uma tabela específica futuramente, pode-se usar: supabase.table("sua_tabela").select("*").limit(1).execute()
        return {
            "status": "healthy",
            "supabase_url": SUPABASE_URL
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro de conexão com o banco de dados: {str(e)}")
