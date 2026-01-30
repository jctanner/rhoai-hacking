#!/bin/bash

echo "=========================================="
echo "Cleaning Orphaned etcd Keys"
echo "=========================================="
echo ""

# Get etcd pod
ETCD_POD=$(oc get pods -n openshift-etcd -l app=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$ETCD_POD" ]; then
  echo "ERROR: Cannot find etcd pod"
  exit 1
fi

echo "Using etcd pod: $ETCD_POD"
echo ""

# Find all opendatahub keys
echo "Finding all opendatahub keys in etcd..."
KEYS=$(oc exec -n openshift-etcd "$ETCD_POD" -- etcdctl get / --prefix --keys-only 2>/dev/null | grep -i opendatahub || echo "")

if [ -z "$KEYS" ]; then
  echo "No opendatahub keys found in etcd"
  exit 0
fi

echo "Found keys:"
echo "$KEYS"
echo ""

# Delete each key
echo "Deleting keys..."
while IFS= read -r key; do
  if [ -n "$key" ]; then
    echo "  Deleting: $key"
    oc exec -n openshift-etcd "$ETCD_POD" -- etcdctl del "$key" 2>&1 | grep -v "^$"
  fi
done <<< "$KEYS"

echo ""
echo "Verifying deletion..."
REMAINING=$(oc exec -n openshift-etcd "$ETCD_POD" -- etcdctl get / --prefix --keys-only 2>/dev/null | grep -i opendatahub | wc -l || echo "0")

if [ "$REMAINING" -eq 0 ]; then
  echo "✓ All opendatahub keys successfully deleted from etcd"
else
  echo "✗ Still found $REMAINING opendatahub keys in etcd"
fi

echo ""
echo "=========================================="
echo "etcd Cleanup Complete"
echo "=========================================="
