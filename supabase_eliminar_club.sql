-- RPC para que el creador elimine el club completo (cascada manual sin depender de FK)
CREATE OR REPLACE FUNCTION public.eliminar_club(p_club_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creador uuid;
BEGIN
    SELECT creado_por INTO v_creador FROM public.clubs WHERE id = p_club_id;
    IF v_creador IS NULL THEN
        RAISE EXCEPTION 'Club no encontrado';
    END IF;
    IF v_creador <> auth.uid() THEN
        RAISE EXCEPTION 'Solo el creador puede eliminar este club';
    END IF;

    DELETE FROM public.votos_ruta
    WHERE sesion_id IN (SELECT id FROM public.sesiones_club WHERE club_id = p_club_id);

    DELETE FROM public.rutas_propuestas
    WHERE sesion_id IN (SELECT id FROM public.sesiones_club WHERE club_id = p_club_id);

    DELETE FROM public.sesiones_club WHERE club_id = p_club_id;
    DELETE FROM public.club_mensajes WHERE club_id = p_club_id;
    DELETE FROM public.club_miembros WHERE club_id = p_club_id;
    DELETE FROM public.clubs WHERE id = p_club_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.eliminar_club(uuid) TO authenticated;
