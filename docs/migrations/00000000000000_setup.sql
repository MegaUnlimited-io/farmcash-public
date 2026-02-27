create table public.devices (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  creation_date timestamp with time zone not null,
  last_update_date timestamp with time zone not null,
  installation_id text not null,
  token text not null,
  "operatingSystem" text not null,
  extra_data jsonb null,
  constraint devices_pkey primary key (id),
  constraint devices_user_id_fkey foreign KEY (user_id) references auth.users (id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;

alter table public.devices enable row level security;

create policy "Enable select access for users based on their user ID *"
on public.devices
for select using (auth.uid() = user_id);

create policy "Enable insert access for users based on their user ID *"
on public.devices
for insert with check (auth.uid() = user_id);

create policy "Enable update access for users based on their user ID *"
on public.devices
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Enable delete access for users based on their user ID *"
on public.devices
for delete using (auth.uid() = user_id);

create table public.notifications (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  title text not null,
  body text not null,
  data jsonb null,
  type text null,
  creation_date timestamp with time zone not null,
  read_date timestamp with time zone null,
  locale text null,
  constraint notifications_pkey primary key (id),
  constraint notifications_user_id_fkey foreign key (user_id) references auth.users (id) on update cascade on delete cascade
) tablespace pg_default;

alter table public.notifications enable row level security;

create policy "Enable read based on user_id." on public.notifications
  for select using (auth.uid() = user_id);

create policy "Enable update based on user_id." on public.notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Enable realtime for notifications table
alter publication supabase_realtime add table public.notifications;

create type store_type as enum (
  'PLAY_STORE',
  'APPLE_STORE'
);

create type sub_status as enum (
  'ACTIVE',
  'PAUSED',
  'EXPIRED',
  'LIFETIME'
);

create table
  public.subscriptions (
    id uuid not null default gen_random_uuid (),
    creation_date timestamp with time zone not null default now(),
    sku_id text not null,
    last_update_date timestamp with time zone not null,
    period_end_date timestamp with time zone null,
    user_id uuid null,
    store store_type null,
    status sub_status not null,
    constraint subscriptions_pkey primary key (id),
    constraint subscriptions_user_id_fkey foreign key (user_id) references auth.users (id) on update cascade on delete cascade
  ) tablespace pg_default;

alter table public.subscriptions
  enable row level security;

create policy "Enable read based on user_id." on public.subscriptions
  for select using (auth.uid() = user_id);

create table
  public.users (
    id uuid not null default gen_random_uuid (),
    creation_date timestamp with time zone not null default now(),
    last_update_date timestamp without time zone null,
    name character varying null,
    email character varying null,
    avatar_url text null,
    onboarded boolean not null default false,
    constraint users_pkey primary key (id),
    constraint users_id_key unique (id)
  ) tablespace pg_default;

alter table users enable row level security;

create policy "Users are viewable by everyone." on public.users
  for select using (true);

create policy "Users can insert their own profile." on public.users
  for insert with check (auth.uid() = id);

create policy "Users can update own profile." on public.users
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- ================================================
-- user infos table
-- ================================================
create table public.user_infos (
  id uuid PRIMARY KEY default gen_random_uuid (),
  user_id uuid NOT NULL,  
  info_key TEXT NOT NULL,
  info_value TEXT NOT NULL,
  constraint user_infos_id_fkey foreign key (user_id) references auth.users (id) on update cascade on delete cascade
) tablespace pg_default;

alter table user_infos enable row level security;

create policy "Users can insert" on public.user_infos
  for insert with check (auth.uid() = user_id);

create policy "Users can update" on public.user_infos
    for update using (auth.uid() = user_id);

create policy "Users can delete" on public.user_infos
    for delete using (auth.uid() = user_id);

create policy "Users can select" on public.user_infos
    for select using (auth.uid() = user_id);

-- ================================================
-- Feature requests table (this is features that users can vote on)
-- ================================================
CREATE TABLE public.feature_requests (
    id uuid PRIMARY KEY default gen_random_uuid (),
    creation_date timestamp with time zone not null default now(),
    last_update_date timestamp with time zone not null default now(),
    title jsonb NOT NULL, -- ex : {en: "title", fr: "titre"} add any language your app support
    description jsonb NOT NULL, -- ex : {en: "description", fr: "description"} add any language your app support
    votes smallint NOT NULL,
    active boolean NOT NULL
) tablespace pg_default;

ALTER TABLE public.feature_requests ENABLE ROW LEVEL SECURITY;

create policy "Users can select" on public.feature_requests
    for select using (true);

-- ================================================
-- Feature votes table (this is the votes that users can cast on features)
-- ================================================

create TABLE public.feature_votes (
  id uuid PRIMARY KEY default gen_random_uuid (),
  creation_date timestamp with time zone not null default now(),
  user_uid uuid NOT NULL,
  feature_id uuid NOT NULL,
  constraint user_uid_fkey foreign key (user_uid) references auth.users (id) on update cascade on delete cascade,
  constraint feature_id_fkey foreign key (feature_id) references public.feature_requests (id) on update cascade on delete cascade
) tablespace pg_default;

ALTER TABLE public.feature_votes ENABLE ROW LEVEL SECURITY;

create policy "Users can insert" on public.feature_votes
    for insert with check (auth.uid() = user_uid);

create policy "Users can delete" on public.feature_votes
    for delete using (auth.uid() = user_uid);

create policy "Users can select" on public.feature_votes
    for select using (auth.uid() = user_uid);

-- ===========================================================================
-- awaiting_feature_requests table (user feature request that you will review)
-- ===========================================================================

create TABLE public.awaiting_feature_requests (
  id uuid PRIMARY KEY default gen_random_uuid (),
  creation_date timestamp with time zone not null default now(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  user_uid uuid NOT NULL,
  constraint user_uid_fkey foreign key (user_uid) references auth.users (id) on update cascade on delete cascade
) tablespace pg_default;

ALTER TABLE public.awaiting_feature_requests ENABLE ROW LEVEL SECURITY;

create policy "Users can insert" on public.awaiting_feature_requests 
    for insert with check (auth.uid() = user_uid);

create policy "Users can select" on public.awaiting_feature_requests
    for select using (auth.uid() = user_uid);

CREATE OR REPLACE FUNCTION increment_feature_request_value()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE feature_requests
    SET votes = votes + 1
    WHERE id = NEW.feature_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER after_feature_vote_insert
AFTER INSERT ON feature_votes
FOR EACH ROW
EXECUTE FUNCTION increment_feature_request_value();

CREATE OR REPLACE FUNCTION decrement_feature_request_value()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE feature_requests
    SET votes = votes - 1
    WHERE id = OLD.feature_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER after_feature_vote_delete
AFTER DELETE ON feature_votes
FOR EACH ROW
EXECUTE FUNCTION decrement_feature_request_value();


-- ================================================
-- This trigger automatically creates a profile entry when a new user signs up via Supabase Auth.
-- See https://supabase.com/docs/guides/auth/managing-user-data#using-triggers for more details.
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, name, avatar_url, email)
  values (new.id, new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'avatar_url', new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_update_user()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.users
  SET email = NEW.email
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_updated
AFTER UPDATE ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.handle_update_user();

-- Set up Storage for avatars
insert into storage.buckets (id, name) values ('avatars', 'avatars') on conflict (id) do nothing;


-- Set up access controls for storage.
-- See https://supabase.com/docs/guides/storage#policy-examples for more details.

-- Update 23/08/2025 this seems not working anymore. This seems enabled by default
-- ERROR:  42501: must be owner of table objects ()
-- alter table storage.objects enable row level security;

create policy "Avatar images are publicly accessible." on storage.objects
  for select using (bucket_id = 'avatars');

create policy "Allow authenticated users to upload an avatar." on storage.objects
  for insert to authenticated with check (bucket_id = 'avatars');

create policy "Allow authenticated users to update their own files"on storage.objects
  for update to authenticated using (bucket_id = 'avatars') with check ( auth.uid()::text = owner_id);

create policy "Allow authenticated users to delete their own files" on storage.objects
  for delete to authenticated using ( bucket_id = 'avatars' AND auth.uid()::text = owner_id );

-- Dashboard setup
-- ----------------------------------------------
-- ADMIN ROLE SETUP 
-- ----------------------------------------------
create type public.app_permission as enum ('admin_all');
create type public.app_role as enum ('admin');

-- USER ROLES
create table public.user_roles (
  id        bigint generated by default as identity primary key,
  user_id   uuid references auth.users on delete cascade not null,
  role      app_role not null,
  unique (user_id, role)
);
comment on table public.user_roles is 'Application roles for each user.';

-- ROLE PERMISSIONS
create table public.role_permissions (
  id           bigint generated by default as identity primary key,
  role         app_role not null,
  permission   app_permission not null,
  unique (role, permission)
);
comment on table public.role_permissions is 'Application permissions for each role.';

alter table public.role_permissions enable row level security;

insert into public.role_permissions (role, permission)
values
  ('admin', 'admin_all');

-- Create the auth hook function to add the user role to the claims
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
  declare
    claims jsonb;
    user_role public.app_role;
  begin
    -- Fetch the user role in the user_roles table
    select role into user_role from public.user_roles where user_id = (event->>'user_id')::uuid;

    claims := event->'claims';

    if user_role is not null then
      -- Set the claim
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    else
      claims := jsonb_set(claims, '{user_role}', 'null');
    end if;

    -- Update the 'claims' object in the original event
    event := jsonb_set(event, '{claims}', claims);

    -- Return the modified or original event
    return event;
  end;
$$;

grant usage on schema public to supabase_auth_admin;

grant execute on function public.custom_access_token_hook
  to supabase_auth_admin;

revoke execute on function public.custom_access_token_hook
  from authenticated, anon, public;

grant all on table public.user_roles to supabase_auth_admin;

revoke all
  on table public.user_roles
  from authenticated, anon, public;

create policy "Allow auth admin to read user roles" ON public.user_roles 
as permissive for select 
to supabase_auth_admin 
using (true);

-- Accessing custom claims in RLS policies
create or replace function public.authorize(
  requested_permission app_permission
)
returns boolean as $$
declare
  bind_permissions int;
  user_role public.app_role;
begin
  -- Fetch user role once and store it to reduce number of calls
  select (auth.jwt() ->> 'user_role')::public.app_role into user_role;

  select count(*)
  into bind_permissions
  from public.role_permissions
  where role_permissions.permission = requested_permission
    and role_permissions.role = user_role;

  return bind_permissions > 0;
end;
$$ language plpgsql stable security definer set search_path = '';

-- ----------------------------------------------
-- NOTIFICATION CAMPAIN SETUP START
-- ----------------------------------------------
create type public.notification_status as enum ('scheduled', 'sent', 'failed');

create table public.notification_campaigns (
  id            uuid primary key default (gen_random_uuid()),
  title         text not null,
  body          text not null,
  scheduled_at  timestamp with time zone not null,
  created_at    timestamp with time zone default now(),
  channel       text null,
  extra_data    jsonb null,
  status        notification_status not null
) tablespace pg_default;

alter table public.notification_campaigns enable row level security;

create policy "Enable read only for admin" on public.notification_campaigns 
for select TO public USING ((SELECT authorize('admin_all')));

create policy "Enable insert for admin" on public.notification_campaigns 
  FOR INSERT with check ((SELECT authorize('admin_all')));

create policy "Enable update for admin" on public.notification_campaigns 
for update TO public USING ((SELECT authorize('admin_all')));

create policy "Enable delete for admin" on public.notification_campaigns
for delete TO public USING ((SELECT authorize('admin_all')));

-- ----------------------------------------------
-- POLICIES UPDATE 
-- ----------------------------------------------

DROP POLICY IF EXISTS "Users can select" ON public.user_infos;
DROP POLICY IF EXISTS "Enable read based on user_id." ON public.subscriptions;
DROP POLICY IF EXISTS "Enable read based on user_id." ON public.notifications;
DROP POLICY IF EXISTS "Enable select access for users based on their user ID *" ON public.devices;

-- user_infos table 
CREATE POLICY "Users can select" ON public.user_infos
  FOR SELECT TO public USING (auth.uid() = user_id OR (SELECT authorize('admin_all')));

-- subscription table 
create policy "Enable read based on user_id." on public.subscriptions
  for select TO public USING (auth.uid() = user_id OR (SELECT authorize('admin_all')));

CREATE POLICY "Enable insert for admin" ON public.subscriptions 
  FOR INSERT with check ((SELECT authorize('admin_all')));

-- notifications table
create policy "Enable read based on user_id." on public.notifications
  for select TO public USING (auth.uid() = user_id OR (SELECT authorize('admin_all')));

CREATE POLICY "Enable insert for admin" ON public.notifications 
  FOR INSERT with check ((SELECT authorize('admin_all')));

-- devices table
create policy "Enable select access for users based on their user ID *" on public.devices
  for select TO public USING (auth.uid() = user_id OR (SELECT authorize('admin_all')));

-- insert policy for feature_requests
create policy "Enable inset for admin" on public.feature_requests
  for insert with check((SELECT authorize('admin_all')));

-- update policy for feature_requests
create policy "Enable update for admin" on public.feature_requests
  for update TO public USING ((SELECT authorize('admin_all')));  

-- select policy for awaiting_feature_requests
create policy "Enable select for admin" on public.awaiting_feature_requests
  for select TO public USING ((SELECT authorize('admin_all')));


-- ----------------------------------------------
-- VIEWS SETUP
-- ----------------------------------------------
-- daily subscriptions by device type view
CREATE OR REPLACE VIEW public.subscription_daily_by_device AS
WITH subs AS (
  SELECT
    date_trunc('day', s.creation_date)::date AS day,
    CASE
      WHEN s.store = 'PLAY_STORE' THEN 'android'
      WHEN s.store = 'APPLE_STORE' THEN 'ios'
      ELSE NULL
    END AS device_type
  FROM public.subscriptions s
  WHERE s.creation_date IS NOT NULL
)
SELECT
  day,
  device_type,
  COUNT(*)::bigint AS subscriptions_count
FROM subs
WHERE device_type IS NOT NULL
GROUP BY day, device_type
ORDER BY day, device_type;

-- daily user counts view + onboarded counts
CREATE OR REPLACE VIEW public.user_daily_counts AS
WITH bounds AS (
  SELECT
    date_trunc('day', MIN(u.creation_date))::date AS start_day,
    date_trunc('day', NOW())::date AS end_day
  FROM public.users u
),
day_series AS (
  SELECT generate_series(b.start_day, b.end_day, interval '1 day')::date AS day
  FROM bounds b
),
daily AS (
  SELECT
    date_trunc('day', u.creation_date)::date AS day,
    count(*) AS users_count,
    count(*) FILTER (WHERE u.onboarded = true) AS onboarded_count
  FROM public.users u
  GROUP BY 1
)
SELECT
  ds.day,
  COALESCE(d.users_count, 0) AS users_count,
  COALESCE(d.onboarded_count, 0) AS onboarded_count
FROM day_series ds
LEFT JOIN daily d USING (day)
ORDER BY ds.day;