package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"time"
)

func UploadImageToNFTStorage(apiKey string, fileData []byte) (string, error) {
	buf := new(bytes.Buffer)
	writer := multipart.NewWriter(buf)
	part, err := writer.CreateFormFile("file", filepath.Base("image.jpeg")) // Use a generic filename
	if err != nil {
		return "", err
	}
	part.Write(fileData)
	writer.Close()

	// Send a POST request to NFT.Storage API
	req, err := http.NewRequest("POST", "https://api.nft.storage/upload", buf)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// Handle the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	type resBody struct {
		Ok    bool `json:"ok"`
		Value struct {
			Cid     string    `json:"cid"`
			Size    int       `json:"size"`
			Created time.Time `json:"created"`
			Type    string    `json:"type"`
			Scope   string    `json:"scope"`
			Pin     struct {
				Cid  string `json:"cid"`
				Name string `json:"name"`
				Meta struct {
				} `json:"meta"`
				Status  string    `json:"status"`
				Created time.Time `json:"created"`
				Size    int       `json:"size"`
			} `json:"pin"`
			Files []struct {
				Name string `json:"name"`
				Type string `json:"type"`
			} `json:"files"`
			Deals []struct {
				BatchRootCid   string    `json:"batchRootCid"`
				LastChange     time.Time `json:"lastChange"`
				Miner          string    `json:"miner"`
				Network        string    `json:"network"`
				PieceCid       string    `json:"pieceCid"`
				Status         string    `json:"status"`
				StatusText     string    `json:"statusText"`
				ChainDealID    int       `json:"chainDealID"`
				DealActivation time.Time `json:"dealActivation"`
				DealExpiration time.Time `json:"dealExpiration"`
			} `json:"deals"`
		} `json:"value"`
	}

	var response resBody
	err = json.Unmarshal(body, &response)
	if err != nil {
		return "", err
	}
	return response.Value.Cid, nil
}

func UploadMetadataToNFTStorage(apiKey string, jsonData []byte) (string, error) {
	// Send a POST request to NFT.Storage API
	req, err := http.NewRequest("POST", "https://api.nft.storage/upload", bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// Handle the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	type resBody struct {
		Ok    bool `json:"ok"`
		Value struct {
			Cid     string    `json:"cid"`
			Size    int       `json:"size"`
			Created time.Time `json:"created"`
			Type    string    `json:"type"`
			Scope   string    `json:"scope"`
			Pin     struct {
				Cid  string `json:"cid"`
				Name string `json:"name"`
				Meta struct {
				} `json:"meta"`
				Status  string    `json:"status"`
				Created time.Time `json:"created"`
				Size    int       `json:"size"`
			} `json:"pin"`
			Files []struct {
				Name string `json:"name"`
				Type string `json:"type"`
			} `json:"files"`
			Deals []struct {
				BatchRootCid   string    `json:"batchRootCid"`
				LastChange     time.Time `json:"lastChange"`
				Miner          string    `json:"miner"`
				Network        string    `json:"network"`
				PieceCid       string    `json:"pieceCid"`
				Status         string    `json:"status"`
				StatusText     string    `json:"statusText"`
				ChainDealID    int       `json:"chainDealID"`
				DealActivation time.Time `json:"dealActivation"`
				DealExpiration time.Time `json:"dealExpiration"`
			} `json:"deals"`
		} `json:"value"`
	}

	var response resBody
	err = json.Unmarshal(body, &response)
	if err != nil {
		return "", err
	}
	return response.Value.Cid, nil
}
