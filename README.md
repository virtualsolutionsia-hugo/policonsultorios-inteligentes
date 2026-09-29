# POLICONSULTORIO INTELIGENTE

Repositorio de respaldo y configuración para el sistema multi-clínica de gestión pediátrica basado en Supabase, Lovable y n8n.

## Contenido

```text
policonsultorio-inteligente/
├── automation/
│   └── bot-whatsapp-n8n.json
├── database/
│   └── schema.sql
├── docs/
│   ├── n8n-setup.md
│   ├── queries-lovable.md
│   └── security.md
├── .env.example
├── .gitignore
└── README.md
```

## Puesta en marcha

1. En un proyecto Supabase nuevo, ejecutá `database/schema.sql` desde SQL Editor. No lo uses como migración sobre una base con datos existentes.
2. En `clinicas`, cargá el `phone_number_id` asignado por Meta en `whatsapp_phone_id` para asociar cada número entrante con su clínica.
3. Configurá en n8n las variables indicadas en `.env.example`. No guardes sus valores reales en Git.
4. Importá `automation/bot-whatsapp-n8n.json` desde **Workflows → Import from File**.
5. Seguí [docs/n8n-setup.md](docs/n8n-setup.md) para registrar el webhook de Meta y probarlo con datos sintéticos antes de activarlo.

## Alcance del workflow

El flujo valida el webhook de Meta, registra mensajes entrantes con deduplicación por ID, clasifica la intención con IA y responde con textos prefijados. Las solicitudes de turnos y de HISTORIAL DEL PACIENTE se derivan a recepción; el flujo no confirma ni crea turnos y nunca responde consultas clínicas con diagnóstico o tratamiento.

El clasificador envía el texto entrante a OpenAI. No uses datos reales de pacientes ni de menores hasta validar consentimiento, base legal, contratos y configuración de privacidad aplicables.

## Roles

| Rol | Acceso previsto |
|---|---|
| `super-admin` | Todas las clínicas |
| `admin_clinica` | Su clínica |
| `recepcion` | Turnos y datos operativos de pacientes |
| `medico` | Pacientes e HISTORIAL DEL PACIENTE asignados |
| `vacunador` | Sus turnos de vacunación |

La columna `alerta` de `pacientes` corresponde a la etiqueta visible `ALERTA` y referencia patologías preexistentes. Es información de salud sensible: antes de producción hay que restringir su lectura por rol; las políticas RLS actuales operan por tabla y no ocultan columnas.

## GitHub

El proyecto está preparado para inicializarse como repositorio Git local. La publicación en GitHub requiere crear un repositorio vacío en tu cuenta y configurar el remoto; no incluyas `.env`, claves, tokens, datos de pacientes ni exportaciones con credenciales.

Virtual Solutions IA · Posadas, Argentina
