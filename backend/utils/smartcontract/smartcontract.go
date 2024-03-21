package smartcontract

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

func argS(s string) string {
	return "string:" + s
}

func argA(s string) string {
	return "address:" + s
}
func argI(i int) string {
	s := strconv.Itoa(i)
	return "u64:" + s
}

type DelegateReviewParams struct {
	Voter         string
	MetaDataUri   string
	Category      string
	DomainAddress string
	SiteUrl       string
	SiteType      string
	SiteTag       string
	SiteSafety    string
}

type CreateGameParams struct {
	GameName       string
	StartTimestamp string
}

type ClaimPrizeParams struct {
	GameID  int
	Prize   string
	Address string
}
type DrawNumberParams struct {
	GameID int
}

type JoinGameParams struct {
	GameID int
	Uri    string
	Ticket [][]int
}

var ErrMetadataDuplicated = errors.New("metadata already exist")

func CallCreateGame(p CreateGameParams) (*TxResult, error) {
	gas_unit, _ := strconv.Atoi(os.Getenv("GAS_UNITS"))
	gas_price, _ := strconv.Atoi(os.Getenv("GAS_PRICE"))
	fmt.Println(gas_unit)
	fmt.Println(gas_price)

	command := fmt.Sprintf("move run --function-id %s::bingov1::create_game --max-gas %d --gas-unit-price %d --args", os.Getenv("APTOS_FUNCTION_ID"), gas_unit, gas_price)
	args := append(strings.Split(command, " "),
		argS(p.GameName), "u64:"+p.StartTimestamp, "u64:100000000", "u64:1", "string:Collection_name", "string:desc", "string:uri", "u64:1")
	cmd := exec.Command("aptos", args...)
	fmt.Println(strings.Join(args, " "))

	o, err := cmd.Output()
	if err != nil {
		if err, ok := err.(*exec.ExitError); ok {
			if strings.Contains(string(o), "ERROR_METADATA_DUPLICATED(0x3)") {
				return nil, fmt.Errorf("%w: %w", ErrMetadataDuplicated, err)
			}
			return nil, fmt.Errorf("stderr: %s out: %s err: %w", err.Stderr, o, err)
		}
		return nil, fmt.Errorf("out: %s err: %w", o, err)
	}

	txResult, err := UnmarshalTxResult(o)
	return &txResult, err
}

func CallClaimPrize(p ClaimPrizeParams) (*TxResult, error) {
	gas_unit, _ := strconv.Atoi(os.Getenv("GAS_UNITS"))
	gas_price, _ := strconv.Atoi(os.Getenv("GAS_PRICE"))
	command := fmt.Sprintf("move run --function-id %s::bingov1::claim_prize --max-gas %d --gas-unit-price %d --args", os.Getenv("APTOS_FUNCTION_ID"), gas_unit, gas_price)
	args := append(strings.Split(command, " "),
		argI(p.GameID), argS(p.Prize), argA(p.Address))
	cmd := exec.Command("aptos", args...)
	fmt.Println(strings.Join(args, " "))

	o, err := cmd.Output()
	if err != nil {
		if err, ok := err.(*exec.ExitError); ok {
			if strings.Contains(string(o), "ERROR_METADATA_DUPLICATED(0x3)") {
				return nil, fmt.Errorf("%w: %w", ErrMetadataDuplicated, err)
			}
			return nil, fmt.Errorf("stderr: %s out: %s err: %w", err.Stderr, o, err)
		}
		return nil, fmt.Errorf("out: %s err: %w", o, err)
	}

	txResult, err := UnmarshalTxResult(o)
	return &txResult, err
}

func CallDrawNumber(p DrawNumberParams) (*TxResult, error) {
	gas_unit, _ := strconv.Atoi(os.Getenv("GAS_UNITS"))
	gas_price, _ := strconv.Atoi(os.Getenv("GAS_PRICE"))
	command := fmt.Sprintf("move run --function-id %s::bingov1::draw_number --max-gas %d --gas-unit-price %d --args", os.Getenv("APTOS_FUNCTION_ID"), gas_unit, gas_price)
	args := append(strings.Split(command, " "),
		argI(p.GameID))
	cmd := exec.Command("aptos", args...)
	fmt.Println(strings.Join(args, " "))

	o, err := cmd.Output()
	if err != nil {
		if err, ok := err.(*exec.ExitError); ok {
			if strings.Contains(string(o), "ERROR_METADATA_DUPLICATED(0x3)") {
				return nil, fmt.Errorf("%w: %w", ErrMetadataDuplicated, err)
			}
			return nil, fmt.Errorf("stderr: %s out: %s err: %w", err.Stderr, o, err)
		}
		return nil, fmt.Errorf("out: %s err: %w", o, err)
	}

	txResult, err := UnmarshalTxResult(o)
	return &txResult, err
}

func CallJoinGame(p JoinGameParams) (*TxResult, error) {
	gas_unit, _ := strconv.Atoi(os.Getenv("GAS_UNITS"))
	gas_price, _ := strconv.Atoi(os.Getenv("GAS_PRICE"))
	command := fmt.Sprintf("move run --function-id %s::bingov1::join_game --max-gas %d --gas-unit-price %d --args", os.Getenv("APTOS_FUNCTION_ID"), gas_unit, gas_price)
	args := append(strings.Split(command, " "),
		argI(p.GameID), argS(p.Uri), "u64:")
	cmd := exec.Command("aptos", args...)
	fmt.Println(strings.Join(args, " "))

	o, err := cmd.Output()
	if err != nil {
		if err, ok := err.(*exec.ExitError); ok {
			if strings.Contains(string(o), "ERROR_METADATA_DUPLICATED(0x3)") {
				return nil, fmt.Errorf("%w: %w", ErrMetadataDuplicated, err)
			}
			return nil, fmt.Errorf("stderr: %s out: %s err: %w", err.Stderr, o, err)
		}
		return nil, fmt.Errorf("out: %s err: %w", o, err)
	}

	txResult, err := UnmarshalTxResult(o)
	return &txResult, err
}
