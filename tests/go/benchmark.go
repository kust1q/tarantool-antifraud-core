package main

import (
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"

	"github.com/tarantool/go-tarantool"
)

const (
	Addr        = "127.0.0.1:3301"
	Concurrency = 100
	Requests    = 100000
)

func main() {
	opts := tarantool.Opts{
		User: "guest",
	}
	conn, err := tarantool.Connect(Addr, opts)
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	fmt.Printf("Starting benchmark: %d requests, %d concurrency\n", Requests, Concurrency)

	var wg sync.WaitGroup
	start := time.Now()

	reqPerWorker := Requests / Concurrency
	for i := 0; i < Concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for j := 0; j < reqPerWorker; j++ {
				userID := rand.Intn(2) + 1
				amount := 1.0
				ip := fmt.Sprintf("192.168.1.%d", rand.Intn(255))
				ts := time.Now().Unix()

				var res []interface{}
				err := conn.CallTyped("process_transaction", []interface{}{userID, amount, ip, ts}, &res)
				if err != nil {
					log.Printf("Error in worker %d: %v", workerID, err)
					return
				}
			}
		}(i)
	}

	wg.Wait()
	elapsed := time.Since(start)
	tps := float64(Requests) / elapsed.Seconds()

	fmt.Printf("Benchmark finished in %v\n", elapsed)
	fmt.Printf("Throughput: %.2f TPS\n", tps)
	fmt.Printf("Avg Latency: %v\n", elapsed/Requests)
}
