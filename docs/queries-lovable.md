# POLICONSULTORIO INTELIGENTE — Queries de Lovable para Supabase

Documento técnico: cómo el dashboard en Lovable se conecta y consulta la base de datos.

---

## Autenticación y contexto

Todo comienza cuando el usuario hace login. Supabase Auth devuelve un `session.user.id` que luego usamos para:
1. Obtener el `rol` y `clinica_id` del usuario desde la tabla `usuarios`
2. Filtrar todas las queries por `clinica_id` automáticamente
3. Aplicar permisos adicionales según el rol (un médico solo ve sus turnos, etc.)

## Ficha del paciente

El campo `pacientes.alerta` se presenta con la etiqueta `ALERTA` y referencia patologías preexistentes. No lo expongas a recepción: la RLS del esquema es por tabla y no restringe columnas. Antes de habilitarlo en Lovable, implementá una vista o API que limite su lectura a los roles clínicos autorizados.

---

## Panel General (Dashboard Home)

### Query 1: Obtener datos del usuario actual

```sql
SELECT 
  u.id,
  u.rol,
  u.clinica_id,
  u.medico_id,
  u.vacunador_id,
  c.nombre AS clinica_nombre
FROM usuarios u
LEFT JOIN clinicas c ON u.clinica_id = c.id
WHERE u.id = auth.uid();
```

**Uso en Lovable**: Se ejecuta al cargar el panel, devuelve el rol y la clínica actual para filtrar todas las demás queries.

---

### Query 2: Obtener turnos del día actual

```sql
SELECT 
  t.id,
  t.fecha_hora,
  t.tipo_consulta,
  t.estado,
  t.origen,
  p.nombre_completo AS paciente,
  COALESCE(m.nombre_completo, v.nombre_completo) AS profesional,
  CASE WHEN t.medico_id IS NOT NULL THEN 'Médico' ELSE 'Vacunador' END AS tipo_profesional,
  e.nombre AS especialidad
FROM turnos t
LEFT JOIN pacientes p ON t.paciente_id = p.id
LEFT JOIN medicos m ON t.medico_id = m.id
LEFT JOIN vacunadores v ON t.vacunador_id = v.id
LEFT JOIN medico_especialidades me ON m.id = me.medico_id
LEFT JOIN especialidades e ON me.especialidad_id = e.id
WHERE t.clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND DATE(t.fecha_hora) = CURRENT_DATE
ORDER BY t.fecha_hora ASC;
```

**Uso**: Llena la sección "Agenda de hoy" del panel. Los filtros (especialidad, médico, vacunador) se aplican después en el cliente.

---

### Query 3: Contadores (métricas)

**Turnos hoy confirmados:**
```sql
SELECT COUNT(*) AS turnos_hoy
FROM turnos
WHERE clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND DATE(fecha_hora) = CURRENT_DATE
AND estado = 'confirmado';
```

**Mensajes WhatsApp sin revisar:**
```sql
SELECT COUNT(*) AS mensajes_pendientes
FROM mensajes_whatsapp mw
JOIN whatsapp_conversaciones wc ON mw.conversacion_id = wc.id
WHERE wc.clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND mw.direccion = 'entrante'
AND mw.generado_por = 'bot';
```

**HISTORIAL DEL PACIENTE pendiente de revisión:**
```sql
SELECT COUNT(*) AS historias_pendientes
FROM historias_clinicas
WHERE clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND estado = 'borrador_ia';
```

**Turnos confirmados por WhatsApp:**
```sql
SELECT COUNT(*) AS confirmados_whatsapp
FROM turnos
WHERE clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND DATE(fecha_hora) = CURRENT_DATE
AND origen = 'bot_whatsapp'
AND estado = 'confirmado';
```

**Uso**: Las 4 tarjetas de métricas en la parte superior del panel.

---

## Bandeja de WhatsApp

### Query 4: Obtener mensajes clasificados por IA

```sql
SELECT 
  mw.id,
  mw.mensaje,
  mw.intencion,
  mw.generado_por,
  mw.created_at,
  wc.telefono,
  p.nombre_completo AS paciente,
  p.id AS paciente_id
FROM mensajes_whatsapp mw
JOIN whatsapp_conversaciones wc ON mw.conversacion_id = wc.id
LEFT JOIN pacientes p ON wc.paciente_id = p.id
WHERE wc.clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND mw.direccion = 'entrante'
AND mw.estado = 'pendiente_revision'
ORDER BY mw.created_at DESC
LIMIT 10;
```

**Uso**: Llena la sección "Bandeja WhatsApp" con los últimos 10 mensajes sin revisar, clasificados por intención.

---

## HISTORIAL DEL PACIENTE

### Query 5: Obtener registros del HISTORIAL DEL PACIENTE pendientes de aprobación

```sql
SELECT 
  hc.id,
  p.nombre_completo AS paciente,
  hc.borrador_ia,
  hc.created_at,
  m.nombre_completo AS medico
FROM historias_clinicas hc
JOIN pacientes p ON hc.paciente_id = p.id
JOIN medicos m ON hc.medico_id = m.id
WHERE hc.clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND hc.estado = 'borrador_ia'
ORDER BY hc.created_at DESC;
```

**Uso**: Tabla de registros generados con IA que esperan aprobación profesional.

---

### Query 6: Aprobar o editar el HISTORIAL DEL PACIENTE

```sql
UPDATE historias_clinicas
SET 
  version_aprobada = $1,
  estado = 'aprobada',
  aprobado_por = auth.uid(),
  aprobado_en = NOW(),
  updated_at = NOW()
WHERE id = $2
AND clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
RETURNING *;
```

**Uso**: Cuando un médico aprueba o edita un borrador del HISTORIAL DEL PACIENTE.

---

## Pantalla de Altas

### Query 7: Crear un nuevo médico

```sql
INSERT INTO medicos (clinica_id, nombre_completo, telefono, email, activo)
VALUES (
  (SELECT clinica_id FROM usuarios WHERE id = auth.uid()),
  $1, $2, $3
)
RETURNING id;
```

**Luego insertar especialidades:**
```sql
INSERT INTO medico_especialidades (medico_id, especialidad_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;
```

**Uso**: Desde la pantalla "Alta de médico".

---

### Query 8: Crear horario de atención

```sql
INSERT INTO horarios_atencion (
  medico_id,
  dia_semana,
  hora_inicio,
  hora_fin,
  duracion_turno_min
)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;
```

**Uso**: Cada vez que el usuario agrega una franja horaria.

---

### Query 9: Crear nueva prestación

```sql
INSERT INTO prestaciones (
  clinica_id,
  especialidad_id,
  nombre,
  duracion_min
)
VALUES (
  (SELECT clinica_id FROM usuarios WHERE id = auth.uid()),
  $1, $2, $3
)
RETURNING *;
```

**Uso**: Crear tipos de consulta nuevos.

---

## Pantalla de Turnos

### Query 10: Obtener médicos disponibles

```sql
SELECT DISTINCT
  m.id,
  m.nombre_completo,
  e.nombre AS especialidad
FROM medicos m
LEFT JOIN medico_especialidades me ON m.id = me.medico_id
LEFT JOIN especialidades e ON me.especialidad_id = e.id
WHERE m.clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND m.activo = true
ORDER BY m.nombre_completo;
```

**Uso**: Dropdown de "Médico" cuando se crea un turno.

---

### Query 11: Crear un turno manualmente

```sql
INSERT INTO turnos (
  clinica_id,
  paciente_id,
  medico_id,
  vacunador_id,
  fecha_hora,
  tipo_consulta,
  prestacion_id,
  estado,
  origen
)
VALUES (
  (SELECT clinica_id FROM usuarios WHERE id = auth.uid()),
  $1, $2, $3, $4, $5, $6,
  'pendiente',
  'manual'
)
RETURNING *;
```

**Uso**: Insertar un turno nuevo desde el panel.

---

## Filtrados

### Query 12: Turnos filtrados por especialidad, médico o vacunador

```sql
SELECT t.*
FROM turnos t
LEFT JOIN medicos m ON t.medico_id = m.id
LEFT JOIN medico_especialidades me ON m.id = me.medico_id
LEFT JOIN especialidades e ON me.especialidad_id = e.id
WHERE t.clinica_id = (SELECT clinica_id FROM usuarios WHERE id = auth.uid())
AND DATE(t.fecha_hora) = CURRENT_DATE
AND (
  CASE 
    WHEN $1 IS NOT NULL THEN e.id = $1
    WHEN $2 IS NOT NULL THEN t.medico_id = $2
    WHEN $3 IS NOT NULL THEN t.vacunador_id = $3
    ELSE TRUE
  END
);
```

**Uso**: Filtros del panel (tipo profesional, especialidad, médico, vacunador).

---

## Permisos por rol

### Para un Médico: ver solo sus pacientes

Se agrega automáticamente a todas las queries:
```sql
AND t.medico_id = (SELECT medico_id FROM usuarios WHERE id = auth.uid())
```

### Para Recepción: no ver el HISTORIAL DEL PACIENTE

Simplemente no ejecutar las Query 5 ni 6. Las políticas RLS de Supabase también lo bloquean a nivel de BD.

### Para Vacunador: ver solo sus turnos

```sql
AND t.vacunador_id = (SELECT vacunador_id FROM usuarios WHERE id = auth.uid())
```

---

## Notas de implementación en Lovable

1. **Cada query se ejecuta como una "Action" o "Connector" a Supabase** — Lovable tiene un conector nativo para Supabase que permite ejecutar SQL directamente.

2. **Variables reactivas** — Cuando cambian los filtros (especialidad, médico), Lovable re-ejecuta automáticamente las queries que dependen de esos valores.

3. **Caché y actualización** — Las queries del panel se ejecutan al cargar la página y cuando se crea/edita un turno. Lovable puede refrescar automáticamente según configuración.

4. **Validaciones en el cliente** — Aunque RLS bloquea a nivel de BD, Lovable debe validar en el cliente que el usuario tiene permisos (ej: un médico no ve el botón "Editar" para historias que no son suyas).

5. **Relaciones complejas** — Algunas queries (como la de turnos con especialidades) requieren JOINs múltiples. Lovable optimiza esto con índices en Supabase (ya creados en el schema).
