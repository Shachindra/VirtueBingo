package models

type Metadata struct {
	GameId      int    `json:"gameId"`
	Type        string `json:"type"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Ticket      string `json:"ticket"`
	Image       string `json:"image"`
}

type TicketRequest struct {
}
