// fake-hub: minimal Hub API stub for local Blip game server development
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
)

// ServerRecord tracks the state of a registered game server
type ServerRecord struct {
	ID         string
	Players    int
	MaxPlayers int
}

var (
	mu            sync.RWMutex
	serverRecords = map[string]*ServerRecord{}

	// Path to the world Lua script (mounted into container)
	worldLuaPath = envOrDefault("WORLD_LUA_PATH", "/worlds/prison_escape/world.lua")
	// Address clients use to reach the game server (host:port)
	gameServerAddr = envOrDefault("GAME_SERVER_ADDRESS", "localhost:8080")
	// World ID the game server registers under
	worldID = envOrDefault("WORLD_ID", "prison-escape-local")
	// Max players
	maxPlayersDefault = 8
)

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", router)
	port := ":10083"
	log.Printf("[fake-hub] listening on %s", port)
	log.Printf("[fake-hub] world lua   : %s", worldLuaPath)
	log.Printf("[fake-hub] game server : %s", gameServerAddr)
	log.Fatal(http.ListenAndServe(port, mux))
}

func router(w http.ResponseWriter, r *http.Request) {
	log.Printf("[fake-hub] %s %s", r.Method, r.URL.Path)
	p := r.URL.Path

	switch {
	// Game server: fetch world script
	case r.Method == "GET" && strings.HasPrefix(p, "/private/worlds/"):
		handleGetWorld(w, r)

	// Game server: heartbeat info
	case r.Method == "POST" && strings.Contains(p, "/private/server/") && strings.HasSuffix(p, "/info"):
		handleServerInfo(w, r)

	// Game server: graceful exit
	case r.Method == "POST" && strings.Contains(p, "/private/server/") && strings.HasSuffix(p, "/exit"):
		handleServerExit(w, r)

	// Game server: chat relay (optional, just ACK)
	case r.Method == "POST" && p == "/private/chat/message":
		w.WriteHeader(http.StatusOK)

	// Client: get running server address for a world
	case r.Method == "GET" && strings.HasPrefix(p, "/worlds/") && strings.Contains(p, "/server/"):
		handleGetServer(w, r)

	// Client: login (returns fake token so client can authenticate)
	case r.Method == "POST" && p == "/login":
		handleLogin(w, r)

	default:
		log.Printf("[fake-hub] 404 %s %s", r.Method, p)
		http.NotFound(w, r)
	}
}

// GET /private/worlds/{worldID}?f=script&f=maxPlayers
func handleGetWorld(w http.ResponseWriter, r *http.Request) {
	script, err := os.ReadFile(worldLuaPath)
	if err != nil {
		log.Printf("[fake-hub] failed to read world script: %v", err)
		http.Error(w, "world script not found", http.StatusNotFound)
		return
	}

	resp := map[string]interface{}{
		"world": map[string]interface{}{
			"script":     string(script),
			"maxPlayers": maxPlayersDefault,
		},
	}
	writeJSON(w, resp)
}

// POST /private/server/{serverID}/info  body: {"id":"...","players":N}
func handleServerInfo(w http.ResponseWriter, r *http.Request) {
	var body struct {
		ID      string `json:"id"`
		Players int    `json:"players"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err == nil && body.ID != "" {
		mu.Lock()
		if rec, ok := serverRecords[body.ID]; ok {
			rec.Players = body.Players
		} else {
			serverRecords[body.ID] = &ServerRecord{
				ID:         body.ID,
				Players:    body.Players,
				MaxPlayers: maxPlayersDefault,
			}
		}
		mu.Unlock()
		log.Printf("[fake-hub] server %s heartbeat: %d players", body.ID, body.Players)
	}
	w.WriteHeader(http.StatusOK)
}

// POST /private/server/{serverID}/exit
func handleServerExit(w http.ResponseWriter, r *http.Request) {
	// Extract server ID from path: /private/server/{id}/exit
	parts := strings.Split(r.URL.Path, "/")
	if len(parts) >= 4 {
		sid := parts[3]
		mu.Lock()
		delete(serverRecords, sid)
		mu.Unlock()
		log.Printf("[fake-hub] server %s exited", sid)
	}
	w.WriteHeader(http.StatusOK)
}

// GET /worlds/{worldID}/server/{tag}
// Client calls this to find the game server address
func handleGetServer(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	players := 0
	for _, rec := range serverRecords {
		players = rec.Players
		break
	}
	mu.RUnlock()

	resp := map[string]interface{}{
		"server": map[string]interface{}{
			"id":         "local-server-1",
			"address":    gameServerAddr,
			"players":    players,
			"maxPlayers": maxPlayersDefault,
		},
	}
	writeJSON(w, resp)
}

// POST /login
func handleLogin(w http.ResponseWriter, r *http.Request) {
	resp := map[string]interface{}{
		"token":    "fake-local-token",
		"userID":   "local-user-1",
		"username": "LocalPlayer",
	}
	writeJSON(w, resp)
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("[fake-hub] json encode error: %v", err)
	}
}
