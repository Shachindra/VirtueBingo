package memory

type CreateGameRequest struct {
	Name                 string   `json:"name"`
	StartTimestamp       string   `json:"startTimestamp"`
	Symbol               string   `json:"symbol"`
	Picture              string   `json:"picture"`
	CoverImage           string   `json:"coverImage"`
	Description          string   `json:"description"`
	CreatorWalletAddress string   `json:"creatorWalletAddress"`
	Type                 string   `json:"type"`
	ImageList            []string `json:"imageList"`
	BoxSize              int      `json:"boxSize"`
}

type GetGameReqest struct {
	GameId int `json:"gameId"`
}
