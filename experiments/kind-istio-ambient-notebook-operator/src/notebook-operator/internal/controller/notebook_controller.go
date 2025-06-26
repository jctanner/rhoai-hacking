/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"fmt"
	"net/url"

	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	gatewayv1 "sigs.k8s.io/gateway-api/apis/v1"

	//networkingv1 "sigs.k8s.io/gateway-api/apis/v1beta1"

	//v1beta1 "sigs.k8s.io/gateway-api/apis/v1beta1"

	dsv1alpha1 "github.com/example/notebook-operator/api/v1alpha1"
)

// NotebookReconciler reconciles a Notebook object
type NotebookReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=ds.example.com,resources=notebooks,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=ds.example.com,resources=notebooks/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=ds.example.com,resources=notebooks/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the Notebook object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.20.4/pkg/reconcile
func (r *NotebookReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	var notebook dsv1alpha1.Notebook
	if err := r.Get(ctx, req.NamespacedName, &notebook); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	//podName := notebook.Name + "-pod"
	podName := notebook.Name

	var pod corev1.Pod
	err := r.Get(ctx, types.NamespacedName{Name: podName, Namespace: notebook.Namespace}, &pod)
	if err == nil {
		// Pod already exists
		return ctrl.Result{}, nil
	} else if !apierrors.IsNotFound(err) {
		// Some other error
		return ctrl.Result{}, err
	}

	image := notebook.Spec.Image
	if image == "" {
		image = "jupyter/scipy-notebook:latest" // default image
	}

	port := notebook.Spec.Port
	if port == 0 {
		port = 8888 // default Jupyter port
	}

	args := []string{
		"start-notebook.sh",
		"--NotebookApp.token=",
		"--NotebookApp.password=",
		"--ServerApp.base_url=/notebooks/" + url.PathEscape(notebook.Name),
		fmt.Sprintf("--port=%d", port),
	}

	// Create new pod
	newPod := corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      podName,
			Namespace: notebook.Namespace,
			Labels: map[string]string{
				"app": "notebook",
				"notebook": notebook.Name,
			},
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name:  "jupyter",
					Image: image,
					Ports: []corev1.ContainerPort{{ContainerPort: port}},
					Args:  args,
				},
			},
		},
	}

	if err := ctrl.SetControllerReference(&notebook, &newPod, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	if err := r.Create(ctx, &newPod); err != nil {
		return ctrl.Result{}, err
	}

	log.Info("Created new Pod for Notebook", "pod", newPod.Name)

	// Create a Service for the notebook pod if it doesn't exist
	svcName := notebook.Name + "-svc"
	var svc corev1.Service
	err = r.Get(ctx, types.NamespacedName{Name: svcName, Namespace: notebook.Namespace}, &svc)
	if err != nil && errors.IsNotFound(err) {
		svc = corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      svcName,
				Namespace: notebook.Namespace,
			},
			Spec: corev1.ServiceSpec{
				Selector: map[string]string{
					"app":      "notebook",
					"notebook": notebook.Name,
				},
				Ports: []corev1.ServicePort{
					{
						Port:       port,
						TargetPort: intstrFromInt(port),
						Protocol:   corev1.ProtocolTCP,
					},
				},
			},
		}

		if err := ctrl.SetControllerReference(&notebook, &svc, r.Scheme); err != nil {
			return ctrl.Result{}, err
		}
		if err := r.Create(ctx, &svc); err != nil {
			return ctrl.Result{}, err
		}
	}

	log.Info("Created new Service for Notebook", "svc", svc.Name)

	// Create HTTPRoute for /notebooks/<name>
	routeName := notebook.Name + "-route"
	//var route networkingv1.HTTPRoute
	var route gatewayv1.HTTPRoute
	err = r.Get(ctx, types.NamespacedName{Name: routeName, Namespace: notebook.Namespace}, &route)
	log.Error(err, "route")
	if err != nil && errors.IsNotFound(err) {
		route := gatewayv1.HTTPRoute{
			ObjectMeta: metav1.ObjectMeta{
				Name:      routeName,
				Namespace: notebook.Namespace,
				Labels:    map[string]string{"app": notebook.Name},
			},
			Spec: gatewayv1.HTTPRouteSpec{
				CommonRouteSpec: gatewayv1.CommonRouteSpec{ // 👈 ParentRefs moved here
					ParentRefs: []gatewayv1.ParentReference{{
						Name:      gatewayv1.ObjectName("notebooks-gateway"),
						Namespace: ptr(gatewayv1.Namespace(notebook.Namespace)),
					}},
				},
				Rules: []gatewayv1.HTTPRouteRule{{
					Matches: []gatewayv1.HTTPRouteMatch{{
						Path: &gatewayv1.HTTPPathMatch{
							Type:  ptr(gatewayv1.PathMatchPathPrefix),
							Value: ptr("/notebooks/" + url.PathEscape(notebook.Name)),
						},
					}},
					BackendRefs: []gatewayv1.HTTPBackendRef{{
						BackendRef: gatewayv1.BackendRef{
							BackendObjectReference: gatewayv1.BackendObjectReference{
								Name: gatewayv1.ObjectName(svcName),
								Port: ptr(gatewayv1.PortNumber(port)),
							},
							// Optional:
							// Weight: ptr(int32(1)),
						},
					}},
				}},
			},
		}

		if err := ctrl.SetControllerReference(&notebook, &route, r.Scheme); err != nil {
			return ctrl.Result{}, err
		}
		if err := r.Create(ctx, &route); err != nil {
			return ctrl.Result{}, err
		}

		log.Info("Created new HTTPRoute for Notebook", "route", route.Name)
	}

	//log.Info("Created new HTTPRoute for Notebook", "route", route.Name)

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *NotebookReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&dsv1alpha1.Notebook{}).
		Named("notebook").
		Complete(r)
}

func intstrFromInt(i int32) intstr.IntOrString {
	return intstr.IntOrString{Type: intstr.Int, IntVal: i}
}

func ptrToPortNumber(p int32) *gatewayv1.PortNumber {
	port := gatewayv1.PortNumber(p)
	return &port
}

func pathMatchPrefix() *gatewayv1.PathMatchType {
	prefix := gatewayv1.PathMatchPathPrefix
	return &prefix
}

func ptr[T any](v T) *T {
	return &v
}
