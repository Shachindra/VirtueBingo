package models

import "github.com/lib/pq"

type Game struct {
	Name                 string `json:"name"`
	StartTimestamp       string `json:"startTimestamp"`
	Symbol               string `json:"symbol"`
	Picture              string `json:"picture"`
	CoverImage           string `json:"coverImage"`
	Description          string `json:"description"`
	CreatorWalletAddress string `json:"creatorWalletAddress"`
	Type                 string `json:"type"`
	TransactionHash      string `json:"transactionHash"`
	GameId               int    `json:"gameId"`
}
type MemoryGame struct {
	Name                 string         `json:"name"`
	StartTimestamp       string         `json:"startTimestamp"`
	Symbol               string         `json:"symbol"`
	Picture              string         `json:"picture"`
	CoverImage           string         `json:"coverImage"`
	Description          string         `json:"description"`
	CreatorWalletAddress string         `json:"creatorWalletAddress"`
	Type                 string         `json:"type"`
	TransactionHash      string         `json:"transactionHash"`
	GameId               int            `json:"gameId"`
	ImageList            pq.StringArray `json:"imageList" gorm:"type:text[]"`
	BoxSize              int            `json:"boxSize"`
}

type SnlGame struct {
	Name                 string `json:"name"`
	Symbol               string `json:"symbol"`
	Picture              string `json:"picture"`
	CoverImage           string `json:"coverImage"`
	Description          string `json:"description"`
	CreatorWalletAddress string `json:"creatorWalletAddress"`
	Type                 string `json:"type"`
	TransactionHash      string `json:"transactionHash"`
	GameId               int    `json:"gameId"`
}
