# Seguridad y datos

- No versionar secretos, tokens, claves de servicio, HISTORIAL DEL PACIENTE ni datos identificables de pacientes.
- La Service Role Key de Supabase omite RLS. Guardarla solo en n8n/backend, limitar quién administra credenciales y rotarla si se expone.
- La columna `pacientes.alerta` contiene referencias a patologías preexistentes. Las políticas RLS actuales son por tabla y recepción tiene acceso a filas de pacientes; por eso no debe cargarse información real en `alerta` hasta implementar y probar controles de acceso por columna o una API/vista que la oculte a roles no clínicos.
- El clasificador envía el texto de WhatsApp a OpenAI. Antes de usar datos reales de salud o de menores, validar consentimiento, normativa argentina aplicable, base legal, contratos de tratamiento, región/retención y configuración del proveedor. Hasta entonces, usar datos sintéticos.
- No enviar respuestas clínicas automáticas. Las consultas de salud, historial y urgencias deben derivarse a profesionales; el mensaje de emergencia del flujo no reemplaza los servicios locales.
- Configurar retención mínima de ejecuciones en n8n, control de acceso, auditoría, backups cifrados y procedimiento de incidentes.
- Probar RLS con cada rol y con operaciones `SELECT`, `INSERT`, `UPDATE` y `DELETE` antes de un piloto. El esquema de referencia requiere una revisión independiente de seguridad antes de producción.
