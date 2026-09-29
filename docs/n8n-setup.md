# Importación y configuración de n8n

## Requisitos

- n8n con los nodos integrados Webhook, Code, HTTP Request y Respond to Webhook.
- Supabase con `database/schema.sql` aplicado.
- Un número de WhatsApp Cloud API configurado en Meta.
- Variables de entorno de `.env.example` configuradas en el entorno de n8n. El workflow usa expresiones `$env`; en n8n Cloud o en instancias que las bloqueen, reemplazalas por credenciales seguras compatibles con esa instancia.

## Configurar la clínica

Copiá el `phone_number_id` de Meta y asociá el número a una clínica existente:

```sql
UPDATE public.clinicas
SET whatsapp_phone_id = 'PHONE_NUMBER_ID_DE_META'
WHERE id = 'UUID_DE_LA_CLINICA';
```

`whatsapp_phone_id` debe ser único. El flujo descarta solicitudes cuyo número no esté asociado a una clínica.

## Importar y conectar Meta

1. En n8n, importá `automation/bot-whatsapp-n8n.json`.
2. Configurá `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `WHATSAPP_CLOUD_TOKEN`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_GRAPH_API_VERSION` y `OPENAI_API_KEY` en n8n. Usá una versión de Graph API vigente para tu aplicación de Meta.
3. Guardá el workflow y copiá la URL de producción del webhook `Meta: recibir mensajes`.
4. En la configuración de Webhooks de Meta, usá esa URL como Callback URL y el mismo valor de `WHATSAPP_VERIFY_TOKEN` como Verify Token. El nodo GET verifica el desafío y el POST recibe eventos; ambos usan la ruta `meta-whatsapp`.
5. Suscribí la aplicación al campo `messages`. Activá el workflow y probá primero con un número y mensajes sintéticos.

## Comportamiento y límites

- El POST responde inmediatamente a Meta; el procesamiento continúa en n8n.
- Los estados de entrega sin mensaje entrante se ignoran.
- Cada mensaje de Meta se registra una sola vez mediante `provider_message_id`.
- El clasificador solo devuelve una intención (`turno`, `historia`, `seguimiento`, `urgencia` u `otro`). Las respuestas las determina el workflow; no genera diagnósticos ni reserva turnos.
- Si el clasificador falla o devuelve una salida inválida, la respuesta cae en el texto genérico de derivación.
- Revisá las ejecuciones fallidas, la política de reintentos y la retención de datos de ejecución de n8n antes de producción.

## Variables

| Variable | Uso |
|---|---|
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Acceso backend privilegiado; nunca usar en Lovable/navegador |
| `WHATSAPP_CLOUD_TOKEN` | Token de Meta para enviar mensajes |
| `WHATSAPP_VERIFY_TOKEN` | Token propio para validar el webhook GET |
| `WHATSAPP_GRAPH_API_VERSION` | Versión activa de Graph API, por ejemplo `vXX.X` |
| `OPENAI_API_KEY` | Clasificación de intención |
