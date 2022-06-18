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
	keptnNamespace string = "keptn"
	keptnMinPods   int32  = 12
	frameworkName  string = "keptn"
)

var (
	f = framework.NewDefaultFramework(frameworkName)
)

var _ = ginkgo.Describe("e2e keptn", func() {
	f.SkipNamespaceCreation = true

	//ginkgo.BeforeEach(func() {
	//	ginkgo.By("Waiting to ketpn's pods ready")
	//	err := e2epod.WaitForPodsRunningReady(f.ClientSet, keptnNamespace, keptnMinPods, 0, framework.PodStartShortTimeout, make(map[string]string))
	//	framework.ExpectNoError(err)
	//
	//	tk := e2ekubectl.NewTestKubeconfig(framework.TestContext.CertDir, framework.TestContext.Host, framework.TestContext.KubeConfig, framework.TestContext.KubeContext, framework.TestContext.KubectlPath, "")
	//
	//	ginkgo.By("creating certs and issuer objects")
	//	util.ApplyManifest(tk, "../../assets/k8s/ca/cert-manager-issuer-kind-test.yaml")
	//	util.ApplyManifest(tk, "../../assets/k8s/ca/cert-manager-issuer-kind-ca-test.yaml")
	//	util.ApplyManifest(tk, "../../assets/k8s/certs/cert-manager-certificate-test1.yaml")
	//	util.ApplyManifest(tk, "../../assets/k8s/certs/cert-manager-certificate-test2.yaml")
	//
	//})

	//var _ = ginkgo.Describe("nats server", func() {
	//	ginkgo.It("should running", func() {
	//		ss, err := f.ClientSet.AppsV1().StatefulSets(keptnNamespace).Get(context.TODO(), "keptn-nats-cluster", metav1.GetOptions{})
	//		framework.ExpectNoError(err)
	//
	//		e2estatefulset.WaitForRunning(f.ClientSet, 1, 1, ss)
	//	})
	//})

	var _ = ginkgo.Describe("mongodb server", func() {
		ginkgo.It("should running", func() {
			td, err := f.ClientSet.AppsV1().Deployments(keptnNamespace).Get(context.TODO(), "keptn-mongo", metav1.GetOptions{})
			framework.ExpectNoError(err)

			// Wait for it to be updated to revision 1
			err = e2edeployment.WaitForDeploymentRevisionAndImage(f.ClientSet, keptnNamespace, "keptn-mongo", "1", "docker.io/bitnami/mongodb")
			framework.ExpectNoError(err)

			err = e2edeployment.WaitForDeploymentComplete(f.ClientSet, td)
			framework.ExpectNoError(err)
		})
	})

	var _ = ginkgo.Describe("Control Plane", func() {
		ginkgo.It("should pods running", func() {
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

			ginkgo.By("Waiting to ketpn's pods ready")
			err := e2epod.WaitForPodsRunningReady(f.ClientSet, keptnNamespace, keptnMinPods, 0, framework.PodStartShortTimeout, make(map[string]string))
			framework.ExpectNoError(err)
		})
	})

	//var _ = ginkgo.Describe("--> Issuers", func() {
	//
	//	ginkgo.It("should Issuer exists in namespace cert-manager-local-ca", func() {
	//		ret, err := util.GetCrdObjects(f.ClientSet, "/apis/cert-manager.io/v1/namespaces/cert-manager-local-ca/issuers")
	//		if err != nil {
	//			klog.Infof("get crd err: %v", err)
	//		}
	//		//klog.Infof("XXX crd list: %v", ret)
	//		gomega.Expect(ret.Items[0].Name).Should(gomega.MatchRegexp("kind-test-issuer"))
	//	})
	//
	//	ginkgo.It("should Issuer be in ready in namespace cert-manager-local-ca", func() {
	//		ginkgo.By("Waiting for Issuer to become Ready")
	//		err := cmUtil.WaitForIssuerCondition(cmFw.CertManagerClientSet.CertmanagerV1().Issuers("cert-manager-local-ca"),
	//			"kind-test-issuer",
	//			v1.IssuerCondition{
	//				Type:   v1.IssuerConditionReady,
	//				Status: cmmeta.ConditionTrue,
	//			})
	//		gomega.Expect(err).NotTo(gomega.HaveOccurred())
	//	})
	//
	//	ginkgo.It("should Issuer exists in namespace cert-manager-local-ca2", func() {
	//		ret, err := util.GetCrdObjects(f.ClientSet, "/apis/cert-manager.io/v1/namespaces/cert-manager-local-ca2/issuers")
	//		if err != nil {
	//			klog.Infof("get crd err: %v", err)
	//		}
	//		//klog.Infof("DEBUG: issuers crd list: %v", ret)
	//		gomega.Expect(ret.Items[0].Name).Should(gomega.MatchRegexp("ca-issuer"))
	//	})
	//
	//	ginkgo.It("should Issuer be in ready in namespace cert-manager-local-ca2", func() {
	//		ginkgo.By("Waiting for Issuer to become Ready")
	//		err := cmUtil.WaitForIssuerCondition(cmFw.CertManagerClientSet.CertmanagerV1().Issuers("cert-manager-local-ca2"),
	//			"ca-issuer",
	//			v1.IssuerCondition{
	//				Type:   v1.IssuerConditionReady,
	//				Status: cmmeta.ConditionTrue,
	//			})
	//		gomega.Expect(err).NotTo(gomega.HaveOccurred())
	//	})
	//})
	//
	//var _ = ginkgo.Describe("--> Certificates/Secrets", func() {
	//	ginkgo.It("should provide cert-key for cert-manager-local-ca", func() {
	//
	//		ginkgo.By("Waiting for the Certificate to be issued...")
	//		certContext, _ := cmFw.CertManagerClientSet.CertmanagerV1().Certificates("cert-manager-local-ca").Get(context.TODO(), "certificate-test1", metav1.GetOptions{})
	//		_, err := cmFw.Helper().WaitForCertificateReadyAndDoneIssuing(certContext, time.Minute*5)
	//		gomega.Expect(err).NotTo(gomega.HaveOccurred())
	//
	//		ginkgo.By("Fetching secret's details...")
	//		ret, err := f.ClientSet.CoreV1().
	//			Secrets("cert-manager-local-ca").
	//			Get(context.TODO(), "test1-tls", metav1.GetOptions{})
	//		if err != nil {
	//			klog.Infof("get secret err: %v", err)
	//		}
	//		//klog.Infof("get secret ret: %v", ret)
	//		gomega.Expect(ret.Name).Should(gomega.MatchRegexp("test1-tls"))
	//	})
	//
	//	ginkgo.It("should provide cert-key for cert-manager-local-ca2", func() {
	//
	//		ginkgo.By("Waiting for the Certificate to be issued...")
	//		certContext, _ := cmFw.CertManagerClientSet.CertmanagerV1().Certificates("cert-manager-local-ca2").Get(context.TODO(), "certificate-test2", metav1.GetOptions{})
	//		_, err := cmFw.Helper().WaitForCertificateReadyAndDoneIssuing(certContext, time.Minute*5)
	//		gomega.Expect(err).NotTo(gomega.HaveOccurred())
	//
	//		ginkgo.By("Fetching secret's details...")
	//		ret, err := f.ClientSet.CoreV1().
	//			Secrets("cert-manager-local-ca2").
	//			Get(context.TODO(), "test2-tls", metav1.GetOptions{})
	//		if err != nil {
	//			klog.Infof("get secret err: %v", err)
	//		}
	//		//klog.Infof("get secret ret: %v", ret)
	//		gomega.Expect(ret.Name).Should(gomega.MatchRegexp("test2-tls"))
	//	})
	//})

})
