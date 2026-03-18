import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * game-progress
 *
 * Returns a student's full progress for a world, including
 * chapter statuses, attempt counts, and submission history.
 *
 * GET ?student_id=uuid&world_slug=prison-escape
 */
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const url = new URL(req.url);
    const student_id = url.searchParams.get("student_id");
    const world_slug = url.searchParams.get("world_slug");

    if (!student_id || !world_slug) {
      return new Response(
        JSON.stringify({ error: "Missing student_id or world_slug" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Look up world
    const { data: world } = await supabase
      .from("game_worlds")
      .select("id, title, chapter_count")
      .eq("slug", world_slug)
      .single();

    if (!world) {
      return new Response(
        JSON.stringify({ error: "World not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get all chapters for this world
    const { data: chapters } = await supabase
      .from("game_chapters")
      .select("id, chapter_number, title, description, concepts, code_template, hint_text")
      .eq("world_id", world.id)
      .order("chapter_number");

    // Get student's progress for each chapter
    const { data: progress } = await supabase
      .from("game_progress")
      .select("chapter_id, status, attempts, first_attempt_at, completed_at")
      .eq("student_id", student_id)
      .eq("world_id", world.id);

    // Get student's leaderboard entry
    const { data: leaderboard } = await supabase
      .from("game_leaderboard")
      .select("score, chapters_completed, total_attempts, total_time_seconds, started_at, finished_at")
      .eq("student_id", student_id)
      .eq("world_id", world.id)
      .single();

    // Merge chapter info with progress
    const progressMap = new Map(
      (progress || []).map((p) => [p.chapter_id, p])
    );

    const chapterProgress = (chapters || []).map((ch) => {
      const p = progressMap.get(ch.id);
      return {
        chapter_number: ch.chapter_number,
        title: ch.title,
        description: ch.description,
        concepts: ch.concepts,
        code_template: ch.code_template,
        // Show hint after 3+ attempts or if completed
        hint: p && (p.attempts >= 3 || p.status === "completed") ? ch.hint_text : null,
        status: p?.status || (ch.chapter_number === 1 ? "available" : "locked"),
        attempts: p?.attempts || 0,
        first_attempt_at: p?.first_attempt_at || null,
        completed_at: p?.completed_at || null,
      };
    });

    return new Response(
      JSON.stringify({
        world: {
          slug: world_slug,
          title: world.title,
          chapter_count: world.chapter_count,
        },
        chapters: chapterProgress,
        leaderboard: leaderboard || null,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
