package keptn

import (
	"context"
	"fmt"
	appsv1 "k8s.io/api/apps/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	clientset "k8s.io/client-go/kubernetes"
	"k8s.io/kubectl/pkg/util/podutils"
	"k8s.io/kubernetes/test/e2e/framework"
	"regexp"
	"sort"
	"strconv"
)

/* docs
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/apps/statefulset.go
https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/framework/deployment/wait.go
https://github.com/kubernetes/kubernetes/blob/42c05a547468804b2053ecf60a3bd15560362fc2/test/utils/deployment.go#L199
k8s.ovn.org/pod-networks
*/

// copied from:
// https://github.com/kubernetes/kubernetes/blob/v1.23.7/test/e2e/framework/statefulset/wait.go#L34

var statefulPodRegex = regexp.MustCompile("(.*)-([0-9]+)$")

type statefulPodsByOrdinal []v1.Pod

func getStatefulPodOrdinal(pod *v1.Pod) int {
	ordinal := -1
	subMatches := statefulPodRegex.FindStringSubmatch(pod.Name)
	if len(subMatches) < 3 {
		return ordinal
	}
	if i, err := strconv.ParseInt(subMatches[2], 10, 32); err == nil {
		ordinal = int(i)
	}
	return ordinal
}

func getPodList(c clientset.Interface, ss *appsv1.StatefulSet) *v1.PodList {
	selector, err := metav1.LabelSelectorAsSelector(ss.Spec.Selector)
	framework.ExpectNoError(err)
	podList, err := c.CoreV1().Pods(ss.Namespace).List(context.TODO(), metav1.ListOptions{LabelSelector: selector.String()})
	framework.ExpectNoError(err)
	return podList
}

func sortStatefulPods(pods *v1.PodList) {
	sort.Sort(statefulPodsByOrdinal(pods.Items))
}

func (sp statefulPodsByOrdinal) Len() int {
	return len(sp)
}

func (sp statefulPodsByOrdinal) Swap(i, j int) {
	sp[i], sp[j] = sp[j], sp[i]
}

func (sp statefulPodsByOrdinal) Less(i, j int) bool {
	return getStatefulPodOrdinal(&sp[i]) < getStatefulPodOrdinal(&sp[j])
}

func statefulsetWaitForRunning(c clientset.Interface, numPodsRunning, numPodsReady int32, ss *appsv1.StatefulSet) {
	check := func() (bool, error) {
		podList := getPodList(c, ss)
		sortStatefulPods(podList)
		if int32(len(podList.Items)) < numPodsRunning {
			framework.Logf("Found %d stateful pods, waiting for %d", len(podList.Items), numPodsRunning)
			return false, nil
		}
		if int32(len(podList.Items)) > numPodsRunning {
			return false, fmt.Errorf("too many pods scheduled, expected %d got %d", numPodsRunning, len(podList.Items))
		}
		for _, p := range podList.Items {
			shouldBeReady := getStatefulPodOrdinal(&p) < int(numPodsReady)
			isReady := podutils.IsPodReady(&p)
			desiredReadiness := shouldBeReady == isReady
			framework.Logf("Waiting for pod %v to enter %v - Ready=%v, currently %v - Ready=%v", p.Name, v1.PodRunning, shouldBeReady, p.Status.Phase, isReady)
			if p.Status.Phase != v1.PodRunning || !desiredReadiness {
				return false, nil
			}
		}
		return true, nil
	}
	_, checkErr := check()

	if checkErr != nil {
		framework.Failf("Failed waiting for pods to enter running: %v", checkErr)
	}
}
