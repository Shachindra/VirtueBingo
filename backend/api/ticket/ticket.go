package ticket

import (
	"VirtueGaming/models"
	"VirtueGaming/utils"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

func ApplyRoutes(r *gin.RouterGroup) {
	g := r.Group("/ticket")
	{
		g.POST("", generateTicket)
	}
}

func generateTicket(c *gin.Context) {
	var req PostTickerRequest
	if err := c.BindJSON(&req); err != nil {
		logrus.Error("failed to bind request: ", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	ticket := utils.Generate()
	ticketString := utils.IntArrayToStringArray(ticket)
	flatTicket := utils.FlattenTicket(ticketString)

	ticketStringNonZero := utils.ReplaceZeroWithEmpty(ticketString)

	imgbytes, err := utils.CreateTicketBytes(ticketStringNonZero, "image.png")
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
		GameId:      req.GameId,
		Type:        req.Type,
		Name:        req.Name,
		Description: req.Description,
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
