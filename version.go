package imposm3

var Version string

// buidVersion gets replaced while building with
// go build -ldflags "-X github.com/unibasil/imposm3.buildVersion 1234"
var buildVersion string

func init() {
	Version = "0.5.0"
	Version += buildVersion
}
