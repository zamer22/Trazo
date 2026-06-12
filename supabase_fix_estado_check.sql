-- Ampliar el CHECK de estado para incluir 'finalizada'
ALTER TABLE public.sesiones_club
    DROP CONSTRAINT IF EXISTS sesiones_club_estado_check;

ALTER TABLE public.sesiones_club
    ADD CONSTRAINT sesiones_club_estado_check
    CHECK (estado IN ('esperando', 'corriendo', 'finalizada'));
