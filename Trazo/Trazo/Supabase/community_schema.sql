-- Esquema mínimo para Comunidad en Supabase (Fase E).
-- Ejecutar en el SQL Editor del proyecto Supabase.

create table if not exists public.clubs (
    slug text primary key,
    name text not null,
    initials text not null,
    accent_raw text not null default 'teal',
    invite_code text not null unique,
    last_message_text text,
    last_message_at timestamptz,
    created_at timestamptz not null default now()
);

create table if not exists public.club_messages (
    id uuid primary key default gen_random_uuid(),
    club_slug text not null references public.clubs(slug) on delete cascade,
    sender_name text not null,
    text text not null,
    is_from_current_user boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists club_messages_club_slug_idx on public.club_messages (club_slug);

alter publication supabase_realtime add table public.club_messages;

alter table public.clubs enable row level security;
alter table public.club_messages enable row level security;

-- Políticas abiertas para desarrollo; endurecer antes de producción.
create policy "clubs read" on public.clubs for select using (true);
create policy "club_messages read" on public.club_messages for select using (true);
create policy "club_messages insert" on public.club_messages for insert with check (true);
