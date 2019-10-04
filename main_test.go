package main

import (
	"fmt"
	"os"
	"testing"
	"time"
)

func TestSleep(t *testing.T) {
	fmt.Printf("Unix Time before sleep: %v\n", time.Now().Unix())
	if sleep, ok := os.LookupEnv("SLEEP_DURATION"); ok {
		if duration, err := time.ParseDuration(sleep); err != nil {
			t.Error(err)
		} else {
			fmt.Printf("Sleeping for %s\n", duration)
			time.Sleep(duration)
		}
	}
	fmt.Printf("Unix Time after sleep: %v\n", time.Now().Unix())
}
