package api

import (
	"VirtueGaming/api/game"
	"VirtueGaming/api/memory"
	"VirtueGaming/api/snl"
	"VirtueGaming/api/ticket"

	"github.com/gin-gonic/gin"
)

func ApplyRoutes(r *gin.Engine) {
	g := r.Group("/api/v1.0")
	{
		ticket.ApplyRoutes(g)
		game.ApplyRoutes(g)
		memory.ApplyRoutes(g)
		snl.ApplyRoutes(g)
	}
}
