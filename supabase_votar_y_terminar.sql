-- =============================================================
-- 1. Arregla votar_ruta (RLS bloqueaba el UPDATE de votos)
-- =============================================================
CREATE OR REPLACE FUNCTION public.votar_ruta(p_sesion_id uuid, p_ruta_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user uuid;
    v_voto_anterior uuid;
BEGIN
    v_user := auth.uid();
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'No autenticado';
    END IF;

    SELECT ruta_id INTO v_voto_anterior
    FROM public.votos_ruta
    WHERE sesion_id = p_sesion_id AND user_id = v_user;

    IF v_voto_anterior IS NOT NULL THEN
        IF v_voto_anterior = p_ruta_id THEN
            RETURN;
        END IF;
        UPDATE public.rutas_propuestas
        SET votos = GREATEST(0, votos - 1)
        WHERE id = v_voto_anterior;
        UPDATE public.votos_ruta
        SET ruta_id = p_ruta_id
        WHERE sesion_id = p_sesion_id AND user_id = v_user;
    ELSE
        INSERT INTO public.votos_ruta(sesion_id, user_id, ruta_id)
        VALUES (p_sesion_id, v_user, p_ruta_id);
    END IF;

    UPDATE public.rutas_propuestas
    SET votos = votos + 1
    WHERE id = p_ruta_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.votar_ruta(uuid, uuid) TO authenticated;


-- =============================================================
-- 2. Tabla de votos para terminar la sesión
-- =============================================================
CREATE TABLE IF NOT EXISTS public.votos_terminar_sesion (
    sesion_id uuid NOT NULL REFERENCES public.sesiones_club(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    creado_en timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (sesion_id, user_id)
);

ALTER TABLE public.votos_terminar_sesion ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "leer_votos_terminar" ON public.votos_terminar_sesion;
CREATE POLICY "leer_votos_terminar"
ON public.votos_terminar_sesion FOR SELECT
TO authenticated
USING (true);


-- =============================================================
-- 3. RPC: votar terminar — cuando todos votan, finaliza
-- =============================================================
CREATE OR REPLACE FUNCTION public.votar_terminar_sesion(p_sesion_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user uuid;
    v_club_id uuid;
    v_total_miembros int;
    v_total_votos int;
BEGIN
    v_user := auth.uid();
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'No autenticado';
    END IF;

    SELECT club_id INTO v_club_id FROM public.sesiones_club WHERE id = p_sesion_id;
    IF v_club_id IS NULL THEN
        RAISE EXCEPTION 'Sesión no encontrada';
    END IF;

    INSERT INTO public.votos_terminar_sesion(sesion_id, user_id)
    VALUES (p_sesion_id, v_user)
    ON CONFLICT DO NOTHING;

    SELECT COUNT(*) INTO v_total_miembros FROM public.club_miembros WHERE club_id = v_club_id;
    SELECT COUNT(*) INTO v_total_votos FROM public.votos_terminar_sesion WHERE sesion_id = p_sesion_id;

    IF v_total_votos >= v_total_miembros THEN
        UPDATE public.sesiones_club
        SET estado = 'finalizada'
        WHERE club_id = v_club_id
          AND estado IN ('esperando', 'corriendo');
    END IF;

    RETURN jsonb_build_object(
        'votos', v_total_votos,
        'total', v_total_miembros,
        'finalizada', v_total_votos >= v_total_miembros
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.votar_terminar_sesion(uuid) TO authenticated;


-- =============================================================
-- 4. RPC: leer cuántos han votado (para mostrar X/N en la UI)
-- =============================================================
CREATE OR REPLACE FUNCTION public.estado_votos_terminar(p_sesion_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_club_id uuid;
    v_total_miembros int;
    v_total_votos int;
    v_ya_voto boolean;
BEGIN
    SELECT club_id INTO v_club_id FROM public.sesiones_club WHERE id = p_sesion_id;
    IF v_club_id IS NULL THEN
        RETURN jsonb_build_object('votos', 0, 'total', 0, 'yaVoto', false);
    END IF;
    SELECT COUNT(*) INTO v_total_miembros FROM public.club_miembros WHERE club_id = v_club_id;
    SELECT COUNT(*) INTO v_total_votos FROM public.votos_terminar_sesion WHERE sesion_id = p_sesion_id;
    SELECT EXISTS (
        SELECT 1 FROM public.votos_terminar_sesion
        WHERE sesion_id = p_sesion_id AND user_id = auth.uid()
    ) INTO v_ya_voto;
    RETURN jsonb_build_object(
        'votos', v_total_votos,
        'total', v_total_miembros,
        'yaVoto', v_ya_voto
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.estado_votos_terminar(uuid) TO authenticated;
