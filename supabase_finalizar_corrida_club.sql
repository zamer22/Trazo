-- RPC: finalizar UNA sesión específica
CREATE OR REPLACE FUNCTION public.finalizar_corrida_club(p_sesion_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_club_id uuid;
    v_es_miembro boolean;
BEGIN
    SELECT club_id INTO v_club_id FROM public.sesiones_club WHERE id = p_sesion_id;
    IF v_club_id IS NULL THEN
        RAISE EXCEPTION 'Sesión no encontrada';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.club_miembros
        WHERE club_id = v_club_id AND user_id = auth.uid()
    ) INTO v_es_miembro;

    IF NOT v_es_miembro THEN
        RAISE EXCEPTION 'No eres miembro de este club';
    END IF;

    -- Finaliza TODAS las pendientes del mismo club para evitar sesiones zombi
    UPDATE public.sesiones_club
    SET estado = 'finalizada'
    WHERE club_id = v_club_id
      AND estado IN ('esperando', 'corriendo');
END;
$$;

GRANT EXECUTE ON FUNCTION public.finalizar_corrida_club(uuid) TO authenticated;

-- RPC: finalizar TODAS las sesiones pendientes de un club (limpieza directa)
CREATE OR REPLACE FUNCTION public.finalizar_todas_sesiones_club(p_club_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_es_miembro boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.club_miembros
        WHERE club_id = p_club_id AND user_id = auth.uid()
    ) INTO v_es_miembro;

    IF NOT v_es_miembro THEN
        RAISE EXCEPTION 'No eres miembro de este club';
    END IF;

    UPDATE public.sesiones_club
    SET estado = 'finalizada'
    WHERE club_id = p_club_id
      AND estado IN ('esperando', 'corriendo');
END;
$$;

GRANT EXECUTE ON FUNCTION public.finalizar_todas_sesiones_club(uuid) TO authenticated;
