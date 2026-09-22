import re
from uuid import UUID
from datetime import date, datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, EmailStr, Field, ConfigDict, field_validator


class AnamneseDermatologica(BaseModel):
    tipo_pele: Optional[str] = None  # Normal, Seca, Oleosa, Mista, Sensível
    fototipo_fitzpatrick: Optional[str] = None  # I, II, III, IV, V, VI
    alergias: List[str] = Field(default_factory=list)
    medicamentos_uso: List[str] = Field(default_factory=list)
    historico_cirurgico: Optional[str] = None
    queixa_principal: Optional[str] = None
    observacoes_tecnicas: Optional[str] = None
    contraindicacoes: List[str] = Field(default_factory=list)


class ClienteBase(BaseModel):
    nome: str = Field(min_length=2, max_length=255)
    telefone: str = Field(min_length=8, max_length=20)
    email: Optional[EmailStr] = None
    cpf: Optional[str] = None
    data_nascimento: Optional[date] = None
    anamnese: AnamneseDermatologica = Field(default_factory=AnamneseDermatologica)
    status: str = "ATIVO"

    @field_validator("email", mode="before")
    @classmethod
    def clean_email(cls, v: Any) -> Optional[str]:
        if v is None:
            return None
        s = str(v).strip()
        return s if s else None

    @field_validator("cpf", mode="before")
    @classmethod
    def clean_cpf(cls, v: Any) -> Optional[str]:
        if v is None:
            return None
        s = str(v).strip()
        if not s:
            return None
        digits = re.sub(r"\D", "", s)
        if len(digits) == 11:
            return f"{digits[:3]}.{digits[3:6]}.{digits[6:9]}-{digits[9:]}"
        return s[:14]

    @field_validator("data_nascimento", mode="before")
    @classmethod
    def clean_data_nascimento(cls, v: Any) -> Optional[date]:
        if v is None:
            return None
        if isinstance(v, (date, datetime)):
            return v if isinstance(v, date) else v.date()
        s = str(v).strip()
        if not s:
            return None
        try:
            if "/" in s:
                return datetime.strptime(s, "%d/%m/%Y").date()
            return datetime.strptime(s, "%Y-%m-%d").date()
        except ValueError:
            raise ValueError("Formato de data inválido. Utilize DD/MM/AAAA ou AAAA-MM-DD.")

    @field_validator("anamnese", mode="before")
    @classmethod
    def clean_anamnese(cls, v: Any) -> Any:
        if v is None:
            return AnamneseDermatologica()
        return v


class ClienteCreate(ClienteBase):
    pass


class ClienteUpdate(BaseModel):
    nome: Optional[str] = None
    telefone: Optional[str] = None
    email: Optional[EmailStr] = None
    cpf: Optional[str] = None
    data_nascimento: Optional[date] = None
    anamnese: Optional[AnamneseDermatologica] = None
    status: Optional[str] = None

    @field_validator("email", mode="before")
    @classmethod
    def clean_email(cls, v: Any) -> Optional[str]:
        if v is None:
            return None
        s = str(v).strip()
        return s if s else None

    @field_validator("cpf", mode="before")
    @classmethod
    def clean_cpf(cls, v: Any) -> Optional[str]:
        if v is None:
            return None
        s = str(v).strip()
        if not s:
            return None
        digits = re.sub(r"\D", "", s)
        if len(digits) == 11:
            return f"{digits[:3]}.{digits[3:6]}.{digits[6:9]}-{digits[9:]}"
        return s[:14]

    @field_validator("data_nascimento", mode="before")
    @classmethod
    def clean_data_nascimento(cls, v: Any) -> Optional[date]:
        if v is None:
            return None
        if isinstance(v, (date, datetime)):
            return v if isinstance(v, date) else v.date()
        s = str(v).strip()
        if not s:
            return None
        try:
            if "/" in s:
                return datetime.strptime(s, "%d/%m/%Y").date()
            return datetime.strptime(s, "%Y-%m-%d").date()
        except ValueError:
            raise ValueError("Formato de data inválido. Utilize DD/MM/AAAA ou AAAA-MM-DD.")


class ClienteResponse(ClienteBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
