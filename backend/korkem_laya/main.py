# Copyright (c) 2026, KORKEM Flow and contributors
# Fast System 1 Decision Microservice based on Laya (Convai Innovations)
"""
Korkem Laya Microservice:
High-speed System 1 decision engine for KORKEM Flow ERP.
Performs semantic domain routing, tool pruning, and customer intent classification
locally in single-forward-pass inference without external token consumption.
"""

from __future__ import annotations

import os
import time
import threading
import logging
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("korkem_laya")

# Global router and lock for thread-safe inference
_router: Any = None
_router_lock = threading.Lock()
_start_time = time.time()

# Domain taxonomy for KORKEM furniture manufacturing
DOMAIN_TAXONOMY = {
    "inventory": "Склад, остатки, материалы, ЛДСП, кромка, фурнитура, резервы, қойма, материалдар, қалдық",
    "manufacturing": "Производство, цех, распил, кромление, присадка, раскрой, станки, ЧПУ, смены, өндіріс, станок",
    "sales": "Заказы клиентов, продажи, КП, коммерческие предложения, договоры, оплаты, баға, төлем, тапсырыс",
    "procurement": "Закупки, поставщики, приходные накладные, заказы поставщикам, жеткізушілер",
    "dispatch": "Доставка, отгрузка клиенту, монтаж мебели, установка, логистика, жеткізу, орнату",
    "chain": "Замер, дизайн-проект, конструктор, технолог, чертеж Базис, спецификация, өлшеу, жоба",
    "tasks": "Задачи сотрудников, поручения, дедлайны, просрочки, тапсырмалар",
    "finance": "Финансы, зарплата цеха, сдельная оплата, касса, баланс, выплаты",
    "profile": "Приветствия, благодарности, общие вопросы, кто ты, мои права, сәлем, рахмет"
}

# Domain questions schema for Laya Router
ROUTING_QUESTIONS = {
    "domain": {
        "type": "choice",
        "instructions": "К какой категории мебельного производства относится этот запрос?",
        "criteria": DOMAIN_TAXONOMY
    },
    "needs_tools": {
        "type": "noul",
        "instructions": "Требуются ли вызовы инструментов ERP/базы данных для ответа на этот запрос? (ложь для приветствий и простой вежливости)",
        "criteria": {
            "true": "Вопрос требует проверки склада, заказов, статусов, цен или документов ERP",
            "false": "Простое приветствие, благодарность, шутка или вежливый разговор"
        }
    }
}

CUSTOMER_INTENT_QUESTIONS = {
    "intent": {
        "type": "choice",
        "instructions": "Каково основное намерение клиента мебельной фабрики?",
        "criteria": {
            "new_order_inquiry": "Клиент хочет заказать мебель, узнать цену, сделать расчет или вызвать замерщика",
            "order_status": "Клиент спрашивает о статусе уже сделанного ранее заказа или дате готовности",
            "general_question": "Общий вопрос о графике работы, адресе салона, материалах или гарантии",
            "other": "Приветствие без запроса, спам или не относящееся к мебели сообщение"
        }
    }
}


def load_laya_router():
    """Load and initialize Laya router with multilingual checkpoint."""
    global _router
    try:
        import laya
        logger.info("Initializing Laya Router (multilingual only)...")
        router = laya.Router(preload=False, default="multilingual")
        router.preload(names=["multilingual"])
        _router = router
        logger.info("Laya Router (multilingual) successfully loaded and ready.")
    except Exception as exc:
        logger.warning(f"Laya preloading failed (will retry lazily or use rules): {exc}")
        _router = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: preload model in background or synchronously
    threading.Thread(target=load_laya_router, daemon=True).start()
    yield
    # Shutdown
    logger.info("Korkem Laya service shutting down.")


app = FastAPI(
    title="Korkem Laya System 1 Decision Service",
    version="0.3.7",
    lifespan=lifespan,
    description="Sub-50ms System 1 decision engine for KORKEM Flow ERP"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic Schemas
class RouteRequest(BaseModel):
    text: str = Field(..., description="The user or worker query text")
    role: Optional[str] = Field(None, description="Current user ERP role (e.g. CUTTING_OPERATOR)")
    language: Optional[str] = Field("auto", description="Language code or auto")


class RouteResponse(BaseModel):
    domain: str
    confidence: float
    needs_tools: bool
    allowed_domains: List[str]
    latency_ms: float
    engine: str


class IntentRequest(BaseModel):
    message: str = Field(..., description="Customer message text")


class IntentResponse(BaseModel):
    intent: str
    confidence: float
    latency_ms: float
    engine: str


class SystemOneRequest(BaseModel):
    state: Dict[str, Any]
    questions: Dict[str, Any]


# Quick Fast-path stem rules for instant <1ms response on obvious greetings
GREETING_STEMS = ("привет", "здравствуй", "добрый день", "доброе утро", "добрый вечер", "сәлем", "салам", "рахмет", "спасибо")


@app.get("/health")
def health_check():
    """Health check reporting model readiness and uptime."""
    ready = _router is not None
    uptime = time.time() - _start_time
    return {
        "status": "healthy" if ready else "initializing",
        "service": "korkem-laya",
        "version": "0.3.7",
        "ready": ready,
        "uptime_seconds": round(uptime, 1)
    }


@app.post("/v1/route", response_model=RouteResponse)
def route_query(req: RouteRequest):
    """Route user query to appropriate domain and determine if tools are needed."""
    t0 = time.time()
    clean_text = (req.text or "").strip().lower()

    # Fast path: instant check for greetings / polite chat (0.2 ms)
    if any(stem in clean_text for stem in GREETING_STEMS) and len(clean_text) < 40:
        dt = (time.time() - t0) * 1000
        return RouteResponse(
            domain="profile",
            confidence=0.999,
            needs_tools=False,
            allowed_domains=["profile"],
            latency_ms=round(dt, 2),
            engine="fast_path"
        )

    # Laya Model Inference
    if _router is not None:
        try:
            with _router_lock:
                state = {"text": req.text, "role": req.role or ""}
                res = _router.predict(state, ROUTING_QUESTIONS)
            
            domain_ans = res.get("answers", {}).get("domain", {})
            choice = domain_ans.get("choice", "profile")
            conf = float(domain_ans.get("confidence", 0.85))

            tools_ans = res.get("answers", {}).get("needs_tools", {})
            needs_tools = True
            if choice == "profile":
                needs_tools = False
            elif "choice" in tools_ans:
                needs_tools = tools_ans["choice"] in (True, "true", "True", 1)

            # Domains always include the detected domain + profile (for self-identity)
            allowed = [choice]
            if "profile" not in allowed:
                allowed.append("profile")

            dt = (time.time() - t0) * 1000
            return RouteResponse(
                domain=choice,
                confidence=round(conf, 4),
                needs_tools=needs_tools,
                allowed_domains=allowed,
                latency_ms=round(dt, 2),
                engine="laya-multilingual"
            )
        except Exception as exc:
            logger.warning(f"Laya inference error, falling back: {exc}")

    # Fallback to rule matching if Laya is warming up or threw error
    detected = "profile"
    needs_tools = True
    if any(w in clean_text for w in ("склад", "остат", "материал", "лдсп", "кромк", "фурнитур", "қойма")):
        detected = "inventory"
    elif any(w in clean_text for w in ("цех", "производств", "станок", "распил", "раскро", "кромлен", "өндіріс")):
        detected = "manufacturing"
    elif any(w in clean_text for w in ("заказ", "клиент", "цена", "оплат", "тапсырыс", "шот")):
        detected = "sales"
    else:
        needs_tools = False

    allowed = [detected]
    if "profile" not in allowed:
        allowed.append("profile")

    dt = (time.time() - t0) * 1000
    return RouteResponse(
        domain=detected,
        confidence=0.75,
        needs_tools=needs_tools,
        allowed_domains=allowed,
        latency_ms=round(dt, 2),
        engine="fallback_rules"
    )


@app.post("/v1/intent", response_model=IntentResponse)
def classify_customer_intent(req: IntentRequest):
    """Classify customer message intent for CRM/WhatsApp/Telegram bot."""
    t0 = time.time()
    clean_text = (req.message or "").strip().lower()

    if _router is not None:
        try:
            with _router_lock:
                state = {"message": req.message}
                res = _router.predict(state, CUSTOMER_INTENT_QUESTIONS)

            intent_ans = res.get("answers", {}).get("intent", {})
            intent_choice = intent_ans.get("choice", "other")
            conf = float(intent_ans.get("confidence", 0.85))

            dt = (time.time() - t0) * 1000
            return IntentResponse(
                intent=intent_choice,
                confidence=round(conf, 4),
                latency_ms=round(dt, 2),
                engine="laya-multilingual"
            )
        except Exception as exc:
            logger.warning(f"Laya intent error: {exc}")

    # Rule fallback
    if any(w in clean_text for w in ("заказ", "купить", "цена", "стоимость", "замер", "тапсырыс")):
        intent = "new_order_inquiry"
    elif any(w in clean_text for w in ("готов", "статус", "когда будет", "қайда", "не болды")):
        intent = "order_status"
    elif any(w in clean_text for w in ("адрес", "график", "где находитесь", "материалы")):
        intent = "general_question"
    else:
        intent = "other"

    dt = (time.time() - t0) * 1000
    return IntentResponse(
        intent=intent,
        confidence=0.75,
        latency_ms=round(dt, 2),
        engine="fallback_rules"
    )


@app.post("/v1/systemone")
def direct_system_one(req: SystemOneRequest):
    """Execute raw Laya System 1 decision logic."""
    if _router is None:
        raise HTTPException(status_code=503, detail="Laya router is still initializing")
    with _router_lock:
        return _router.predict(req.state, req.questions)
