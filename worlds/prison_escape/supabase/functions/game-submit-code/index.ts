import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * game-submit-code
 *
 * Called by the LMS when a student submits code for a chapter.
 * - Validates the student is enrolled
 * - Records the submission
 * - Checks if the code matches the correct answer
 * - Updates progress and leaderboard
 * - Returns validation result + whether to inject into game server
 *
 * POST body:
 * {
 *   student_id: uuid,       // from students table
 *   world_slug: string,     // e.g. "prison-escape"
 *   chapter_number: number, // 1-4
 *   code: string            // the student's code submission
 * }
 */
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Service role client — bypasses RLS for server-side writes
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { student_id, world_slug, chapter_number, code } = await req.json();

    // Validate required fields
    if (!student_id || !world_slug || !chapter_number || !code) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing required fields: student_id, world_slug, chapter_number, code",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Look up the world and chapter
    const { data: world, error: worldErr } = await supabase
      .from("game_worlds")
      .select("id")
      .eq("slug", world_slug)
      .eq("is_published", true)
      .single();

    if (worldErr || !world) {
      return new Response(
        JSON.stringify({ success: false, error: "World not found or not published" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: chapter, error: chapterErr } = await supabase
      .from("game_chapters")
      .select("id, correct_code, hint_text")
      .eq("world_id", world.id)
      .eq("chapter_number", chapter_number)
      .single();

    if (chapterErr || !chapter) {
      return new Response(
        JSON.stringify({ success: false, error: `Chapter ${chapter_number} not found` }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Check enrollment (create if not exists)
    const { data: enrollment } = await supabase
      .from("game_enrollments")
      .select("id")
      .eq("student_id", student_id)
      .eq("world_id", world.id)
      .single();

    if (!enrollment) {
      // Auto-enroll on first submission
      await supabase.from("game_enrollments").insert({
        student_id,
        world_id: world.id,
      });
    }

    // 3. Count previous attempts for this chapter
    const { count: prevAttempts } = await supabase
      .from("game_submissions")
      .select("id", { count: "exact", head: true })
      .eq("student_id", student_id)
      .eq("chapter_id", chapter.id);

    const attemptNumber = (prevAttempts || 0) + 1;

    // 4. Validate the code
    const trimmedCode = code.trim();
    const trimmedCorrect = chapter.correct_code.trim();

    // Normalize whitespace for comparison (students might have different spacing)
    const normalize = (s: string) =>
      s.replace(/\s+/g, " ").replace(/\s*\n\s*/g, "\n").trim();

    const isCorrect = normalize(trimmedCode) === normalize(trimmedCorrect);

    // Determine error type if incorrect
    let errorType: string | null = null;
    let errorMessage: string | null = null;

    if (!isCorrect) {
      // Basic syntax check: look for common Lua syntax issues
      if (trimmedCode.includes("_____")) {
        errorType = "validation";
        errorMessage = "Code still contains blank placeholders (_____). Fill in all the blanks.";
      } else if (!trimmedCode.includes("function")) {
        errorType = "syntax";
        errorMessage = "Missing 'function' keyword. Make sure you're defining a function.";
      } else if (!trimmedCode.includes("end")) {
        errorType = "syntax";
        errorMessage = "Missing 'end' keyword. Every function needs to close with 'end'.";
      } else {
        errorType = "logic";
        errorMessage = "Code runs but produces wrong behavior. Check the values you filled in.";
        // Include hint after 3+ attempts
        if (attemptNumber >= 3 && chapter.hint_text) {
          errorMessage += " Hint: " + chapter.hint_text;
        }
      }
    }

    // 5. Record the submission
    await supabase.from("game_submissions").insert({
      student_id,
      chapter_id: chapter.id,
      code_submitted: trimmedCode,
      is_correct: isCorrect,
      error_message: errorMessage,
      error_type: errorType,
      attempt_number: attemptNumber,
    });

    // 6. Update progress
    const { data: progress } = await supabase
      .from("game_progress")
      .select("id, status, attempts")
      .eq("student_id", student_id)
      .eq("chapter_id", chapter.id)
      .single();

    if (progress) {
      // Update existing progress
      const updates: Record<string, unknown> = {
        attempts: progress.attempts + 1,
        status: isCorrect ? "completed" : "in_progress",
      };
      if (isCorrect) {
        updates.completed_at = new Date().toISOString();
        updates.best_code = trimmedCode;
      }
      await supabase
        .from("game_progress")
        .update(updates)
        .eq("id", progress.id);
    } else {
      // Create new progress record
      await supabase.from("game_progress").insert({
        student_id,
        chapter_id: chapter.id,
        world_id: world.id,
        status: isCorrect ? "completed" : "in_progress",
        attempts: 1,
        first_attempt_at: new Date().toISOString(),
        completed_at: isCorrect ? new Date().toISOString() : null,
        best_code: isCorrect ? trimmedCode : null,
      });

      // Unlock next chapter if this one is correct
      if (isCorrect) {
        const nextChapterNum = chapter_number + 1;
        const { data: nextChapter } = await supabase
          .from("game_chapters")
          .select("id")
          .eq("world_id", world.id)
          .eq("chapter_number", nextChapterNum)
          .single();

        if (nextChapter) {
          // Check if next chapter progress already exists
          const { data: nextProgress } = await supabase
            .from("game_progress")
            .select("id")
            .eq("student_id", student_id)
            .eq("chapter_id", nextChapter.id)
            .single();

          if (!nextProgress) {
            await supabase.from("game_progress").insert({
              student_id,
              chapter_id: nextChapter.id,
              world_id: world.id,
              status: "available",
              attempts: 0,
            });
          }
        }
      }
    }

    // 7. Update leaderboard
    const { data: allProgress } = await supabase
      .from("game_progress")
      .select("status, attempts")
      .eq("student_id", student_id)
      .eq("world_id", world.id);

    const completedCount = allProgress?.filter((p) => p.status === "completed").length || 0;
    const totalAttempts = allProgress?.reduce((sum, p) => sum + p.attempts, 0) || 0;

    // Score: higher is better. Reward completion, penalize attempts.
    const score = completedCount * 1000 - totalAttempts * 10;

    const { data: leaderEntry } = await supabase
      .from("game_leaderboard")
      .select("id, started_at")
      .eq("student_id", student_id)
      .eq("world_id", world.id)
      .single();

    const now = new Date().toISOString();

    if (leaderEntry) {
      const updates: Record<string, unknown> = {
        total_attempts: totalAttempts,
        chapters_completed: completedCount,
        score,
      };
      if (completedCount >= 4) {
        updates.finished_at = now;
        if (leaderEntry.started_at) {
          updates.total_time_seconds = Math.round(
            (Date.now() - new Date(leaderEntry.started_at).getTime()) / 1000
          );
        }
      }
      await supabase
        .from("game_leaderboard")
        .update(updates)
        .eq("id", leaderEntry.id);
    } else {
      await supabase.from("game_leaderboard").insert({
        student_id,
        world_id: world.id,
        total_attempts: totalAttempts,
        chapters_completed: completedCount,
        started_at: now,
        finished_at: completedCount >= 4 ? now : null,
        score,
      });
    }

    // 8. Return result
    return new Response(
      JSON.stringify({
        success: true,
        is_correct: isCorrect,
        attempt_number: attemptNumber,
        chapters_completed: completedCount,
        error_type: errorType,
        error_message: errorMessage,
        // If correct, include the code for injection into the game server
        inject_code: isCorrect ? trimmedCode : null,
        chapter: chapter_number,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
