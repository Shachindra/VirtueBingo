package snl

type CreateGameRequest struct {
	Name                 string `json:"name"`
	Symbol               string `json:"symbol"`
	Picture              string `json:"picture"`
	CoverImage           string `json:"coverImage"`
	Description          string `json:"description"`
	CreatorWalletAddress string `json:"creatorWalletAddress"`
	Type                 string `json:"type"`
}

type GetGameReqest struct {
	GameId int `json:"gameId"`
}
