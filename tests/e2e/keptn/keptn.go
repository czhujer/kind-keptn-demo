package keptn

/* docs
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/apps/statefulset.go
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/framework/deployment/wait.go
https://github.com/kubernetes/kubernetes/blob/42c05a547468804b2053ecf60a3bd15560362fc2/test/utils/deployment.go#L199
k8s.ovn.org/pod-networks
*/

import (
	"context"
	"github.com/onsi/ginkgo"
	"github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/kubernetes/test/e2e/framework"
	e2edeployment "k8s.io/kubernetes/test/e2e/framework/deployment"
	e2epod "k8s.io/kubernetes/test/e2e/framework/pod"
)

const (
	keptnNamespace   string = "keptn"
	keptnMinPods     int32  = 12
	frameworkName    string = "keptn"
	mongodbImageName string = "docker.io/bitnami/mongodb:4.4.13-debian-10-r33"
)

var f = framework.NewDefaultFramework(frameworkName)

var _ = ginkgo.Describe("e2e keptn", func() {
	f.SkipNamespaceCreation = true

	//ginkgo.BeforeEach(func() {
	//})

	var _ = ginkgo.Describe("nats server", func() {
		ginkgo.It("nats server should running", func() {
			ss, err := f.ClientSet.AppsV1().StatefulSets(keptnNamespace).Get(context.TODO(), "keptn-nats-cluster", metav1.GetOptions{})
			framework.ExpectNoError(err)

			statefulsetWaitForRunning(f.ClientSet, 1, 1, ss)
		})
	})

	var _ = ginkgo.Describe("mongodb server", func() {
		ginkgo.It("mongodb server should running", func() {
			td, err := f.ClientSet.AppsV1().Deployments(keptnNamespace).Get(context.TODO(), "keptn-mongo", metav1.GetOptions{})
			framework.ExpectNoError(err)

			// Wait for it to be updated to revision 1
			err = e2edeployment.WaitForDeploymentRevisionAndImage(f.ClientSet, keptnNamespace, "keptn-mongo", "1", mongodbImageName)
			framework.ExpectNoError(err)

			err = e2edeployment.WaitForDeploymentComplete(f.ClientSet, td)
			framework.ExpectNoError(err)
		})
	})

	var _ = ginkgo.Describe("Control Plane", func() {
		ginkgo.It("keptn control plane should have pods running", func() {
			// TODO: rewrite get pods for getting over clientSet
			str := framework.RunKubectlOrDie(keptnNamespace, "get", "pods")
			gomega.Expect(str).Should(gomega.MatchRegexp("api-gateway-nginx-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("api-service-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("approval-service-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("bridge-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("configuration-service-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("lighthouse-service-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("mongodb-datastore-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("remediation-service-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("secret-service-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("shipyard-controller-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("statistics-service-"))
			gomega.Expect(str).Should(gomega.MatchRegexp("statistics-service-"))

			ginkgo.By("Waiting to keptn's pods ready")
			err := e2epod.WaitForPodsRunningReady(f.ClientSet, keptnNamespace, keptnMinPods, 0, framework.PodStartShortTimeout, make(map[string]string))
			framework.ExpectNoError(err)
		})
	})
})
