from uuid import UUID
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from sqlalchemy.exc import IntegrityError

from app.api.deps import get_db, get_current_user
from app.models.entities import Cliente
from app.schemas.cliente import ClienteCreate, ClienteUpdate, ClienteResponse

router = APIRouter()


@router.get(
    "",
    response_model=List[ClienteResponse],
    summary="Listar ou buscar clientes da clínica",
    description="Permite buscar pacientes por nome, CPF ou telefone para vinculação rápida no PDV ou na ficha clínica."
)
async def listar_clientes(
    busca: Optional[str] = Query(None, description="Termo de busca por nome, CPF ou telefone"),
    incluir_inativos: bool = Query(False, description="Se deve incluir clientes inativados"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[ClienteResponse]:
    stmt = select(Cliente)
    if not incluir_inativos:
        stmt = stmt.where(Cliente.status == "ATIVO")

    if busca:
        termo = f"%{busca.strip()}%"
        stmt = stmt.where(
            or_(
                Cliente.nome.ilike(termo),
                Cliente.cpf.ilike(termo),
                Cliente.telefone.ilike(termo)
            )
        )
    stmt = stmt.order_by(Cliente.nome.asc()).limit(100)
    res = await db.execute(stmt)
    clientes = res.scalars().all()
    return [ClienteResponse.model_validate(c) for c in clientes]


@router.get(
    "/{cliente_id}",
    response_model=ClienteResponse,
    summary="Obter detalhes e anamnese de um cliente específico"
)
async def obter_cliente(
    cliente_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ClienteResponse:
    stmt = select(Cliente).where(Cliente.id == cliente_id)
    res = await db.execute(stmt)
    cliente = res.scalar_one_or_none()
    if not cliente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cliente {cliente_id} não encontrado."
        )
    return ClienteResponse.model_validate(cliente)


@router.post(
    "",
    response_model=ClienteResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar novo cliente com ficha de anamnese dermatológica (JSONB)"
)
async def criar_cliente(
    cliente_in: ClienteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ClienteResponse:
    # 1. Verificação prévia de duplicidade de CPF (caso informado)
    if cliente_in.cpf:
        stmt_check = select(Cliente).where(Cliente.cpf == cliente_in.cpf)
        res_check = await db.execute(stmt_check)
        if res_check.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Já existe um paciente cadastrado com o CPF {cliente_in.cpf}."
            )

    # 2. Extração segura da anamnese
    anamnese_dict = {}
    if cliente_in.anamnese:
        if hasattr(cliente_in.anamnese, "model_dump"):
            anamnese_dict = cliente_in.anamnese.model_dump()
        elif isinstance(cliente_in.anamnese, dict):
            anamnese_dict = cliente_in.anamnese

    novo_cliente = Cliente(
        nome=cliente_in.nome,
        telefone=cliente_in.telefone,
        email=cliente_in.email,
        cpf=cliente_in.cpf,
        data_nascimento=cliente_in.data_nascimento,
        anamnese=anamnese_dict,
        status=cliente_in.status
    )
    db.add(novo_cliente)
    try:
        await db.commit()
        await db.refresh(novo_cliente)
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Erro de integridade no banco: CPF ou documento já cadastrado."
        )
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Erro ao salvar dados do cliente: {str(e)}"
        )

    return ClienteResponse.model_validate(novo_cliente)


@router.put(
    "/{cliente_id}",
    response_model=ClienteResponse,
    summary="Atualizar dados de um cliente existente e/ou sua anamnese"
)
async def atualizar_cliente(
    cliente_id: UUID,
    cliente_in: ClienteUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ClienteResponse:
    stmt = select(Cliente).where(Cliente.id == cliente_id)
    res = await db.execute(stmt)
    cliente = res.scalar_one_or_none()
    if not cliente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cliente {cliente_id} não encontrado."
        )

    if cliente_in.nome is not None:
        cliente.nome = cliente_in.nome
    if cliente_in.telefone is not None:
        cliente.telefone = cliente_in.telefone
    if cliente_in.email is not None:
        cliente.email = cliente_in.email
    if cliente_in.cpf is not None:
        # Se alterou CPF, verifica duplicidade
        if cliente_in.cpf != cliente.cpf:
            stmt_cpf = select(Cliente).where(Cliente.cpf == cliente_in.cpf)
            res_cpf = await db.execute(stmt_cpf)
            if res_cpf.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Já existe outro paciente cadastrado com o CPF {cliente_in.cpf}."
                )
        cliente.cpf = cliente_in.cpf
    if cliente_in.data_nascimento is not None:
        cliente.data_nascimento = cliente_in.data_nascimento
    if cliente_in.status is not None:
        cliente.status = cliente_in.status
    if cliente_in.anamnese is not None:
        if hasattr(cliente_in.anamnese, "model_dump"):
            cliente.anamnese = cliente_in.anamnese.model_dump()
        elif isinstance(cliente_in.anamnese, dict):
            cliente.anamnese = cliente_in.anamnese

    try:
        await db.commit()
        await db.refresh(cliente)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Conflito de dados no banco de dados."
        )

    return ClienteResponse.model_validate(cliente)


@router.delete(
    "/{cliente_id}",
    status_code=status.HTTP_200_OK,
    summary="Inativar paciente (soft delete)"
)
async def inativar_cliente(
    cliente_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    stmt = select(Cliente).where(Cliente.id == cliente_id)
    res = await db.execute(stmt)
    cliente = res.scalar_one_or_none()
    if not cliente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cliente {cliente_id} não encontrado."
        )

    cliente.status = "INATIVO"
    await db.commit()
    return {"message": "Paciente inativado com sucesso.", "id": str(cliente_id)}
