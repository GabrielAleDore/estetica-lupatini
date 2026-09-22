import asyncio
from sqlalchemy import text
from app.core.database import engine

async def check_db():
    try:
        async with engine.connect() as conn:
            query = text("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name")
            res = await conn.execute(query)
            tables = [r[0] for r in res.fetchall()]
            print("TABELAS_NO_BANCO:", tables)
            
            for t in ["produtos", "servicos", "clientes", "contas_cartoes"]:
                if t in tables:
                    count = (await conn.execute(text(f"SELECT COUNT(*) FROM {t}"))).scalar()
                    print(f"TABELA '{t}': {count} registros")
                else:
                    print(f"TABELA '{t}': NAO EXISTE")
    except Exception as e:
        print("ERRO_AO_CONSULTAR_BANCO:", type(e), e)

if __name__ == "__main__":
    asyncio.run(check_db())
