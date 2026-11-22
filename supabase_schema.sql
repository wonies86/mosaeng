-- =========================================================
--  모생일기 · 콘티 노트 — Supabase 스키마
--  Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 [Run]
--  (한 번만 실행하면 됩니다. 다시 실행해도 안전합니다.)
-- =========================================================

create table if not exists public.mosaeng_contis (
  id          uuid primary key,
  title       text        not null default '',
  author      text        not null default '모과',      -- 모과 | 생강 | 함께
  cast        text[]      not null default '{}',         -- 등장인물: 모과 | 생강 | 자두 | 대추 | 한라봉 | 멜론 | 적포도 | 능금 | 청포도
  category    text        not null default 'wedding',   -- wedding | daily | trip | diet
  status      text        not null default 'idea',      -- idea | conti | making | done
  cuts        jsonb       not null default '["","","",""]'::jsonb,  -- 컷 배열 (4칸 기본, 9컷까지 늘어남)
  memo        text        not null default '',
  tags        text        not null default '',
  deleted     boolean     not null default false,        -- 양쪽 폰 동기화용 소프트 삭제
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 이미 만들어 둔 테이블(=cast 컬럼이 없는 예전 스키마)에도 안전하게 추가
-- 이 줄을 실행하지 않으면 앱은 cast 없이 저장을 계속합니다(둘 다 정상 동작).
alter table public.mosaeng_contis
  add column if not exists cast text[] not null default '{}';

-- 최근 수정순 조회용
create index if not exists mosaeng_contis_updated_idx
  on public.mosaeng_contis (updated_at desc);

-- 같은 콘티를 두 폰에서 동시에 고쳐도 마지막 저장이 이기도록 updated_at 자동 갱신
create or replace function public.mosaeng_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists mosaeng_touch on public.mosaeng_contis;
create trigger mosaeng_touch
  before update on public.mosaeng_contis
  for each row execute function public.mosaeng_touch_updated_at();

-- ---------------------------------------------------------
-- 접근 권한 (RLS)
--  두 사람만 아는 anon key로 접근하는 사적인 메모장이라
--  anon 역할에 읽기/쓰기를 열어 둡니다.
--  anon key는 절대 공개 게시판·SNS에 붙이지 마세요.
-- ---------------------------------------------------------
alter table public.mosaeng_contis enable row level security;

drop policy if exists "mosaeng all for anon" on public.mosaeng_contis;
create policy "mosaeng all for anon"
  on public.mosaeng_contis
  for all
  to anon, authenticated
  using (true)
  with check (true);

-- ---------------------------------------------------------
-- 실시간(Realtime) 구독 켜기
-- ---------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.mosaeng_contis;
  exception when duplicate_object then
    null;  -- 이미 추가되어 있으면 그대로 둠
  end;
end $$;

-- ---------------------------------------------------------
-- 확인용 (선택): 테이블이 잘 만들어졌는지 보기
-- select count(*) from public.mosaeng_contis;
-- ---------------------------------------------------------
