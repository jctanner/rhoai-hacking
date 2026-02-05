#!/bin/bash
#
# Compare generated bundle vs cluster-extracted bundle
#

GENERATED="src/red-hat-data-services/rhods-operator.3.3/rhoai-bundle"
EXTRACTED="example_cluster_info/rhoai-fbc/bundles/3.3.0"

echo "========================================="
echo "Bundle Comparison"
echo "========================================="
echo ""
echo "Generated bundle: $GENERATED"
echo "Extracted bundle: $EXTRACTED"
echo ""

echo "File counts:"
echo "  Generated: $(ls -1 $GENERATED/manifests/*.yaml 2>/dev/null | wc -l) files"
echo "  Extracted: $(ls -1 $EXTRACTED/manifests/*.yaml 2>/dev/null | wc -l) files"
echo ""

echo "RELATED_IMAGE environment variables:"
echo "  Generated: $(grep -c "RELATED_IMAGE" $GENERATED/manifests/*.clusterserviceversion.yaml 2>/dev/null || echo 0)"
echo "  Extracted: $(grep -c "RELATED_IMAGE" $EXTRACTED/manifests/*.clusterserviceversion.yaml 2>/dev/null || echo 0)"
echo ""

echo "Sample RELATED_IMAGE vars from extracted bundle:"
grep "RELATED_IMAGE" $EXTRACTED/manifests/*.clusterserviceversion.yaml 2>/dev/null | head -5
echo ""

echo "Recommendation:"
echo "  Use build-from-extracted-bundle.sh to preserve all RELATED_IMAGE variables"
