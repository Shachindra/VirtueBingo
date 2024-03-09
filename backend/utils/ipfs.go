package utils

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"html/template"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/chromedp/cdproto/page"
	"github.com/chromedp/chromedp"
	"github.com/disintegration/imaging"
	ipfs "github.com/ipfs/go-ipfs-api"
	draw2 "golang.org/x/image/draw"
)

type Metadata struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Image       string `json:"image"`
}

func CreateTicketImage(ticket [][]string, staticImageFile string) (string, error) {
	// Create a template for the HTML table
	tmpl, err := template.New("table").Parse(`
	<!DOCTYPE html>
	<html>
	<head>
		<style>
			table {
				border-collapse: collapse;
				width: 100%; /* Set table width to 100% */
				margin: 10px;
			}
			table, th, td {
				border: 1px solid black;
				/* Increase padding for more space */
				padding: 10px; /* Adjust padding as needed */
				text-align: center;
			}
			/* Slightly larger serif font */
			#tbl td {
				width: 50px; /* Adjust the width as needed */
				height: 50px; /* Adjust the height as needed */
				font-family: Arial, sans-serif; /* Specify a serif font */
				font-size: 22px; /* Increase font size slightly */
			}
		</style>
	</head>
	<body>
		<table id="tbl">
			{{range .}}
			<tr>
				{{range .}}
				<td>{{.}}</td>
				{{end}}
			</tr>
			{{end}}
		</table>
	</body>
	</html>	
	`)
	if err != nil {
		return "", err
	}
	// Execute the template with the data
	var buf strings.Builder
	if err := tmpl.Execute(&buf, ticket); err != nil {
		return "", err
	}

	html := buf.String()
	// Launch headless Chrome
	ctx, cancel := chromedp.NewContext(context.Background())
	defer cancel()

	// Capture screenshot of the HTML table
	var screenshotBuf []byte

	if err := chromedp.Run(ctx,
		chromedp.Navigate("about:blank"),
		chromedp.ActionFunc(func(ctx context.Context) error {
			frameTree, err := page.GetFrameTree().Do(ctx)
			if err != nil {
				return err
			}
			err = page.SetDocumentContent(frameTree.Frame.ID, html).Do(ctx)
			if err != nil {
				return err
			}
			return nil
		}),
		chromedp.Screenshot("#tbl", &screenshotBuf, chromedp.NodeVisible, chromedp.ByID),
	); err != nil {
		return "", err
	}

	// Save the screenshot to a file
	if err := os.WriteFile("screenshot.png", screenshotBuf, 0644); err != nil {
		return "", err
	}

	// Load the ticket image
	ticketImg, err := imaging.Open("screenshot.png")
	if err != nil {
		return "", err
	}

	// Load the static image
	staticImg, err := imaging.Open(staticImageFile)
	if err != nil {
		return "", err
	}

	bounds1 := staticImg.Bounds()
	bounds2 := ticketImg.Bounds()

	newWidth := bounds2.Dx() / 7
	newHeight := bounds1.Dy() * newWidth / bounds1.Dx()

	resizedFirstImg := image.NewRGBA(image.Rect(0, 0, newWidth, newHeight))
	draw2.ApproxBiLinear.Scale(resizedFirstImg, resizedFirstImg.Bounds(), staticImg, bounds1, draw.Src, nil)

	width := max(resizedFirstImg.Bounds().Dx(), bounds2.Dx())
	height := resizedFirstImg.Bounds().Dy() + bounds2.Dy()

	centerX := (bounds2.Dx() - newWidth) / 2

	newRect := image.Rect(0, 0, width, height)
	img := image.NewRGBA(newRect)
	bgColor := color.White
	draw.Draw(img, img.Bounds(), &image.Uniform{bgColor}, image.ZP, draw.Src)
	draw.Draw(img, image.Rect(centerX, 0, centerX+newWidth, ticketImg.Bounds().Dy()), resizedFirstImg, image.Point{}, draw.Src)
	draw.Draw(img, bounds2.Add(image.Pt(0, resizedFirstImg.Bounds().Dy())), ticketImg, bounds2.Min, draw.Over)

	// Save the final image to a file
	outFile, err := os.Create("final_image.png")
	if err != nil {
		return "", err
	}
	defer outFile.Close()

	// Encode the final image to PNG format
	if err := png.Encode(outFile, img); err != nil {
		return "", err
	}

	// Read the PNG image file
	imageData, err := os.ReadFile("final_image.png")
	if err != nil {
		return "", err
	}

	// Convert the image data to base64 string
	base64Str := base64.StdEncoding.EncodeToString(imageData)

	return "data:image/png;base64," + base64Str, nil
}

func CreateTicketBytes(ticket [][]string, staticImageFile string) ([]byte, error) {
	// Create a template for the HTML table
	tmpl, err := template.New("table").Parse(`
	<!DOCTYPE html>
	<html>
	<head>
		<style>
			table {
				border-collapse: collapse;
				width: 100%; /* Set table width to 100% */
				margin: 10px;
			}
			table, th, td {
				border: 1px solid black;
				/* Increase padding for more space */
				padding: 10px; /* Adjust padding as needed */
				text-align: center;
			}
			/* Slightly larger serif font */
			#tbl td {
				width: 50px; /* Adjust the width as needed */
				height: 50px; /* Adjust the height as needed */
				font-family: Arial, sans-serif; /* Specify a serif font */
				font-size: 22px; /* Increase font size slightly */
			}
		</style>
	</head>
	<body>
		<table id="tbl">
			{{range .}}
			<tr>
				{{range .}}
				<td>{{.}}</td>
				{{end}}
			</tr>
			{{end}}
		</table>
	</body>
	</html>	
	`)
	if err != nil {
		return nil, err
	}
	// Execute the template with the data
	var buf strings.Builder
	if err := tmpl.Execute(&buf, ticket); err != nil {
		return nil, err
	}

	html := buf.String()
	// Launch headless Chrome
	ctx, cancel := chromedp.NewContext(context.Background())
	defer cancel()

	// Capture screenshot of the HTML table
	var screenshotBuf []byte

	if err := chromedp.Run(ctx,
		chromedp.Navigate("about:blank"),
		chromedp.ActionFunc(func(ctx context.Context) error {
			frameTree, err := page.GetFrameTree().Do(ctx)
			if err != nil {
				return err
			}
			err = page.SetDocumentContent(frameTree.Frame.ID, html).Do(ctx)
			if err != nil {
				return err
			}
			return nil
		}),
		chromedp.Screenshot("#tbl", &screenshotBuf, chromedp.NodeVisible, chromedp.ByID),
	); err != nil {
		return nil, err
	}

	// Save the screenshot to a file
	if err := os.WriteFile("screenshot.png", screenshotBuf, 0644); err != nil {
		return nil, err
	}

	// Load the ticket image
	ticketImg, err := imaging.Open("screenshot.png")
	if err != nil {
		return nil, err
	}

	// Load the static image
	staticImg, err := imaging.Open(staticImageFile)
	if err != nil {
		return nil, err
	}

	bounds1 := staticImg.Bounds()
	bounds2 := ticketImg.Bounds()

	newWidth := bounds2.Dx() / 7
	newHeight := bounds1.Dy() * newWidth / bounds1.Dx()

	resizedFirstImg := image.NewRGBA(image.Rect(0, 0, newWidth, newHeight))
	draw2.ApproxBiLinear.Scale(resizedFirstImg, resizedFirstImg.Bounds(), staticImg, bounds1, draw.Src, nil)

	width := max(resizedFirstImg.Bounds().Dx(), bounds2.Dx())
	height := resizedFirstImg.Bounds().Dy() + bounds2.Dy()

	centerX := (bounds2.Dx() - newWidth) / 2

	newRect := image.Rect(0, 0, width, height)
	img := image.NewRGBA(newRect)
	bgColor := color.White
	draw.Draw(img, img.Bounds(), &image.Uniform{bgColor}, image.ZP, draw.Src)
	draw.Draw(img, image.Rect(centerX, 0, centerX+newWidth, ticketImg.Bounds().Dy()), resizedFirstImg, image.Point{}, draw.Src)
	draw.Draw(img, bounds2.Add(image.Pt(0, resizedFirstImg.Bounds().Dy())), ticketImg, bounds2.Min, draw.Over)

	// Save the final image to a file
	outFile, err := os.Create("final_image.png")
	if err != nil {
		return nil, err
	}
	defer outFile.Close()
	// Encode the final image to PNG format
	if err := png.Encode(outFile, img); err != nil {
		return nil, err
	}

	// Read the PNG image file
	imageData, err := os.ReadFile("final_image.png")
	if err != nil {
		return nil, err
	}

	return imageData, nil
}

func CreateMetadata(ticket [][]string, gameID string, imageData string) (*Metadata, error) {
	// Flatten the ticket and calculate the hash
	flattenedTicket := FlattenTicket(OptimizeTicket(ticket))
	flattenedTicketString := strings.Join(flattenedTicket, " ")
	h := sha256.New()
	h.Write([]byte(flattenedTicketString))
	ticketHash := h.Sum(nil)

	// Create the metadata struct
	metadata := &Metadata{
		Name:        string(ticketHash),
		Description: "Game # " + gameID,
		Image:       imageData,
	}

	return metadata, nil
}

func ipfsOperations(gameID, ticketID string, metadata *Metadata) (string, string, error) {
	// Connect to the IPFS daemon
	sh := ipfs.NewShell("localhost:5001")

	// Create directories for game and ticket
	baseDir := "tickets"
	if err := os.MkdirAll(filepath.Join(baseDir, gameID), 0755); err != nil {
		return "", "", err
	}

	// Save metadata to a JSON file
	ticketFile := filepath.Join(baseDir, gameID, ticketID+".json")
	metadataBytes, err := json.Marshal(metadata)
	if err != nil {
		return "", "", err
	}
	if err := os.WriteFile(ticketFile, metadataBytes, 0644); err != nil {
		return "", "", err
	}

	// Add the ticket directory to IPFS
	ipfsHash, err := sh.AddDir(baseDir)
	if err != nil {
		return "", "", err
	}

	// Publish the IPNS name
	ipnsName, err := sh.PublishWithDetails(ipfsHash, "testkey", time.Hour*100, time.Hour*100, false)
	if err != nil {
		return "", "", err
	}

	return ipfsHash, ipnsName.Name, nil
}
