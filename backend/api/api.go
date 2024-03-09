package api

import (
	"InnerVirtueBingo/models"
	"InnerVirtueBingo/utils"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

func ApplyRoutes(r *gin.Engine) {
	g := r.Group("/ticket")
	{
		g.GET("", generateTicket)
	}
}

func generateTicket(c *gin.Context) {
	// gameID := c.Query("game_id")
	// ticketID := c.Query("ticket_id")

	ticket := utils.GenerateTambolaTicket(1)
	//optimizedTicket := utils.OptimizeTicket(ticket)
	flatTicket := utils.FlattenTicket(ticket)
	//encodedTicket := utils.EncodeHexTicket(flatTicket)

	// str, err := utils.CreateTicketImage(ticket, "image.png")
	// if err != nil {
	// 	fmt.Println("err: ", err)
	// 	return
	// }

	imgbytes, err := utils.CreateTicketBytes(ticket, "image.png")
	if err != nil {
		fmt.Println("err: ", err)
		return
	}
	imageIPFSHash, err := utils.UploadImageToNFTStorage(os.Getenv("NFT_STORAGE_KEY"), imgbytes)
	if err != nil {
		fmt.Println("err: ", err)
		return
	}
	metadata := models.Metadata{
		Name:        "ticket",
		Description: "bingo ticket",
		Ticket:      strings.Join(flatTicket, ","),
		Image:       "ipfs://" + imageIPFSHash + "/image.jpeg",
	}
	metadataBytes, err := json.Marshal(metadata)
	if err != nil {
		fmt.Println("err: ", err)
		return
	}

	metadataHash, err := utils.UploadMetadataToNFTStorage(os.Getenv("NFT_STORAGE_KEY"), metadataBytes)
	if err != nil {
		fmt.Println("err: ", err)
		return
	}

	response := map[string]string{
		"ticket":   strings.Join(flatTicket, ","),
		"metadata": "ipfs://" + metadataHash,
	}

	c.JSON(http.StatusOK, gin.H{
		"data": response,
	})
}
