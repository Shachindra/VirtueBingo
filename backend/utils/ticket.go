package utils

import (
	"encoding/hex"
	"fmt"
	"math/rand"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Number is an alias for int
type Number int

// Row is a list of Numbers
type Row []Number

// ColumnRange represents the start and end range for each column
type ColumnRange struct {
	start Number
	end   Number
}

// COLUMN_RANGES is a list of ColumnRange objects defining the valid ranges for each column
var COLUMN_RANGES = []ColumnRange{
	{1, 9},
	{10, 19},
	{20, 29},
	{30, 39},
	{40, 49},
	{50, 59},
	{60, 69},
	{70, 79},
	{80, 90},
}

// Ticket is a structure to store and display the ticket
type Ticket struct {
	rows     []Row
	numbers  []Number
	selected map[Number]bool
}

func insertBlanksAndExpandArray(original []Number) []string {
	// Seed the random number generator
	rand.Seed(time.Now().UnixNano())

	// New array of 9 elements
	newArray := make([]string, 9)

	// Calculate the total number of blanks to insert
	blanksToInsert := len(newArray) - len(original)

	// Keep track of positions already filled
	filledPositions := make(map[int]bool)

	// First, randomly distribute blanks across the new array
	for blanksToInsert > 0 {
		pos := rand.Intn(len(newArray))
		if _, exists := filledPositions[pos]; !exists {
			newArray[pos] = "" // Use 0 as a placeholder for blanks
			filledPositions[pos] = true
			blanksToInsert--
		}
	}

	// Then, fill in the original numbers in order
	for _, num := range original {
		for i, val := range newArray {
			// Look for the first 'blank' position to insert the number
			if val == "" && !filledPositions[i] {
				newArray[i] = strconv.Itoa(int(num))
				filledPositions[i] = true
				break
			}
		}
	}
	return newArray
}

// getFormattedTicket returns a representation of the ticket in a 3x9 grid with blank squares represented by an empty string
func (t *Ticket) getFormattedTicket() [][]string {
	representation := make([][]string, 0)
	for i := range representation {
		representation[i] = make([]string, 9)
	}

	for _, row := range t.rows {
		arr := insertBlanksAndExpandArray(row)
		representation = append(representation, arr)
	}
	return representation
}

// generateTicket generates a housie ticket containing 15 randomly selected numbers based on the following rules:
// - A Housie ticket has 15 numbers.
// - These 15 numbers are placed in a 3 rows x 9 cols grid (27 possible spaces).
// - There has to be exactly 5 numbers in each row.
// - There has to be at least one number in each column.
// - The numbers in each column must belong to that column's allowed range.
func GenerateTicket() *Ticket {
	// Make a copy of COLUMN_RANGES as we mutate it during the selection process
	columnRanges := make([]ColumnRange, len(COLUMN_RANGES))
	copy(columnRanges, COLUMN_RANGES)

	// The numbers selected for the ticket
	ticketNumbers := make(map[Number]bool)

	// Saving the numbers column-wise to ensure we select at max 3 numbers for each column and also
	// to help in distributing them into the 3 rows later
	columnWiseNumbers := make(map[ColumnRange][]Number)

	// Select one number from each column range. This will give us 9 numbers
	for _, columnRange := range columnRanges {
		selectedNumber := selectUniqueNumberFromRange(columnRange, columnWiseNumbers[columnRange])
		ticketNumbers[selectedNumber] = true
		columnWiseNumbers[columnRange] = append(columnWiseNumbers[columnRange], selectedNumber)
	}

	// Select the remaining 6 numbers at random from the columns
	for len(ticketNumbers) < 15 {
		selectedRange := columnRanges[rand.Intn(len(columnRanges))]
		selectedNumber := selectUniqueNumberFromRange(selectedRange, columnWiseNumbers[selectedRange])

		ticketNumbers[selectedNumber] = true
		columnWiseNumbers[selectedRange] = append(columnWiseNumbers[selectedRange], selectedNumber)

		// If we have selected 3 numbers for a specific column, remove that column from the further selection process
		if len(columnWiseNumbers[selectedRange]) == 3 {
			for i, cr := range columnRanges {
				if cr == selectedRange {
					columnRanges = append(columnRanges[:i], columnRanges[i+1:]...)
					break
				}
			}
		}
	}

	// Assign the 15 selected numbers into the 3 rows
	rows := assignToRows(columnWiseNumbers)
	return &Ticket{rows: rows, numbers: collectNumbers(rows), selected: ticketNumbers}
}

// selectUniqueNumberFromRange selects and returns a number randomly from a ColumnRange.
// If the number has already been selected before, then it selects a new number until a unique number is found.
func selectUniqueNumberFromRange(columnRange ColumnRange, alreadySelected []Number) Number {
	var selectedNumber Number
	for {
		selectedNumber = Number(rand.Intn(int(columnRange.end-columnRange.start+1))) + columnRange.start
		found := false
		for _, n := range alreadySelected {
			if n == selectedNumber {
				found = true
				break
			}
		}
		if !found {
			break
		}
	}
	return selectedNumber
}

// assignToRows distributes the ticket numbers into the 3 rows such that each row has exactly 5 numbers.
// It starts with the columns that have 3 numbers, followed by the columns that have two numbers, and
// then columns that have 1 number.
// The numbers are assigned in a round-robin fashion.
func assignToRows(columnWiseNumbers map[ColumnRange][]Number) []Row {
	ticket := make([]Row, 3)
	rowNum := 0
	for colLen := 3; colLen > 0; colLen-- {
		for _, column := range columnWiseNumbers {
			if len(column) == colLen {
				rowNum = insertFromColumnsToRows(column, ticket, rowNum)
			}
		}
	}
	return ticket
}

// insertFromColumnsToRows inserts numbers from the columns into the rows in a round-robin fashion.
// It returns the row_num so it can be persisted between calls.
func insertFromColumnsToRows(column []Number, ticket []Row, rowNum int) int {
	sort.Slice(column, func(i, j int) bool {
		return column[i] < column[j]
	})

	// Assign in round-robin logic starting from the smallest row num possible
	rowNumsToAssignTo := make([]int, len(column))
	for i := range column {
		rowNumsToAssignTo[i] = rowNum
		rowNum = (rowNum + 1) % 3
	}

	// Sort the row numbers to assign the smaller numbers to higher rows
	sort.Ints(rowNumsToAssignTo)
	for i, num := range column {
		ticket[rowNumsToAssignTo[i]] = append(ticket[rowNumsToAssignTo[i]], num)
	}

	return rowNum
}

// collectNumbers collects all the numbers from the rows into a single slice
func collectNumbers(rows []Row) []Number {
	var numbers []Number
	for _, row := range rows {
		numbers = append(numbers, row...)
	}
	return numbers
}

// generateTambolaTicket generates the specified number of tickets and returns a slice of formatted ticket representations
func GenerateTambolaTicket(numberOfTickets int) [][]string {
	var tickets [][]string
	for i := 0; i < numberOfTickets; i++ {
		ticket := GenerateTicket()
		tickets = append(tickets, ticket.getFormattedTicket()...)
	}
	return tickets
}

// encodeHexTicket encodes the flattened ticket into a hexadecimal string
func EncodeHexTicket(ticket []string) string {
	var numbers []byte
	for _, num := range ticket {
		if num != "" {
			n := fmt.Sprintf("%02d", mustParseInt(num))
			numbers = append(numbers, n...)
		}
	}
	return hex.EncodeToString(numbers)
}

// mustParseInt is a helper function to parse a string into an int, panicking on error
func mustParseInt(s string) int {
	n, err := fmt.Sscanf(s, "%d", new(int))
	if err != nil || n != 1 {
		panic(fmt.Sprintf("failed to parse int from %q", s))
	}
	return *new(int)
}

// formatTicket formats a single ticket representation into a human-readable string
func formatTicket(ticket []string) string {
	rows := make([]string, 3)
	for i := 0; i < 9; i++ {
		rows[0] += ticket[i] + " "
		rows[1] += ticket[i+9] + " "
		rows[2] += ticket[i+18] + " "
	}
	return strings.Join(rows, "\n")
}

func OptimizeTicket(ticket [][]string) [][]string {
	var optimizedTicket [][]string

	for _, row := range ticket {
		var optimizedRow []string
		for _, num := range row {
			if num != "" {
				optimizedRow = append(optimizedRow, num)
			}
		}
		optimizedTicket = append(optimizedTicket, optimizedRow)
	}

	return optimizedTicket
}

// flattenTicket flattens the optimized ticket into a single slice
func FlattenTicket(optimizedTicket [][]string) []string {
	var flattenedTicket []string
	for _, row := range optimizedTicket {
		flattenedTicket = append(flattenedTicket, row...)
	}
	return flattenedTicket
}
