package main

import (
	"flag"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/go-rod/rod"
	"github.com/go-rod/rod/lib/launcher"
	"github.com/go-rod/stealth"
)

func main() {
	url := flag.String("url", env("CELLGUARD_UI_URL", "http://localhost:3000/dashboard"), "UI URL to capture")
	out := flag.String("out", env("CELLGUARD_UI_SCREENSHOT", "tmp/ui-dashboard.png"), "screenshot output path")
	headed := flag.Bool("headed", false, "run with visible browser window")
	flag.Parse()

	l := launcher.New().
		Headless(!*headed).
		Set("window-size", "1440,1024")
	defer l.Cleanup()

	browser := rod.New().ControlURL(l.MustLaunch()).MustConnect()
	defer browser.MustClose()

	page := stealth.MustPage(browser)
	page.Timeout(30 * time.Second).MustNavigate(*url).MustWaitLoad()
	wait := page.MustWaitRequestIdle()
	wait()

	if err := os.MkdirAll(filepath.Dir(*out), 0o755); err != nil {
		log.Fatalf("create screenshot dir: %v", err)
	}
	page.MustScreenshot(*out)

	title := page.MustInfo().Title
	log.Printf("captured title=%q url=%s screenshot=%s", title, *url, *out)
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
