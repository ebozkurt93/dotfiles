package main

import (
	"fmt"
	"log"
	"strconv"
	"strings"

	"github.com/gocolly/colly"
)

type countryInfo struct {
	name                   string
	code                   string
	todayDeathCount        int
	todayNewCaseCount      int
	yesterdayDeathCount    int
	yesterdayNewCaseCount  int
	twoDaysAgoDeathCount   int
	twoDaysAgoNewCaseCount int
}

type result struct {
	newDeathCount int
	newCaseCount  int
}

func x(countries []countryInfo, e *colly.HTMLElement) map[int]result {
	iterCount := 0
	countryIndex := -1
	results := make(map[int]result)
	e.ForEach("tr td", func(_ int, el *colly.HTMLElement) {
		if iterCount > 0 {
			// new cases
			if iterCount == 3 {
				text := strings.ReplaceAll(strings.TrimSpace(el.Text), ",", "")
				updatedResults := results[countryIndex]
				if val, err := strconv.Atoi(text); err != nil {
					updatedResults.newCaseCount = 0
				} else {
					updatedResults.newCaseCount = val
				}
				results[countryIndex] = updatedResults
			}
			// new deaths
			if iterCount == 1 {
				text := strings.ReplaceAll(strings.TrimSpace(el.Text), ",", "")
				updatedResults := results[countryIndex]
				if val, err := strconv.Atoi(text); err != nil {
					updatedResults.newDeathCount = 0
				} else {
					updatedResults.newDeathCount = val
				}
				results[countryIndex] = updatedResults
			}
			iterCount--
		}
		for i, country := range countries {
			if el.Text == country.name {
				countryIndex = i
				iterCount = 4
			}
		}
	})
	return results
}

func main() {
	url := "https://www.worldometers.info/coronavirus/"
	countries := []countryInfo{
		{
			name: "Turkey",
			code: "TR",
		},
		{
			name: "Sweden",
			code: "SE",
		},
	}

	c := colly.NewCollector(colly.Async(false))
	c.OnHTML(`table[id=main_table_countries_today]`, func(e *colly.HTMLElement) {
		for k, v := range x(countries, e) {
			countries[k].todayDeathCount = v.newDeathCount
			countries[k].todayNewCaseCount = v.newCaseCount
		}
	})
	c.OnHTML(`table[id=main_table_countries_yesterday]`, func(e *colly.HTMLElement) {
		for k, v := range x(countries, e) {
			countries[k].yesterdayDeathCount = v.newDeathCount
			countries[k].yesterdayNewCaseCount = v.newCaseCount
		}
	})
	c.OnHTML(`table[id=main_table_countries_yesterday2]`, func(e *colly.HTMLElement) {
		for k, v := range x(countries, e) {
			countries[k].twoDaysAgoDeathCount = v.newDeathCount
			countries[k].twoDaysAgoNewCaseCount = v.newCaseCount
		}
	})

	c.OnError(func(_ *colly.Response, err error) {
		log.Println("Something went wrong:", err)
	})

	c.Visit(url)

	// Death counts
	res := "💀 "
	for _, c := range countries {
		res += fmt.Sprintf("%s:%d ", c.code, c.todayDeathCount)
	}
	fmt.Println(strings.TrimSpace(res))
	fmt.Println("---")
	y := "Yesterday → "
	for _, c := range countries {
		y += fmt.Sprintf("%s:%d ", c.code, c.yesterdayDeathCount)
	}
	y += "\nTwo days ago → "
	for _, c := range countries {
		y += fmt.Sprintf("%s:%d ", c.code, c.twoDaysAgoDeathCount)
	}
	fmt.Println(strings.TrimSpace(y))
	fmt.Println("---")

	// Case counts
	res2 := "🤮 "
	for _, c := range countries {
		res2 += fmt.Sprintf("%s:%d ", c.code, c.todayNewCaseCount)
	}
	fmt.Println(strings.TrimSpace(res2))
	fmt.Println("---")
	y2 := "Yesterday → "
	for _, c := range countries {
		y2 += fmt.Sprintf("%s:%d ", c.code, c.yesterdayNewCaseCount)
	}
	y2 += "\nTwo days ago → "
	for _, c := range countries {
		y2 += fmt.Sprintf("%s:%d ", c.code, c.twoDaysAgoNewCaseCount)
	}
	fmt.Println(strings.TrimSpace(y2))

	// Generic information and refresh stuff
	fmt.Println("---")
	fmt.Println("Refresh | refresh=true")
	fmt.Println("---")
	for _, c := range countries {
		fmt.Printf("Go to site → %s | href=%s\n", c.name, fmt.Sprintf("%scountry/%s", url, c.name))
	}
	fmt.Printf("Go to site | href=%s", url)
}
