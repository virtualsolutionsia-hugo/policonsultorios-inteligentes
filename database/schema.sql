-- ============================================================================
-- POLICONSULTORIO INTELIGENTE — ESQUEMA SQL PARA SUPABASE
-- ============================================================================
-- Pegá todo esto en la consola SQL de Supabase de tu proyecto
-- Las tablas y políticas de RLS se crean automáticamente

-- ============================================================================
-- 1. TABLAS CORE
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinicas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  whatsapp_phone_id TEXT UNIQUE,
  activa BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  clinica_id UUID REFERENCES clinicas(id) ON DELETE CASCADE,
  rol TEXT NOT NULL CHECK (rol IN ('super-admin', 'admin_clinica', 'recepcion', 'medico', 'vacunador')),
  medico_id UUID,
  vacunador_id UUID,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- 2. MÉDICOS Y ESPECIALIDADES
-- ============================================================================

CREATE TABLE IF NOT EXISTS especialidades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS medicos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  nombre_completo TEXT NOT NULL,
  telefono TEXT,
  email TEXT,
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS medico_especialidades (
  medico_id UUID NOT NULL REFERENCES medicos(id) ON DELETE CASCADE,
  especialidad_id UUID NOT NULL REFERENCES especialidades(id) ON DELETE CASCADE,
  PRIMARY KEY (medico_id, especialidad_id)
);

CREATE TABLE IF NOT EXISTS vacunadores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  nombre_completo TEXT NOT NULL,
  telefono TEXT,
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- 3. PACIENTES Y TURNOS
-- ============================================================================

CREATE TABLE IF NOT EXISTS pacientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  nombre_completo TEXT NOT NULL,
  fecha_nacimiento DATE,
  nombre_tutor TEXT,
  telefono_whatsapp TEXT,
  alerta TEXT,
  email TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS prestaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  especialidad_id UUID REFERENCES especialidades(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  duracion_min INT DEFAULT 20,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS horarios_atencion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  medico_id UUID REFERENCES medicos(id) ON DELETE CASCADE,
  vacunador_id UUID REFERENCES vacunadores(id) ON DELETE CASCADE,
  dia_semana INT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
  hora_inicio TIME NOT NULL,
  hora_fin TIME NOT NULL,
  duracion_turno_min INT DEFAULT 20,
  created_at TIMESTAMP DEFAULT NOW(),
  CHECK (medico_id IS NOT NULL OR vacunador_id IS NOT NULL),
  CHECK (NOT (medico_id IS NOT NULL AND vacunador_id IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS turnos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  paciente_id UUID NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
  medico_id UUID REFERENCES medicos(id) ON DELETE SET NULL,
  vacunador_id UUID REFERENCES vacunadores(id) ON DELETE SET NULL,
  fecha_hora TIMESTAMP NOT NULL,
  tipo_consulta TEXT,
  prestacion_id UUID REFERENCES prestaciones(id) ON DELETE SET NULL,
  estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'confirmado', 'cancelado', 'ausente', 'completado')),
  origen TEXT DEFAULT 'manual' CHECK (origen IN ('manual', 'bot_whatsapp')),
  google_calendar_event_id TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CHECK (medico_id IS NOT NULL OR vacunador_id IS NOT NULL),
  CHECK (NOT (medico_id IS NOT NULL AND vacunador_id IS NOT NULL))
);

-- ============================================================================
-- 4. HISTORIAL DEL PACIENTE
-- ============================================================================

CREATE TABLE IF NOT EXISTS historias_clinicas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  paciente_id UUID NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
  medico_id UUID NOT NULL REFERENCES medicos(id) ON DELETE CASCADE,
  turno_id UUID REFERENCES turnos(id) ON DELETE SET NULL,
  borrador_ia JSONB,
  version_aprobada JSONB,
  estado TEXT DEFAULT 'borrador_ia' CHECK (estado IN ('borrador_ia', 'aprobada', 'editada')),
  aprobado_por UUID REFERENCES medicos(id) ON DELETE SET NULL,
  aprobado_en TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- 5. WHATSAPP
-- ============================================================================

CREATE TABLE IF NOT EXISTS whatsapp_conversaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  paciente_id UUID REFERENCES pacientes(id) ON DELETE SET NULL,
  telefono TEXT NOT NULL,
  estado TEXT DEFAULT 'activa' CHECK (estado IN ('activa', 'cerrada')),
  contexto_bot JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (clinica_id, telefono)
);

CREATE TABLE IF NOT EXISTS mensajes_whatsapp (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinica_id UUID NOT NULL REFERENCES clinicas(id) ON DELETE CASCADE,
  conversacion_id UUID NOT NULL REFERENCES whatsapp_conversaciones(id) ON DELETE CASCADE,
  provider_message_id TEXT UNIQUE,
  direccion TEXT NOT NULL CHECK (direccion IN ('entrante', 'saliente')),
  mensaje TEXT NOT NULL,
  intencion TEXT CHECK (intencion IN ('turno', 'historia', 'seguimiento', 'urgencia', 'otro')),
  generado_por TEXT DEFAULT 'bot' CHECK (generado_por IN ('bot', 'ia', 'humano')),
  turno_generado_id UUID REFERENCES turnos(id) ON DELETE SET NULL,
  estado TEXT NOT NULL DEFAULT 'pendiente_revision' CHECK (estado IN ('pendiente_revision', 'procesado', 'error')),
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- 6. ÍNDICES PARA PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_usuarios_clinica ON usuarios(clinica_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON usuarios(rol);
CREATE INDEX IF NOT EXISTS idx_medicos_clinica ON medicos(clinica_id);
CREATE INDEX IF NOT EXISTS idx_vacunadores_clinica ON vacunadores(clinica_id);
CREATE INDEX IF NOT EXISTS idx_pacientes_clinica ON pacientes(clinica_id);
CREATE INDEX IF NOT EXISTS idx_turnos_clinica ON turnos(clinica_id);
CREATE INDEX IF NOT EXISTS idx_turnos_medico ON turnos(medico_id);
CREATE INDEX IF NOT EXISTS idx_turnos_vacunador ON turnos(vacunador_id);
CREATE INDEX IF NOT EXISTS idx_turnos_fecha ON turnos(fecha_hora);
CREATE INDEX IF NOT EXISTS idx_historias_medico ON historias_clinicas(medico_id);
CREATE INDEX IF NOT EXISTS idx_historias_paciente ON historias_clinicas(paciente_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_conversacion ON mensajes_whatsapp(conversacion_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_provider_id ON mensajes_whatsapp(provider_message_id);
CREATE INDEX IF NOT EXISTS idx_conversaciones_telefono ON whatsapp_conversaciones(telefono);
CREATE INDEX IF NOT EXISTS idx_prestaciones_clinica ON prestaciones(clinica_id);
CREATE INDEX IF NOT EXISTS idx_horarios_medico ON horarios_atencion(medico_id);
CREATE INDEX IF NOT EXISTS idx_horarios_vacunador ON horarios_atencion(vacunador_id);

-- ============================================================================
-- 7. HABILITAR RLS (Row Level Security)
-- ============================================================================
-- Nota: el bot de n8n usa la Service Role Key de Supabase, que IGNORA RLS por
-- diseño. Todo lo que sigue rige exclusivamente el acceso desde el panel web
-- (Lovable), donde cada persona entra con su propio usuario.

ALTER TABLE clinicas ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE medicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE medico_especialidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE vacunadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE pacientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE prestaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE horarios_atencion ENABLE ROW LEVEL SECURITY;
ALTER TABLE turnos ENABLE ROW LEVEL SECURITY;
ALTER TABLE historias_clinicas ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_conversaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensajes_whatsapp ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 8. POLÍTICAS DE RLS POR ROL
-- ============================================================================

-- --------------------------------------------------------------------------
-- USUARIOS: cada persona necesita poder leer SU PROPIA fila (rol, clinica_id,
-- etc.) porque todas las demás políticas de abajo dependen de esta consulta.
-- Sin esto, TODAS las demás políticas fallan en cadena.
-- --------------------------------------------------------------------------
CREATE POLICY "usuarios_lee_su_propia_fila" ON usuarios
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "admin_clinica_gestiona_usuarios" ON usuarios
  FOR ALL USING (
    clinica_id IN (
      SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
    )
  );

CREATE POLICY "super_admin_usuarios" ON usuarios
  FOR ALL USING (auth.uid() IN (SELECT id FROM usuarios WHERE rol = 'super-admin'));

-- --------------------------------------------------------------------------
-- SUPER-ADMIN: acceso total a todas las clínicas y sus datos
-- --------------------------------------------------------------------------
CREATE POLICY "super_admin_clinicas" ON clinicas
  FOR ALL USING (auth.uid() IN (SELECT id FROM usuarios WHERE rol = 'super-admin'));

CREATE POLICY "super_admin_todo_medicos" ON medicos
  FOR ALL USING (auth.uid() IN (SELECT id FROM usuarios WHERE rol = 'super-admin'));

CREATE POLICY "super_admin_todo_vacunadores" ON vacunadores
  FOR ALL USING (auth.uid() IN (SELECT id FROM usuarios WHERE rol = 'super-admin'));

CREATE POLICY "super_admin_todo_pacientes" ON pacientes
  FOR ALL USING (auth.uid() IN (SELECT id FROM usuarios WHERE rol = 'super-admin'));

CREATE POLICY "super_admin_todo_turnos" ON turnos
  FOR ALL USING (auth.uid() IN (SELECT id FROM usuarios WHERE rol = 'super-admin'));

CREATE POLICY "super_admin_todo_whatsapp" ON whatsapp_conversaciones
  FOR ALL USING (auth.uid() IN (SELECT id FROM usuarios WHERE rol = 'super-admin'));

-- --------------------------------------------------------------------------
-- ADMIN DE CLÍNICA: ve y administra SOLO su propia clínica.
-- IMPORTANTE: se filtra por rol = 'admin_clinica', no solo por clinica_id,
-- para que un médico o vacunador de la misma clínica NO herede estos permisos.
-- --------------------------------------------------------------------------
CREATE POLICY "admin_clinica_medicos" ON medicos
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
  ));

CREATE POLICY "admin_clinica_vacunadores" ON vacunadores
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
  ));

CREATE POLICY "admin_clinica_pacientes" ON pacientes
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
  ));

CREATE POLICY "admin_clinica_turnos" ON turnos
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
  ));

CREATE POLICY "admin_clinica_prestaciones" ON prestaciones
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
  ));

CREATE POLICY "admin_clinica_whatsapp" ON whatsapp_conversaciones
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
  ));

CREATE POLICY "admin_clinica_mensajes" ON mensajes_whatsapp
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
  ));

-- --------------------------------------------------------------------------
-- RECEPCIÓN: agenda turnos y registra pacientes de su clínica.
-- FOR ALL (no solo SELECT) porque recepción necesita poder dar de alta
-- pacientes nuevos y crear/editar turnos, no solo consultarlos.
-- --------------------------------------------------------------------------
CREATE POLICY "recepcion_pacientes" ON pacientes
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'recepcion'
  ));

CREATE POLICY "recepcion_turnos" ON turnos
  FOR ALL USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'recepcion'
  ));

CREATE POLICY "recepcion_whatsapp" ON whatsapp_conversaciones
  FOR SELECT USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'recepcion'
  ));

CREATE POLICY "recepcion_mensajes" ON mensajes_whatsapp
  FOR SELECT USING (clinica_id IN (
    SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'recepcion'
  ));

-- --------------------------------------------------------------------------
-- MÉDICO: ve y edita solo sus propios pacientes, turnos e historias.
-- --------------------------------------------------------------------------
CREATE POLICY "medico_pacientes" ON pacientes
  FOR SELECT USING (
    id IN (
      SELECT DISTINCT paciente_id FROM turnos 
      WHERE medico_id = (
        SELECT medico_id FROM usuarios WHERE id = auth.uid() AND rol = 'medico'
      )
    )
  );

CREATE POLICY "medico_historias" ON historias_clinicas
  FOR ALL USING (
    medico_id = (SELECT medico_id FROM usuarios WHERE id = auth.uid() AND rol = 'medico')
  );

CREATE POLICY "medico_turnos" ON turnos
  FOR ALL USING (
    medico_id = (SELECT medico_id FROM usuarios WHERE id = auth.uid() AND rol = 'medico')
  );

-- --------------------------------------------------------------------------
-- VACUNADOR: ve solo sus propios turnos de vacunación. Sin acceso a
-- HISTORIAL DEL PACIENTE (no se crea ninguna política para vacunador ahí,
-- y con RLS activado eso significa acceso denegado por defecto).
-- --------------------------------------------------------------------------
CREATE POLICY "vacunador_turnos" ON turnos
  FOR SELECT USING (
    vacunador_id = (SELECT vacunador_id FROM usuarios WHERE id = auth.uid() AND rol = 'vacunador')
  );

-- --------------------------------------------------------------------------
-- TABLAS DE CATÁLOGO: especialidades, prestaciones y horarios son visibles
-- para cualquier usuario autenticado de una clínica (se usan para llenar
-- dropdowns); la escritura queda reservada a admin_clinica (política de
-- arriba en prestaciones; especialidades es compartida entre clínicas).
-- --------------------------------------------------------------------------
CREATE POLICY "especialidades_lectura" ON especialidades
  FOR SELECT USING (true);

CREATE POLICY "medico_especialidades_lectura" ON medico_especialidades
  FOR SELECT USING (
    medico_id IN (
      SELECT id FROM medicos WHERE clinica_id IN (
        SELECT clinica_id FROM usuarios WHERE id = auth.uid()
      )
    )
  );

CREATE POLICY "admin_clinica_medico_especialidades" ON medico_especialidades
  FOR ALL USING (
    medico_id IN (
      SELECT id FROM medicos WHERE clinica_id IN (
        SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica'
      )
    )
  );

CREATE POLICY "horarios_lectura" ON horarios_atencion
  FOR SELECT USING (
    COALESCE(
      medico_id IN (SELECT id FROM medicos WHERE clinica_id IN (SELECT clinica_id FROM usuarios WHERE id = auth.uid())),
      vacunador_id IN (SELECT id FROM vacunadores WHERE clinica_id IN (SELECT clinica_id FROM usuarios WHERE id = auth.uid())),
      false
    )
  );

CREATE POLICY "admin_clinica_horarios" ON horarios_atencion
  FOR ALL USING (
    COALESCE(
      medico_id IN (SELECT id FROM medicos WHERE clinica_id IN (SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica')),
      vacunador_id IN (SELECT id FROM vacunadores WHERE clinica_id IN (SELECT clinica_id FROM usuarios WHERE id = auth.uid() AND rol = 'admin_clinica')),
      false
    )
  );


-- ============================================================================
-- 9. FUNCTIONS ÚTILES
-- ============================================================================

-- Función para obtener horarios disponibles de un médico en una fecha
CREATE OR REPLACE FUNCTION horarios_disponibles(
  p_medico_id UUID,
  p_fecha DATE
)
RETURNS TABLE (
  hora_inicio TIME,
  hora_fin TIME,
  disponible BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    h.hora_inicio,
    h.hora_fin,
    NOT EXISTS (
      SELECT 1 FROM turnos 
      WHERE medico_id = p_medico_id 
      AND DATE(fecha_hora) = p_fecha
      AND estado != 'cancelado'
    ) AS disponible
  FROM horarios_atencion h
  WHERE h.medico_id = p_medico_id
  AND h.dia_semana = EXTRACT(DOW FROM p_fecha)::INT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 10. DATOS DE PRUEBA (opcional)
-- ============================================================================

-- INSERT INTO clinicas (nombre) VALUES ('Consultorio San Lucas');
-- INSERT INTO especialidades (nombre) VALUES 
--   ('Pediatría general'),
--   ('Vacunación'),
--   ('Nutrición infantil'),
--   ('Neonatología');
