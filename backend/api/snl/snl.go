package snl

import (
	"VirtueGaming/config/dbconfig"
	"VirtueGaming/models"
	"math/rand"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

func ApplyRoutes(r *gin.RouterGroup) {
	g := r.Group("/snl")
	{
		g.POST("", CreateGame)
		g.GET("/all", GetAllGames)
		g.GET("", GetGameById)
	}
}

// status: notStarted, , Stated, Finished
func GetAllGames(c *gin.Context) {
	// var req GetGameReqest
	// if err := c.BindJSON(&req); err != nil {
	// 	logrus.Error("failed to bind request: ", err)
	// 	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	// }
	var games []models.SnlGame
	db := dbconfig.GetDb()
	if err := db.Model(&models.SnlGame{}).Find(&games).Error; err != nil {
		logrus.Error("failed to fetch game: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, games)
}
func GetGameById(c *gin.Context) {
	gameId := c.Query("gameId")

	// var req GetGameReqest
	// if err := c.BindJSON(&req); err != nil {
	// 	logrus.Error("failed to bind request: ", err)
	// 	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	// }
	db := dbconfig.GetDb()
	var game models.SnlGame
	if err := db.Model(&models.SnlGame{}).Where("game_id = ?", gameId).First(&game).Error; err != nil {
		logrus.Error("failed to fetch game: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, game)

}
func CreateGame(c *gin.Context) {
	//create game
	var req CreateGameRequest
	err := c.BindJSON(&req)
	if err != nil {
		logrus.Error("failed to bind request: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	// Generate a random 6-digit number
	gameIdInt := rand.Intn(900000) + 100000
	game := models.SnlGame{
		Name:                 req.Name,
		Symbol:               req.Symbol,
		Picture:              req.Picture,
		CoverImage:           req.CoverImage,
		Description:          req.Description,
		CreatorWalletAddress: req.CreatorWalletAddress,
		Type:                 req.Type,
		//TransactionHash:      txHash,
		GameId: gameIdInt,
	}
	db := dbconfig.GetDb()
	tx := db.Model(&models.SnlGame{}).Create(&game)
	if tx.Error != nil {
		logrus.Error("db err: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": tx.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"gameId": strconv.Itoa(gameIdInt)})
}
