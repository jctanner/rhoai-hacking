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

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// ODHGatewaySpec defines the desired state of ODHGateway.
type ODHGatewaySpec struct {
	Mode          string  `json:"mode"`            // "oidc" or "openshift"
	ConfigMapName string  `json:"configMapName"`   // name of the main proxy ConfigMap
	Image         *string `json:"image,omitempty"` // proxy image to run
	Hostname      string  `json:"hostname"`        // external hostname/route

	OIDC      *OIDCConfig      `json:"oidc,omitempty"`
	OpenShift *OpenShiftConfig `json:"openshift,omitempty"`

	NamespaceSelector *NamespaceSelector `json:"namespaceSelector,omitempty"`
	RouteConfigMap    *RouteConfigMap    `json:"routeConfigMap,omitempty"`
}

type OIDCConfig struct {
	IssuerURL       string                   `json:"issuerURL"`
	ClientID        string                   `json:"clientID"`
	ClientSecretRef corev1.SecretKeySelector `json:"clientSecretRef"`
}

type OpenShiftConfig struct {
	ClientID    string `json:"clientID"`
	ClusterURL  string `json:"clusterURL"`
	ClientSecret string `json:"clientSecret,omitempty"`
}

type NamespaceSelector struct {
	Include []string `json:"include,omitempty"`
}

type RouteConfigMap struct {
	Name    string `json:"name,omitempty"`
	Managed bool   `json:"managed,omitempty"`
	Key     string `json:"key,omitempty"` // optional, default "config.yaml"
}

// ODHGatewayStatus defines the observed state of ODHGateway.
type ODHGatewayStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// ODHGateway is the Schema for the odhgateways API.
type ODHGateway struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ODHGatewaySpec   `json:"spec,omitempty"`
	Status ODHGatewayStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// ODHGatewayList contains a list of ODHGateway.
type ODHGatewayList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ODHGateway `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ODHGateway{}, &ODHGatewayList{})
}
