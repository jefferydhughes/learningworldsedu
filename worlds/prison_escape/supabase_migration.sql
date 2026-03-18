-- ============================================================
-- BLIP GAME PLATFORM — Migration for Skill Samurai Academy
-- Run this in: Supabase Dashboard > SQL Editor
-- Project: omgtqczbzmgvtwptdbxm
--
-- This adds game world tables alongside your existing
-- students, franchise_locations, and auth.users tables.
-- ============================================================

-- 1. GAME WORLDS — registry of playable game worlds
CREATE TABLE public.game_worlds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug text NOT NULL UNIQUE,
    title text NOT NULL,
    description text,
    difficulty text NOT NULL DEFAULT 'intermediate'
        CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    chapter_count integer NOT NULL DEFAULT 4,
    lua_script_version text,
    is_published boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2. GAME CHAPTERS — coding challenges within each world
CREATE TABLE public.game_chapters (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    world_id uuid NOT NULL REFERENCES public.game_worlds(id) ON DELETE CASCADE,
    chapter_number integer NOT NULL,
    title text NOT NULL,
    description text,
    concepts text[],
    code_template text NOT NULL,
    correct_code text NOT NULL,
    hint_text text,
    max_attempts integer DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (world_id, chapter_number)
);

-- 3. GAME ENROLLMENTS — links students to game worlds
--    FKs to your existing students table and franchise_locations
CREATE TABLE public.game_enrollments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    world_id uuid NOT NULL REFERENCES public.game_worlds(id) ON DELETE CASCADE,
    location_id uuid REFERENCES public.franchise_locations(id),
    instructor_name text,
    camp_session text,
    enrolled_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    UNIQUE (student_id, world_id)
);

-- 4. CODE SUBMISSIONS — every student code attempt
CREATE TABLE public.game_submissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    chapter_id uuid NOT NULL REFERENCES public.game_chapters(id) ON DELETE CASCADE,
    code_submitted text NOT NULL,
    is_correct boolean NOT NULL DEFAULT false,
    error_message text,
    error_type text
        CHECK (error_type IS NULL OR error_type IN ('syntax', 'runtime', 'logic', 'validation')),
    attempt_number integer NOT NULL DEFAULT 1,
    submitted_at timestamptz NOT NULL DEFAULT now()
);

-- 5. STUDENT PROGRESS — current state per student per chapter
CREATE TABLE public.game_progress (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    chapter_id uuid NOT NULL REFERENCES public.game_chapters(id) ON DELETE CASCADE,
    world_id uuid NOT NULL REFERENCES public.game_worlds(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'locked'
        CHECK (status IN ('locked', 'available', 'in_progress', 'completed')),
    attempts integer NOT NULL DEFAULT 0,
    first_attempt_at timestamptz,
    completed_at timestamptz,
    best_code text,
    UNIQUE (student_id, chapter_id)
);

-- 6. LEADERBOARD — scoring and rankings per world
CREATE TABLE public.game_leaderboard (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    world_id uuid NOT NULL REFERENCES public.game_worlds(id) ON DELETE CASCADE,
    location_id uuid REFERENCES public.franchise_locations(id),
    total_attempts integer NOT NULL DEFAULT 0,
    chapters_completed integer NOT NULL DEFAULT 0,
    total_time_seconds integer,
    completion_rank integer,
    started_at timestamptz,
    finished_at timestamptz,
    score integer NOT NULL DEFAULT 0,
    UNIQUE (student_id, world_id)
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_game_submissions_student ON public.game_submissions(student_id, submitted_at DESC);
CREATE INDEX idx_game_submissions_chapter ON public.game_submissions(chapter_id, is_correct);
CREATE INDEX idx_game_progress_student ON public.game_progress(student_id, world_id);
CREATE INDEX idx_game_progress_status ON public.game_progress(world_id, status);
CREATE INDEX idx_game_leaderboard_world ON public.game_leaderboard(world_id, score DESC);
CREATE INDEX idx_game_leaderboard_location ON public.game_leaderboard(location_id, score DESC);
CREATE INDEX idx_game_enrollments_student ON public.game_enrollments(student_id);
CREATE INDEX idx_game_enrollments_location ON public.game_enrollments(location_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.game_worlds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_leaderboard ENABLE ROW LEVEL SECURITY;

-- Published worlds and their chapters: readable by anyone authenticated
CREATE POLICY "Anyone can read published worlds"
    ON public.game_worlds FOR SELECT
    USING (is_published = true);

CREATE POLICY "Anyone can read chapters of published worlds"
    ON public.game_chapters FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.game_worlds w
            WHERE w.id = game_chapters.world_id AND w.is_published = true
        )
    );

-- Students see their own enrollments (matched via students.user_id → auth.uid())
CREATE POLICY "Students see own enrollments"
    ON public.game_enrollments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = game_enrollments.student_id AND s.user_id = auth.uid()
        )
    );

-- Students see and create their own submissions
CREATE POLICY "Students see own submissions"
    ON public.game_submissions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = game_submissions.student_id AND s.user_id = auth.uid()
        )
    );

CREATE POLICY "Students insert own submissions"
    ON public.game_submissions FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = game_submissions.student_id AND s.user_id = auth.uid()
        )
    );

-- Students see their own progress
CREATE POLICY "Students see own progress"
    ON public.game_progress FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.students s
            WHERE s.id = game_progress.student_id AND s.user_id = auth.uid()
        )
    );

-- Leaderboard: readable by all authenticated users (public scores)
CREATE POLICY "Anyone can read leaderboard"
    ON public.game_leaderboard FOR SELECT
    USING (true);

-- Service role (Edge Functions) bypasses all RLS for server-side writes

-- ============================================================
-- SEED: Prison Escape world + 4 chapters
-- ============================================================

INSERT INTO public.game_worlds (slug, title, description, difficulty, chapter_count, is_published)
VALUES (
    'prison-escape',
    'Prison Escape',
    'Build a prison with laser hazards, checkpoints, and a victory zone. Learn functions, collision callbacks, timers, and 3D positioning.',
    'intermediate',
    4,
    true
);

-- Chapter 1: Killer Lasers
INSERT INTO public.game_chapters (world_id, chapter_number, title, description, concepts, code_template, correct_code, hint_text)
SELECT w.id, 1, 'Killer Lasers',
    'Make the laser beams deadly. When a player touches a laser, send them falling and respawn them.',
    ARRAY['functions', 'collision callbacks', 'Number3', 'Timer'],
    E'studentCode.laserOnCollision = function(laser, player)\n    player.Position = Number3(0, _____, 0)\n    print(player._____ .. " hit a laser!")\n    Timer(_____, function()\n        if spawnPosition then\n            player.Position = spawnPosition:Copy()\n            player.Velocity = Number3.Zero\n        end\n    end)\nend',
    E'studentCode.laserOnCollision = function(laser, player)\n    player.Position = Number3(0, -100, 0)\n    print(player.Username .. " hit a laser!")\n    Timer(1.0, function()\n        if spawnPosition then\n            player.Position = spawnPosition:Copy()\n            player.Velocity = Number3.Zero\n        end\n    end)\nend',
    'To kill a player, move them far below the map. -100 is a good Y position. player.Username gives the name. Timer takes seconds.'
FROM public.game_worlds w WHERE w.slug = 'prison-escape';

-- Chapter 2: Flashing Lasers
INSERT INTO public.game_chapters (world_id, chapter_number, title, description, concepts, code_template, correct_code, hint_text)
SELECT w.id, 2, 'Flashing Lasers',
    'Set the timing for flashing lasers — how long they stay off (safe) and on (deadly).',
    ARRAY['timers', 'timing values', 'on/off states'],
    E'studentCode.flashTimings = function()\n    return {\n        offTime = _____,\n        onTime = _____\n    }\nend',
    E'studentCode.flashTimings = function()\n    return {\n        offTime = 1.0,\n        onTime = 1.0\n    }\nend',
    'Try values between 0.5 and 2.0 seconds. Equal values give a steady rhythm. What happens if offTime is 0?'
FROM public.game_worlds w WHERE w.slug = 'prison-escape';

-- Chapter 3: Checkpoint System
INSERT INTO public.game_chapters (world_id, chapter_number, title, description, concepts, code_template, correct_code, hint_text)
SELECT w.id, 3, 'Checkpoint System',
    'Save the player''s position when they touch a checkpoint pad. Next death respawns here.',
    ARRAY['Number3 positioning', 'state saving', 'Y-offset'],
    E'studentCode.checkpointOnTouch = function(checkpoint, player, index)\n    spawnPosition = checkpoint._____ + Number3(0, _____, 0)\n    print(player.Username .. " reached Checkpoint " .. _____)\nend',
    E'studentCode.checkpointOnTouch = function(checkpoint, player, index)\n    spawnPosition = checkpoint.Position + Number3(0, 3, 0)\n    print(player.Username .. " reached Checkpoint " .. index)\nend',
    'checkpoint.Position gives the pad''s location. Add 3 studs UP so you don''t spawn inside the floor. index is the checkpoint number.'
FROM public.game_worlds w WHERE w.slug = 'prison-escape';

-- Chapter 4: Victory Zone
INSERT INTO public.game_chapters (world_id, chapter_number, title, description, concepts, code_template, correct_code, hint_text)
SELECT w.id, 4, 'Victory Zone',
    'Show a floating "YOU ESCAPED!" message when the player reaches the final room.',
    ARRAY['Text objects', 'Color', 'Timer', 'Destroy'],
    E'studentCode.victoryOnTouch = function(player)\n    print(player.Username .. " escaped the prison!")\n    local victoryText = _____()\n    victoryText.Text = "_____"\n    victoryText.Color = Color(255, _____, 0)\n    victoryText.BackgroundColor = Color(30, 30, 30)\n    victoryText.FontSize = _____\n    victoryText.Position = player.Position + Number3(0, 10, 0)\n    victoryText:SetParent(World)\n    Timer(_____, function()\n        victoryText:_____()\n    end)\nend',
    E'studentCode.victoryOnTouch = function(player)\n    print(player.Username .. " escaped the prison!")\n    local victoryText = Text()\n    victoryText.Text = "YOU ESCAPED!"\n    victoryText.Color = Color(255, 215, 0)\n    victoryText.BackgroundColor = Color(30, 30, 30)\n    victoryText.FontSize = 40\n    victoryText.Position = player.Position + Number3(0, 10, 0)\n    victoryText:SetParent(World)\n    Timer(5.0, function()\n        victoryText:Destroy()\n    end)\nend',
    'Text() creates a floating text object. Color(255, 215, 0) = gold. FontSize 40 is big. :Destroy() removes objects.'
FROM public.game_worlds w WHERE w.slug = 'prison-escape';
