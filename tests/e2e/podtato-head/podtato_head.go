package podtatoHead

/* docs
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/apps/statefulset.go
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/framework/deployment/wait.go
https://github.com/kubernetes/kubernetes/blob/42c05a547468804b2053ecf60a3bd15560362fc2/test/utils/deployment.go#L199
k8s.ovn.org/pod-networks
*/

import (
	"context"
	"github.com/onsi/ginkgo"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/kubernetes/test/e2e/framework"
	e2edeployment "k8s.io/kubernetes/test/e2e/framework/deployment"
	e2epod "k8s.io/kubernetes/test/e2e/framework/pod"
)

const (
	keptnNamespace       string = "keptn"
	keptnMinPods         int32  = 12
	podtatoheadMinPods   int32  = 12
	frameworkName        string = "podtatoHead"
	podtatoheadImageName string = "ghcr.io/podtato-head/podtatoserver:v0.1.1"
)

var f = framework.NewDefaultFramework(frameworkName)

var _ = ginkgo.Describe("e2e podtato-head", func() {
	f.SkipNamespaceCreation = true

	ginkgo.BeforeEach(func() {
		ginkgo.By("Waiting to ketpn's pods ready")
		err := e2epod.WaitForPodsRunningReady(f.ClientSet, keptnNamespace, keptnMinPods, 0, framework.PodStartShortTimeout, make(map[string]string))
		framework.ExpectNoError(err)
	})

	var _ = ginkgo.Describe("podtato-head namespaces", func() {
		ginkgo.It("podtato-head namespace for dev should exists", func() {
			_, err := f.ClientSet.CoreV1().Namespaces().Get(context.TODO(), "podtato-head-dev", metav1.GetOptions{})
			framework.ExpectNoError(err)
		})

		// TODO: fix keptn deploy
		//ginkgo.It("podtato-head namespace for prod should exists", func() {
		//	_, err := f.ClientSet.CoreV1().Namespaces().Get(context.TODO(), "podtato-head-prod", metav1.GetOptions{})
		//	framework.ExpectNoError(err)
		//})
	})

	var _ = ginkgo.Describe("podtato-head deployments", func() {
		ginkgo.It("podtato-head deployment in dev env should running", func() {
			td, err := f.ClientSet.AppsV1().Deployments("podtato-head-dev").Get(context.TODO(), "helloservice", metav1.GetOptions{})
			framework.ExpectNoError(err)

			// Wait for it to be updated to revision 1
			err = e2edeployment.WaitForDeploymentRevisionAndImage(f.ClientSet, "podtato-head-dev", "helloservice", "1", podtatoheadImageName)
			framework.ExpectNoError(err)

			err = e2edeployment.WaitForDeploymentComplete(f.ClientSet, td)
			framework.ExpectNoError(err)
		})

		//ginkgo.It("podtato-head deployment in prod env should running", func() {
		//	td, err := f.ClientSet.AppsV1().Deployments("podtato-head-prod").Get(context.TODO(), "helloservice", metav1.GetOptions{})
		//	framework.ExpectNoError(err)
		//
		//	// Wait for it to be updated to revision 1
		//	err = e2edeployment.WaitForDeploymentRevisionAndImage(f.ClientSet, "podtato-head-prod", "helloservice", "1", podtatoheadImageName)
		//	framework.ExpectNoError(err)
		//
		//	err = e2edeployment.WaitForDeploymentComplete(f.ClientSet, td)
		//	framework.ExpectNoError(err)
		//})

		// TODO: add tests for service monitor

	})

})
