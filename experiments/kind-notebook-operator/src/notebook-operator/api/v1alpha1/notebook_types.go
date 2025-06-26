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

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// NotebookSpec defines the desired state of Notebook.
type NotebookSpec struct {
	Image     string                      `json:"image"`
	Resources corev1.ResourceRequirements `json:"resources,omitempty"`
	PVCName   string                      `json:"pvcName,omitempty"`
	Port      int32                       `json:"port,omitempty"`
}

// NotebookStatus defines the observed state of Notebook.
type NotebookStatus struct {
	PodName string `json:"podName,omitempty"`
	Phase   string `json:"phase,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// Notebook is the Schema for the notebooks API.
type Notebook struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   NotebookSpec   `json:"spec,omitempty"`
	Status NotebookStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// NotebookList contains a list of Notebook.
type NotebookList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Notebook `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Notebook{}, &NotebookList{})
}
