package models

type Metadata struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Ticket      string `json:"ticket"`
	Image       string `json:"image"`
}

type TicketRequest struct {
}
