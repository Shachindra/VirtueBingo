package ticket

type PostTickerRequest struct {
	GameId      int    `json:"gameId"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Type        string `json:"type"`
}

type Ticket struct {
	GameId      int    `json:"gameId"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Type        string `json:"type"`
	Image       string `json:"image"`
}
