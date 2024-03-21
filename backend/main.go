package main

import (
	"VirtueGaming/api"
	"VirtueGaming/config/dbconfig"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	godotenv.Load()
	dbconfig.DbInit()
	ginApp := gin.Default()
	// cors middleware
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowHeaders = []string{"Authorization", "Content-Type"}
	ginApp.Use(cors.New(config))

	ginApp.NoRoute(func(c *gin.Context) {
		c.JSON(404, gin.H{"status": 404, "message": "Invalid Endpoint Request"})
	})
	api.ApplyRoutes(ginApp)
	// ginApp.Run(":" + os.Getenv("HTTP_PORT"))
	ginApp.Run(":" + "8070")

}
