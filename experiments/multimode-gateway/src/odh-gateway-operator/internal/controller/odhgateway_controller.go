/*
Copyright 2025 ODH.

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
	"sort"
	"strings"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/utils/pointer"
	"k8s.io/utils/ptr"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/event"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/predicate"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	//"sigs.k8s.io/controller-runtime/pkg/source"
	//"sigs.k8s.io/controller-runtime/pkg/source"

	gatewayv1alpha1 "github.com/jctanner/odh-gateway-operator/api/v1alpha1"
)

// ODHGatewayReconciler reconciles a ODHGateway object
type ODHGatewayReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

type RouteEntry struct {
	Path         string
	Upstream     string
	AuthRequired *bool
}

// sortRoutes sorts routes by specificity (longest path first) then alphabetically
// This ensures that more specific routes are matched before catch-all routes,
// while maintaining alphabetical order for readability when paths have the same length
func sortRoutes(routes []RouteEntry) {
	sort.Slice(routes, func(i, j int) bool {
		pathI, pathJ := routes[i].Path, routes[j].Path

		// Primary sort: by path length (descending) - longer/more specific paths first
		if len(pathI) != len(pathJ) {
			return len(pathI) > len(pathJ)
		}

		// Secondary sort: alphabetically for readability when lengths are equal
		return pathI < pathJ
	})
}

// +kubebuilder:rbac:groups=gateway.opendatahub.io,resources=odhgateways,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=gateway.opendatahub.io,resources=odhgateways/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=gateway.opendatahub.io,resources=odhgateways/finalizers,verbs=update
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=serviceaccounts,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the ODHGateway object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.20.4/pkg/reconcile
func (r *ODHGatewayReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	var cr gatewayv1alpha1.ODHGateway
	if err := r.Get(ctx, req.NamespacedName, &cr); err != nil {
		if errors.IsNotFound(err) {
			log.Info("ODHGateway resource not found")
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	defaultImage := "registry.tannerjc.net/odh/odh-gateway:latest"
	if cr.Spec.Image == nil || *cr.Spec.Image == "" {
		cr.Spec.Image = ptr.To(defaultImage)
	}

	// Default route config map
	if cr.Spec.RouteConfigMap == nil {
		cr.Spec.RouteConfigMap = &gatewayv1alpha1.RouteConfigMap{
			Name:    cr.Name + "-routes",
			Key:     "config.yaml",
			Managed: true,
		}
	}

	// Gather matching Services
	var svcs corev1.ServiceList
	if err := r.List(ctx, &svcs); err != nil {
		return ctrl.Result{}, err
	}

	var routes []RouteEntry
	for _, svc := range svcs.Items {
		if val, ok := svc.Annotations["odhgateway.opendatahub.io/enabled"]; ok && val == "true" {
			var port int32 = 80 // default

			for _, p := range svc.Spec.Ports {
				if p.Port > 0 {
					port = p.Port
					break // use the first valid port
				}
			}

					path := svc.Annotations["odhgateway.opendatahub.io/route-path"]
		//upstream := fmt.Sprintf("%s.%s.svc.cluster.local", svc.Name, svc.Namespace)
		upstream := fmt.Sprintf("http://%s.%s.svc.cluster.local:%d", svc.Name, svc.Namespace, port)
		
		// Check for auth-required annotation
		var authRequired *bool
		if authVal, ok := svc.Annotations["odhgateway.opendatahub.io/auth-required"]; ok {
			if authVal == "true" {
				authRequired = ptr.To(true)
			} else if authVal == "false" {
				authRequired = ptr.To(false)
			}
		}
		
		routes = append(routes, RouteEntry{Path: path, Upstream: upstream, AuthRequired: authRequired})
		}
	}

	// Sort routes by specificity (longest path first) then alphabetically
	// This ensures more specific routes are matched before catch-all routes
	sortRoutes(routes)

	// Managed configmap generation
	if cr.Spec.RouteConfigMap != nil && cr.Spec.RouteConfigMap.Managed {
		log.Info("Creating Route ConfigMap")
		if cr.Spec.RouteConfigMap.Name == "" {
			cr.Spec.RouteConfigMap.Name = cr.Name + "-routes"
		}
		if cr.Spec.RouteConfigMap.Key == "" {
			cr.Spec.RouteConfigMap.Key = "config.yaml"
		}

		cfg := generateRouteConfigMap(&cr, routes)
		if err := controllerutil.SetControllerReference(&cr, cfg, r.Scheme); err != nil {
			return ctrl.Result{}, err
		}
		var existingCfg corev1.ConfigMap
		err := r.Get(ctx, types.NamespacedName{Name: cfg.Name, Namespace: cfg.Namespace}, &existingCfg)
		if errors.IsNotFound(err) {
			log.Info("Creating route configmap", "name", cfg.Name)
			if err := r.Create(ctx, cfg); err != nil {
				return ctrl.Result{}, err
			}
		} else if err == nil {
			existingCfg.Data = cfg.Data
			if err := r.Update(ctx, &existingCfg); err != nil {
				return ctrl.Result{}, err
			}
		} else {
			return ctrl.Result{}, err
		}
	}

	// Create ServiceAccount if using OpenShift service account mode
	if cr.Spec.Mode == "openshift" && cr.Spec.OpenShift != nil && cr.Spec.OpenShift.ServiceAccount {
		sa := generateServiceAccount(&cr)
		if err := controllerutil.SetControllerReference(&cr, sa, r.Scheme); err != nil {
			return ctrl.Result{}, err
		}
		var existingSA corev1.ServiceAccount
		err := r.Get(ctx, types.NamespacedName{Name: sa.Name, Namespace: sa.Namespace}, &existingSA)
		if errors.IsNotFound(err) {
			log.Info("Creating ServiceAccount", "name", sa.Name)
			if err := r.Create(ctx, sa); err != nil {
				return ctrl.Result{}, err
			}
		} else if err != nil {
			return ctrl.Result{}, err
		}

		// Note: No need to create separate OAuth client - service account acts as OAuth client
	}

	deploy := generateDeployment(&cr)
	if err := controllerutil.SetControllerReference(&cr, deploy, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}
	var existingDeploy appsv1.Deployment
	err := r.Get(ctx, types.NamespacedName{Name: deploy.Name, Namespace: deploy.Namespace}, &existingDeploy)
	if errors.IsNotFound(err) {
		log.Info("Creating Deployment", "name", deploy.Name)
		if err := r.Create(ctx, deploy); err != nil {
			return ctrl.Result{}, err
		}
	} else if err != nil {
		return ctrl.Result{}, err
	}

	svc := generateService(&cr)
	if err := controllerutil.SetControllerReference(&cr, svc, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}
	var existingSvc corev1.Service
	err = r.Get(ctx, types.NamespacedName{Name: svc.Name, Namespace: svc.Namespace}, &existingSvc)
	if errors.IsNotFound(err) {
		log.Info("Creating Service", "name", svc.Name)
		if err := r.Create(ctx, svc); err != nil {
			return ctrl.Result{}, err
		}
	} else if err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func generateDeployment(cr *gatewayv1alpha1.ODHGateway) *appsv1.Deployment {
	labels := map[string]string{
		"app": cr.Name,
	}

	volumeMounts := []corev1.VolumeMount{}
	volumes := []corev1.Volume{}

	if cr.Spec.RouteConfigMap != nil {
		configMapName := cr.Spec.RouteConfigMap.Name
		configKey := cr.Spec.RouteConfigMap.Key
		if configMapName == "" {
			configMapName = cr.Name + "-routes"
		}
		if configKey == "" {
			configKey = "config.yaml"
		}

		volumeMounts = append(volumeMounts, corev1.VolumeMount{
			Name:      "route-config",
			MountPath: "/etc/odh-gateway/", // or whatever your proxy expects
			ReadOnly:  true,
		})

		volumes = append(volumes, corev1.Volume{
			Name: "route-config",
			VolumeSource: corev1.VolumeSource{
				ConfigMap: &corev1.ConfigMapVolumeSource{
					LocalObjectReference: corev1.LocalObjectReference{
						Name: configMapName,
					},
					Items: []corev1.KeyToPath{
						{
							Key:  configKey,
							Path: "config.yaml", // same name used in your proxy app
						},
					},
				},
			},
		})
	}

	return &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Name,
			Namespace: cr.Namespace,
			Labels:    labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: pointer.Int32(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
				},
				Spec: corev1.PodSpec{
					Volumes:            volumes,
					ServiceAccountName: getServiceAccountName(cr),
					Containers: []corev1.Container{
						{
							Name:  "proxy",
							Image: *cr.Spec.Image,
							Ports: []corev1.ContainerPort{
								{
									Name:          "http",
									ContainerPort: 8080,
									Protocol:      corev1.ProtocolTCP,
								},
							},
							VolumeMounts: volumeMounts,
							Env:          generateEnvironmentVariables(cr),
						},
					},
				},
			},
		},
	}
}

func generateService(cr *gatewayv1alpha1.ODHGateway) *corev1.Service {
	return &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Name + "-svc",
			Namespace: cr.Namespace,
			Labels: map[string]string{
				"app": cr.Name,
			},
		},
		Spec: corev1.ServiceSpec{
			Selector: map[string]string{
				"app": cr.Name,
			},
			Ports: []corev1.ServicePort{
				{
					Name:       "http",
					Port:       80,
					TargetPort: intstr.FromInt(8080), // Adjust if your proxy uses a different container port
					Protocol:   corev1.ProtocolTCP,
				},
			},
			Type: corev1.ServiceTypeClusterIP,
		},
	}
}

func generateServiceAccount(cr *gatewayv1alpha1.ODHGateway) *corev1.ServiceAccount {
	annotations := map[string]string{}
	
	// Add OAuth redirect URI annotation for service account OAuth client
	if cr.Spec.Hostname != "" {
		redirectURI := fmt.Sprintf("https://%s/auth/callback", cr.Spec.Hostname)
		annotations["serviceaccounts.openshift.io/oauth-redirecturi.gateway"] = redirectURI
	}
	
	return &corev1.ServiceAccount{
		ObjectMeta: metav1.ObjectMeta{
			Name:        cr.Name + "-sa",
			Namespace:   cr.Namespace,
			Annotations: annotations,
			Labels: map[string]string{
				"app": cr.Name,
			},
		},
	}
}

func getServiceAccountName(cr *gatewayv1alpha1.ODHGateway) string {
	if cr.Spec.Mode == "openshift" && cr.Spec.OpenShift != nil && cr.Spec.OpenShift.ServiceAccount {
		return cr.Name + "-sa"
	}
	return ""
}



func generateEnvironmentVariables(cr *gatewayv1alpha1.ODHGateway) []corev1.EnvVar {
	var envVars []corev1.EnvVar

	// Add gateway hostname for OAuth callbacks
	if cr.Spec.Hostname != "" {
		envVars = append(envVars, corev1.EnvVar{
			Name:  "GATEWAY_HOSTNAME",
			Value: cr.Spec.Hostname,
		})
	}

	// Add OpenShift service account environment variable if in service account mode
	if cr.Spec.Mode == "openshift" && cr.Spec.OpenShift != nil && cr.Spec.OpenShift.ServiceAccount {
		envVars = append(envVars, corev1.EnvVar{
			Name:  "OPENSHIFT_SERVICE_ACCOUNT",
			Value: cr.Name + "-sa",
		})
		
		// For CRC and development environments, skip TLS verification
		if cr.Spec.Hostname != "" && strings.Contains(cr.Spec.Hostname, "apps-crc.testing") {
			envVars = append(envVars, corev1.EnvVar{
				Name:  "OPENSHIFT_SKIP_TLS_VERIFY",
				Value: "true",
			})
		}
	}

	// Add OIDC environment variables if OIDC is configured
	if cr.Spec.Mode == "oidc" && cr.Spec.OIDC != nil {
		// OIDC Issuer URL
		envVars = append(envVars, corev1.EnvVar{
			Name:  "OIDC_ISSUER_URL",
			Value: cr.Spec.OIDC.IssuerURL,
		})

		// OIDC Client ID
		envVars = append(envVars, corev1.EnvVar{
			Name:  "OIDC_CLIENT_ID",
			Value: cr.Spec.OIDC.ClientID,
		})

		// OIDC Client Secret from secret reference
		if cr.Spec.OIDC.ClientSecretRef.Name != "" {
			envVars = append(envVars, corev1.EnvVar{
				Name: "OIDC_CLIENT_SECRET",
				ValueFrom: &corev1.EnvVarSource{
					SecretKeyRef: &corev1.SecretKeySelector{
						LocalObjectReference: corev1.LocalObjectReference{
							Name: cr.Spec.OIDC.ClientSecretRef.Name,
						},
						Key: cr.Spec.OIDC.ClientSecretRef.Key,
					},
				},
			})
		}
	}

	return envVars
}

func generateRouteConfigMap(cr *gatewayv1alpha1.ODHGateway, routes []RouteEntry) *corev1.ConfigMap {
	cfg := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Spec.RouteConfigMap.Name,
			Namespace: cr.Namespace,
			Labels: map[string]string{
				"app": cr.Name,
			},
		},
		Data: map[string]string{},
	}

	key := "config.yaml"
	if cr.Spec.RouteConfigMap.Key != "" {
		key = cr.Spec.RouteConfigMap.Key
	}

	yamlContent := ""

	// Add authentication provider configuration
	if cr.Spec.Mode == "openshift" && cr.Spec.OpenShift != nil {
		yamlContent += "provider:\n"
		yamlContent += "  type: openshift\n"
		yamlContent += "  openshift:\n"
		
		if cr.Spec.OpenShift.ServiceAccount {
			// Service account mode - auto-configuration
			yamlContent += "    serviceAccount: true\n"
			if cr.Spec.OpenShift.CABundle != "" {
				yamlContent += fmt.Sprintf("    caBundle: |\n%s\n", indentText(cr.Spec.OpenShift.CABundle, "      "))
			}
		} else {
			// Manual mode - backward compatibility
			if cr.Spec.OpenShift.ClientID != "" {
				yamlContent += fmt.Sprintf("    clientId: %s\n", cr.Spec.OpenShift.ClientID)
			}
			if cr.Spec.OpenShift.ClusterURL != "" {
				yamlContent += fmt.Sprintf("    clusterUrl: %s\n", cr.Spec.OpenShift.ClusterURL)
			}
			if cr.Spec.OpenShift.ClientSecret != "" {
				yamlContent += fmt.Sprintf("    clientSecret: %s\n", cr.Spec.OpenShift.ClientSecret)
			}
		}
		yamlContent += "\n"
	} else if cr.Spec.Mode == "oidc" && cr.Spec.OIDC != nil {
		yamlContent += "provider:\n"
		yamlContent += "  type: oidc\n"
		yamlContent += "  oidc:\n"
		yamlContent += fmt.Sprintf("    issuerUrl: %s\n", cr.Spec.OIDC.IssuerURL)
		yamlContent += fmt.Sprintf("    clientId: %s\n", cr.Spec.OIDC.ClientID)
		yamlContent += "    clientSecret: ${OIDC_CLIENT_SECRET}\n"
		yamlContent += "\n"
	}

	// Add routes configuration
	yamlContent += "routes:\n"
	for _, r := range routes {
		yamlContent += fmt.Sprintf("  - path: %s\n    upstream: %s\n", r.Path, r.Upstream)
		if r.AuthRequired != nil {
			yamlContent += fmt.Sprintf("    authRequired: %v\n", *r.AuthRequired)
		}
	}

	cfg.Data[key] = yamlContent
	return cfg
}

func indentText(text, indent string) string {
	lines := strings.Split(text, "\n")
	var indented []string
	for _, line := range lines {
		if line != "" {
			indented = append(indented, indent+line)
		} else {
			indented = append(indented, line)
		}
	}
	return strings.Join(indented, "\n")
}

func (r *ODHGatewayReconciler) SetupWithManager(mgr ctrl.Manager) error {
	//const gatewayName = "odhgateway"
	const gatewayName = "odh-gateway"
	const gatewayNamespace = "opendatahub"

	return builder.
		ControllerManagedBy(mgr).
		For(&gatewayv1alpha1.ODHGateway{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&corev1.ConfigMap{}).
		Owns(&corev1.ServiceAccount{}).
		Watches(
			&corev1.Service{},
			handler.EnqueueRequestsFromMapFunc(
				func(ctx context.Context, obj client.Object) []reconcile.Request {
					svc := obj.(*corev1.Service)
					log := ctrl.LoggerFrom(ctx)
					log.Info("Service event", "name", svc.Name, "annotations", svc.Annotations)

					val, ok := svc.Annotations["odhgateway.opendatahub.io/enabled"]
					if ok {
						log.Info("Found enabled annotation", "value", val)
					}

					if ok && val == "true" {
						log.Info("Enqueueing ODHGateway reconcile", "target", gatewayName)
						return []reconcile.Request{{
							NamespacedName: types.NamespacedName{
								Name:      gatewayName,
								Namespace: gatewayNamespace,
							},
						}}
					}
					return nil
				},
			),
			builder.WithPredicates(predicate.Funcs{
				CreateFunc: func(e event.CreateEvent) bool { return true },
				UpdateFunc: func(e event.UpdateEvent) bool { return true },
				DeleteFunc: func(e event.DeleteEvent) bool {
					_, ok := e.Object.GetAnnotations()["odhgateway.opendatahub.io/enabled"]
					return ok
				},
			}),
		).
		Complete(r)
}
