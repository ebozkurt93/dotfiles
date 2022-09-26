package main

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"strconv"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

type response struct {
	Base     string
	Target   string
	Rate     float64
	URL      string
	HasError bool
}

type value struct {
	rate float64
	url  string
}

type results struct {
	base    string
	targets map[string]value
}

func getExchangeRates(base string, target string) response {
	baseURL := "https://www.investing.com/currencies/%s-%s-converter"
	baseURL = fmt.Sprintf(baseURL, strings.ToLower(base), strings.ToLower(target))

	req, err := http.NewRequest("GET", baseURL, nil)
	if err != nil {
		log.Fatalln(err)
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.105 Safari/537.36")
	req.Header.Set("Accept-Encoding", "gzip, deflate, br")

	client := &http.Client{}

	resp, err := client.Do(req)
	if err != nil {
		log.Fatalln(err)
	}
	defer resp.Body.Close()

	var reader io.ReadCloser
	switch resp.Header.Get("Content-Encoding") {
	case "gzip":
		reader, err = gzip.NewReader(resp.Body)
		defer reader.Close()
	default:
		reader = resp.Body
	}

	buf := new(bytes.Buffer)
	buf.ReadFrom(reader)
	body := buf.String()

	doc, _ := goquery.NewDocumentFromReader(strings.NewReader(string(body)))

	parts := strings.Split(doc.Find(".rate1").Text(), " ")
	rate := -1.0
	if len(parts) > 3 {
		rate, _ = strconv.ParseFloat(parts[3], 64)
	}

	return response{
		Base:     base,
		Target:   target,
		Rate:     rate,
		URL:      baseURL,
		HasError: rate < 0,
	}
}

func printExchangeRates(r results) {
	for k, v := range r.targets {
		rate := math.Floor(v.rate*100) / 100 // prevent rounding for 2 precision points
		fmt.Printf("%s: %5.2f\n", k, rate)
		fmt.Printf("%s/%s: %5.4f | alternate=true href=%s\n", r.base, k, v.rate, v.url)
	}
	fmt.Println("---")
	fmt.Printf("From: %s\n", r.base)
}

func getExchangeRatesCh(base string, target string, returnCh chan<- response) {
	returnCh <- getExchangeRates(base, target)
}

func getMultipleRatesForBase(base string, targets []string, returnCh chan<- results) {
	resultsCh := make(chan response, len(targets))
	for _, v := range targets {
		go getExchangeRatesCh(base, v, resultsCh)
	}

	r := results{
		base:    base,
		targets: make(map[string]value),
	}
	for i := 0; i < cap(resultsCh); i++ {
		x := <-resultsCh
		r.targets[x.Target] = value{rate: x.Rate, url: x.URL}
	}
	returnCh <- r
}

func main() {
	eurCh := make(chan results)
	usdCh := make(chan results)
	tryCh := make(chan results)
	go getMultipleRatesForBase("EUR", []string{"USD", "TRY", "SEK"}, eurCh)
	go getMultipleRatesForBase("USD", []string{"EUR", "TRY", "SEK"}, usdCh)
	go getMultipleRatesForBase("TRY", []string{"SEK"}, tryCh)
	printExchangeRates(<-eurCh)
	fmt.Println("---")
	printExchangeRates(<-usdCh)
	fmt.Println("---")
	printExchangeRates(<-tryCh)
	fmt.Println("---")
	fmt.Println("Refresh | refresh=true")
}
