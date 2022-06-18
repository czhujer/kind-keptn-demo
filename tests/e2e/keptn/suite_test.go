package keptn

import (
	"flag"
	"fmt"
	cmFramework "github.com/cert-manager/cert-manager/test/e2e/framework"
	cmAddon "github.com/cert-manager/cert-manager/test/e2e/framework/addon"
	"github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/config"
	"github.com/onsi/ginkgo/reporters"
	"github.com/onsi/gomega"
	"k8s.io/klog"
	"k8s.io/kubernetes/test/e2e/framework"
	e2econfig "k8s.io/kubernetes/test/e2e/framework/config"
	e2elog "k8s.io/kubernetes/test/e2e/framework/log"
	"k8s.io/kubernetes/test/e2e/framework/testfiles"
	"k8s.io/kubernetes/test/utils/image"
	"os"
	"path"
	"path/filepath"
	"testing"
)

const kubeconfigEnvVar = "KUBECONFIG"

var (
	cfg = cmFramework.DefaultConfig
)

// handleFlags sets up all flags and parses the command line.
func handleFlags() {
	e2econfig.CopyFlags(e2econfig.Flags, flag.CommandLine)
	framework.RegisterCommonFlags(flag.CommandLine)
	framework.RegisterClusterFlags(flag.CommandLine)
	flag.Parse()
}

// required due to go1.13 issue: https://github.com/onsi/ginkgo/issues/602
func TestMain(m *testing.M) {
	var err error
	var kubeconfig string

	// k8s.io/kubernetes/test/e2e/framework requires env KUBECONFIG to be set
	// it does not fall back to defaults
	if os.Getenv(kubeconfigEnvVar) == "" {
		kubeconfig = filepath.Join(os.Getenv("HOME"), ".kube", "config")
		err := os.Setenv(kubeconfigEnvVar, kubeconfig)
		if err != nil {
			e2elog.Logf("Set kubeconfig env finished with error: %v", err)
		}
	}

	// Register test flags, then parse flags.
	handleFlags()

	// Register flags for CM
	cmFramework.DefaultConfig.KubeConfig = kubeconfig

	cmAddon.InitGlobals(cfg)

	err = cmAddon.ProvisionGlobals(cfg)
	if err != nil {
		framework.Failf("Error provisioning global addons: %v", err)
	}

	cmAddon.InitGlobals(cfg)

	err = cmAddon.SetupGlobals(cfg)
	if err != nil {
		framework.Failf("Error configuring global addons: %v", err)
	}

	// end of registering CM stuff

	if framework.TestContext.ListImages {
		for _, v := range image.GetImageConfigs() {
			fmt.Println(v.GetE2EImage())
		}
		os.Exit(0)
	}

	framework.AfterReadingAllFlags(&framework.TestContext)

	klog.Infof("Using kubeconfig: %s\n", framework.TestContext.KubeConfig)

	// TODO: Deprecating repo-root over time... instead just use gobindata_util.go , see #23987.
	// Right now it is still needed, for example by
	// test/e2e/framework/ingress/ingress_utils.go
	// for providing the optional secret.yaml file and by
	// test/e2e/framework/util.go for cluster/log-dump.
	if framework.TestContext.RepoRoot != "" {
		testfiles.AddFileSource(testfiles.RootFileSource{Root: framework.TestContext.RepoRoot})
	}

	// Enable bindata file lookup as fallback.
	//testfiles.AddFileSource(testfiles.BindataFileSource{
	//	Asset:      generated.Asset,
	//	AssetNames: generated.AssetNames,
	//})
	os.Exit(m.Run())
}

func TestE2e(t *testing.T) {
	// Run tests through the Ginkgo runner with output to console + JUnit for reporting
	var r []ginkgo.Reporter
	if framework.TestContext.ReportDir != "" {
		klog.Infof("Saving reports to %s", framework.TestContext.ReportDir)
		// TODO: we should probably only be trying to create this directory once
		// rather than once-per-Ginkgo-node.
		if err := os.MkdirAll(framework.TestContext.ReportDir, 0755); err != nil {
			klog.Errorf("Failed creating report directory: %v", err)
		} else {
			r = append(r, reporters.NewJUnitReporter(path.Join(framework.TestContext.ReportDir, fmt.Sprintf("junit_%v%02d.xml", framework.TestContext.ReportPrefix, config.GinkgoConfig.ParallelNode))))
		}
	} else {
		klog.Infof("ReportDir is not set")
	}
	gomega.RegisterFailHandler(framework.Fail)
	ginkgo.RunSpecsWithDefaultAndCustomReporters(t, "E2E Keptn Suite", r)
}
