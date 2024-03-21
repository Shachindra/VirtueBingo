package game

import (
	"VirtueGaming/config/dbconfig"
	"VirtueGaming/models"
	"VirtueGaming/utils/smartcontract"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

func ApplyRoutes(r *gin.RouterGroup) {
	g := r.Group("/game")
	{
		g.POST("", CreateGame)
		g.GET("/all", GetAllGames)
		g.GET("", GetGameById)
		g.GET("/drawNumber", DrawNumber)
	}
}

// status: notStarted, , Stated, Finished
func GetAllGames(c *gin.Context) {
	// var req GetGameReqest
	// if err := c.BindJSON(&req); err != nil {
	// 	logrus.Error("failed to bind request: ", err)
	// 	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	// }
	var games []models.Game
	db := dbconfig.GetDb()
	if err := db.Model(&models.Game{}).Find(&games).Error; err != nil {
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
	var game models.Game
	if err := db.Model(&models.Game{}).Where("game_id = ?", gameId).First(&game).Error; err != nil {
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
	tx, err := smartcontract.CallCreateGame(smartcontract.CreateGameParams{GameName: req.Name, StartTimestamp: req.StartTimestamp})
	if err != nil {
		logrus.Error("err: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	txHash := tx.Result.TransactionHash

	query := `
	query MyQuery {
	  events(
	    where: {
	      data: { _contains: { game_name: "%s" } },
	      type: { _eq: "%s" }
	    }
	  ) {
		data
	  }
	}
`
	requestBody, err := json.Marshal(map[string]string{
		"query": fmt.Sprintf(query, req.Name, os.Getenv("APTOS_FUNCTION_ID")+"::bingov1::CreateGameEvent"),
	})
	if err != nil {
		fmt.Println("Error marshalling request body:", err)
		return
	}

	contractReq, err := http.NewRequest(http.MethodPost, "https://indexer.random.aptoslabs.com/v1/graphql", bytes.NewReader(requestBody))
	if err != nil {
		logrus.Error("failed to send request: %s", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	client := &http.Client{}
	resp, err := client.Do(contractReq)
	if err != nil {
		logrus.Error("failed to send request: %s", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if resp.StatusCode != 200 {
		logrus.Error("Error in response: %s", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	var result Response
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		fmt.Println("Error decoding response body:", err)
		return
	}
	gameId := result.Data.Events[0].Data.GameID
	gameIdInt, _ := strconv.Atoi(gameId)
	game := models.Game{
		Name:                 req.Name,
		StartTimestamp:       req.StartTimestamp,
		Symbol:               req.Symbol,
		Picture:              req.Picture,
		CoverImage:           req.CoverImage,
		Description:          req.Description,
		CreatorWalletAddress: req.CreatorWalletAddress,
		Type:                 req.Type,
		TransactionHash:      txHash,
		GameId:               gameIdInt,
	}
	db := dbconfig.GetDb()
	if err = db.Model(&models.Game{}).Create(&game).Error; err != nil {
		logrus.Error("db err: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": txHash, "gameId": gameId})
}

func DrawNumber(c *gin.Context) {
	gameId := c.Query("gameId")
	gameIdInt, _ := strconv.Atoi(gameId)
	// var req CreateGameRequest
	// err := c.BindJSON(&req)
	// if err != nil {
	// 	logrus.Error("failed to bind request: ", err)
	// 	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})

	// }
	tx, err := smartcontract.CallDrawNumber(smartcontract.DrawNumberParams{GameID: gameIdInt})
	if err != nil {
		logrus.Error("err: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	txHash := tx.Result.TransactionHash

	query := `
	query MyQuery {
		events(
			where: {type: {_eq: "%s"}}
			order_by: {sequence_number: desc}
			limit: 1
		) {
			data
		}
	}
`
	requestBody, err := json.Marshal(map[string]string{
		"query": fmt.Sprintf(query, os.Getenv("APTOS_FUNCTION_ID")+"::bingov1::DrawNumberEvent"),
	})
	if err != nil {
		fmt.Println("Error marshalling request body:", err)
		return
	}

	contractReq, err := http.NewRequest(http.MethodPost, "https://indexer.random.aptoslabs.com/v1/graphql", bytes.NewReader(requestBody))
	if err != nil {
		logrus.Error("failed to send request: %s", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	client := &http.Client{}
	resp, err := client.Do(contractReq)
	if err != nil {
		logrus.Error("failed to send request: %s", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if resp.StatusCode != 200 {
		logrus.Error("Error in response: %s", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	var result DrawNumberResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		fmt.Println("Error decoding response body:", err)
		return
	}
	number := result.Data.Events[0].Data.Number

	c.JSON(http.StatusOK, gin.H{"number": number, "data": txHash})
}
