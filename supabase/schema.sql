-- ============================================================================
-- TermFlow Supabase PostgreSQL Schema
-- 包含：5 张核心同步表、索引、LWW 冲突保护触发器、Row Level Security (RLS)、Realtime
-- 使用方法：直接复制全部 SQL 粘贴至 Supabase Dashboard -> SQL Editor 运行
-- ============================================================================

-- 1. 通用触发器函数：
--    - 写入时自动维护 server_updated_at = NOW() 作为增量拉取游标（避免客户端时钟偏差漏同步）
--    - UPDATE 时执行服务端 LWW 守卫：若传入的 updated_at 早于云端已有 updated_at，则忽略过期覆盖
CREATE OR REPLACE FUNCTION public.termflow_lww_and_stamp()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.server_updated_at := NOW();
    IF NEW.created_at IS NULL THEN
      NEW.created_at := NOW();
    END IF;
    IF NEW.updated_at IS NULL THEN
      NEW.updated_at := NOW();
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.updated_at < OLD.updated_at THEN
      RETURN NULL;
    END IF;
    NEW.server_updated_at := NOW();
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. 核心业务表定义
-- ============================================================================

-- 2.1 学期表
CREATE TABLE IF NOT EXISTS public.semesters (
  id                UUID PRIMARY KEY,
  user_id           UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 120),
  start_date        DATE NOT NULL,
  end_date          DATE NOT NULL CHECK (end_date >= start_date),
  is_active         BOOLEAN NOT NULL DEFAULT FALSE,
  week_starts_on    SMALLINT NOT NULL DEFAULT 1 CHECK (week_starts_on BETWEEN 1 AND 7),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_semesters_user_sync
  ON public.semesters (user_id, server_updated_at);
CREATE INDEX IF NOT EXISTS idx_semesters_user_active
  ON public.semesters (user_id, is_active) WHERE is_deleted = FALSE;

-- 2.2 目标表（学期 / 月 / 周三级目标统一建模）
CREATE TABLE IF NOT EXISTS public.goals (
  id                UUID PRIMARY KEY,
  user_id           UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  semester_id       UUID REFERENCES public.semesters(id) ON DELETE SET NULL,
  parent_goal_id    UUID REFERENCES public.goals(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
  level             TEXT NOT NULL CHECK (level IN ('semester', 'monthly', 'weekly')),
  title             TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  description       TEXT NOT NULL DEFAULT '',
  category          TEXT NOT NULL DEFAULT 'academic',
  target_year       SMALLINT,
  target_month      SMALLINT CHECK (target_month IS NULL OR target_month BETWEEN 1 AND 12),
  target_week_index SMALLINT CHECK (target_week_index IS NULL OR target_week_index >= 1),
  week_start_date   DATE,
  progress_mode     TEXT NOT NULL DEFAULT 'auto' CHECK (progress_mode IN ('auto', 'manual')),
  manual_progress   DOUBLE PRECISION NOT NULL DEFAULT 0.0 CHECK (manual_progress BETWEEN 0.0 AND 1.0),
  cached_progress   DOUBLE PRECISION NOT NULL DEFAULT 0.0 CHECK (cached_progress BETWEEN 0.0 AND 1.0),
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
  color_hex         TEXT NOT NULL DEFAULT '#4F6BED',
  sort_order        INTEGER NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_goals_user_sync
  ON public.goals (user_id, server_updated_at);
CREATE INDEX IF NOT EXISTS idx_goals_user_level
  ON public.goals (user_id, level, semester_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_goals_parent
  ON public.goals (parent_goal_id) WHERE is_deleted = FALSE;

-- 2.3 任务表（日计划待办 + 周计划待办池）
CREATE TABLE IF NOT EXISTS public.tasks (
  id                UUID PRIMARY KEY,
  user_id           UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  semester_id       UUID REFERENCES public.semesters(id) ON DELETE SET NULL,
  goal_id           UUID REFERENCES public.goals(id) ON DELETE SET NULL,
  title             TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 300),
  notes             TEXT NOT NULL DEFAULT '',
  priority          SMALLINT NOT NULL DEFAULT 2 CHECK (priority BETWEEN 0 AND 3),
  estimated_minutes INTEGER CHECK (estimated_minutes IS NULL OR estimated_minutes >= 0),
  scheduled_date    DATE,
  week_start_date   DATE,
  due_at            TIMESTAMPTZ,
  is_completed      BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at      TIMESTAMPTZ,
  postpone_count    INTEGER NOT NULL DEFAULT 0 CHECK (postpone_count >= 0),
  original_date     DATE,
  weight            INTEGER NOT NULL DEFAULT 1 CHECK (weight >= 1),
  sort_order        INTEGER NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_tasks_user_sync
  ON public.tasks (user_id, server_updated_at);
CREATE INDEX IF NOT EXISTS idx_tasks_user_date
  ON public.tasks (user_id, scheduled_date) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_tasks_user_week
  ON public.tasks (user_id, week_start_date) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_tasks_goal
  ON public.tasks (goal_id) WHERE is_deleted = FALSE;

-- 2.4 标签表
CREATE TABLE IF NOT EXISTS public.tags (
  id                UUID PRIMARY KEY,
  user_id           UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50),
  color_hex         TEXT NOT NULL DEFAULT '#64748B',
  icon_name         TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_tags_user_sync
  ON public.tags (user_id, server_updated_at);

-- 2.5 任务-标签关联表
CREATE TABLE IF NOT EXISTS public.task_tags (
  id                UUID PRIMARY KEY,
  user_id           UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id           UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  tag_id            UUID NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT uq_task_tags_pair UNIQUE (task_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_task_tags_user_sync
  ON public.task_tags (user_id, server_updated_at);
CREATE INDEX IF NOT EXISTS idx_task_tags_task
  ON public.task_tags (task_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- 3. 绑定 LWW & server_updated_at 触发器
-- ============================================================================

DROP TRIGGER IF EXISTS trg_semesters_lww ON public.semesters;
CREATE TRIGGER trg_semesters_lww
  BEFORE INSERT OR UPDATE ON public.semesters
  FOR EACH ROW EXECUTE FUNCTION public.termflow_lww_and_stamp();

DROP TRIGGER IF EXISTS trg_goals_lww ON public.goals;
CREATE TRIGGER trg_goals_lww
  BEFORE INSERT OR UPDATE ON public.goals
  FOR EACH ROW EXECUTE FUNCTION public.termflow_lww_and_stamp();

DROP TRIGGER IF EXISTS trg_tasks_lww ON public.tasks;
CREATE TRIGGER trg_tasks_lww
  BEFORE INSERT OR UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.termflow_lww_and_stamp();

DROP TRIGGER IF EXISTS trg_tags_lww ON public.tags;
CREATE TRIGGER trg_tags_lww
  BEFORE INSERT OR UPDATE ON public.tags
  FOR EACH ROW EXECUTE FUNCTION public.termflow_lww_and_stamp();

DROP TRIGGER IF EXISTS trg_task_tags_lww ON public.task_tags;
CREATE TRIGGER trg_task_tags_lww
  BEFORE INSERT OR UPDATE ON public.task_tags
  FOR EACH ROW EXECUTE FUNCTION public.termflow_lww_and_stamp();

-- ============================================================================
-- 4. Row Level Security (RLS) 权限隔离策略（每用户仅能读写自己的数据）
-- ============================================================================

ALTER TABLE public.semesters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "semesters_owner_all" ON public.semesters;
CREATE POLICY "semesters_owner_all" ON public.semesters
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "goals_owner_all" ON public.goals;
CREATE POLICY "goals_owner_all" ON public.goals
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tasks_owner_all" ON public.tasks;
CREATE POLICY "tasks_owner_all" ON public.tasks
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tags_owner_all" ON public.tags;
CREATE POLICY "tags_owner_all" ON public.tags
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "task_tags_owner_all" ON public.task_tags;
CREATE POLICY "task_tags_owner_all" ON public.task_tags
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 5. 开启 Supabase Realtime（用于多设备实时增量推送通知）
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'semesters'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.semesters;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'goals'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.goals;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'tasks'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'tags'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tags;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'task_tags'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.task_tags;
  END IF;
END $$;
