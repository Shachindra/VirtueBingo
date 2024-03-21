package game

type CreateGameRequest struct {
	Name                 string `json:"name"`
	StartTimestamp       string `json:"startTimestamp"`
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

type Data struct {
	GameID         string `json:"game_id"`
	GameName       string `json:"game_name"`
	Timestamp      string `json:"timestamp"`
	StartTimestamp string `json:"start_timestamp"`
}

type Event struct {
	Data Data `json:"data"`
}

type Response struct {
	Data struct {
		Events []Event `json:"events"`
	} `json:"data"`
}

type DrawNumberData struct {
	GameID    string `json:"game_id"`
	Number    string `json:"number"`
	Timestamp string `json:"timestamp"`
}

type DrawNumberEvent struct {
	Data DrawNumberData `json:"data"`
}

type DrawNumberResponse struct {
	Data struct {
		Events []DrawNumberEvent `json:"events"`
	} `json:"data"`
}
