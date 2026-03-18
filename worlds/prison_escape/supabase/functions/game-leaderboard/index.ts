import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * game-leaderboard
 *
 * Returns the leaderboard for a game world.
 * Optionally filtered by franchise location.
 *
 * GET ?world_slug=prison-escape&location_id=uuid&limit=20
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
    const world_slug = url.searchParams.get("world_slug");
    const location_id = url.searchParams.get("location_id");
    const limit = parseInt(url.searchParams.get("limit") || "20", 10);

    if (!world_slug) {
      return new Response(
        JSON.stringify({ error: "Missing world_slug parameter" }),
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

    // Build leaderboard query
    let query = supabase
      .from("game_leaderboard")
      .select(`
        score,
        chapters_completed,
        total_attempts,
        total_time_seconds,
        started_at,
        finished_at,
        student_id,
        students!inner (
          first_name,
          last_name,
          franchise_locations (
            name
          )
        )
      `)
      .eq("world_id", world.id)
      .order("score", { ascending: false })
      .limit(limit);

    // Filter by location if provided
    if (location_id) {
      query = query.eq("location_id", location_id);
    }

    const { data: entries, error } = await query;

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Format the leaderboard with rank
    const leaderboard = (entries || []).map((entry, index) => ({
      rank: index + 1,
      student_name: `${(entry.students as any)?.first_name || ""} ${((entry.students as any)?.last_name || "").charAt(0)}.`,
      location: (entry.students as any)?.franchise_locations?.name || null,
      score: entry.score,
      chapters_completed: entry.chapters_completed,
      total_chapters: world.chapter_count,
      total_attempts: entry.total_attempts,
      total_time_seconds: entry.total_time_seconds,
      finished: entry.finished_at !== null,
    }));

    return new Response(
      JSON.stringify({
        world: {
          slug: world_slug,
          title: world.title,
        },
        leaderboard,
        total_entries: leaderboard.length,
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
