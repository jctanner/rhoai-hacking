#!/usr/bin/env python3
"""
Generate nginx-redirect.yaml from template by auto-discovering values from the cluster.
"""
import json
import re
import sys
import subprocess
import shutil
import urllib.parse
from pathlib import Path
from string import Template


def discover_variables(content):
    """
    Discover all ${variable} style placeholders in the template.
    Returns a set of variable names.
    """
    pattern = re.compile(r'\$\{([^}]+)\}')
    variables = set()
    for match in pattern.finditer(content):
        variables.add(match.group(1))
    return sorted(variables)


def get_cli_tool():
    """
    Determine which CLI tool to use (oc or kubectl).
    Returns the command name as a string.
    """
    if shutil.which('oc'):
        return 'oc'
    elif shutil.which('kubectl'):
        return 'kubectl'
    else:
        print("Error: Neither 'oc' nor 'kubectl' found in PATH", file=sys.stderr)
        sys.exit(1)


def run_command(cli, args):
    """
    Run a CLI command and return stdout, or None on failure.
    """
    try:
        result = subprocess.run(
            [cli] + args,
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            return result.stdout.strip()
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def detect_platform(cli):
    """
    Detect whether this is RHOAI or ODH by checking multiple sources.
    Returns tuple: (platform_type, namespace, route_name)
    platform_type is either 'rhoai' or 'odh'
    """
    # Primary: Check OdhDashboardConfig for platform type and namespace
    dashboard_config = run_command(cli, [
        'get', 'odhdashboardconfig', '-A', '-o', 'json'
    ])

    if dashboard_config:
        try:
            data = json.loads(dashboard_config)
            for item in data.get('items', []):
                platform_type_annotation = item.get('metadata', {}).get('annotations', {}).get('platform.opendatahub.io/type', '')
                namespace = item.get('metadata', {}).get('namespace', '')
                app_label = item.get('metadata', {}).get('labels', {}).get('app', '')

                if 'OpenShift AI' in platform_type_annotation or app_label == 'rhods-dashboard':
                    return ('rhoai', namespace or 'redhat-ods-applications', 'rhods-dashboard')
                elif app_label == 'odh-dashboard':
                    return ('odh', namespace or 'opendatahub', 'odh-dashboard')
        except json.JSONDecodeError:
            pass

    # Fallback: Check for RHOAI subscription
    rhoai_sub = run_command(cli, [
        'get', 'subscription', '-A',
        '-o', 'jsonpath={.items[?(@.spec.name=="rhods-operator")].metadata.name}'
    ])

    if rhoai_sub:
        return ('rhoai', 'redhat-ods-applications', 'rhods-dashboard')

    # Fallback: Check for ODH subscription
    odh_sub = run_command(cli, [
        'get', 'subscription', '-A',
        '-o', 'jsonpath={.items[?(@.spec.name=="opendatahub-operator")].metadata.name}'
    ])

    if odh_sub:
        return ('odh', 'opendatahub', 'odh-dashboard')

    return (None, None, None)


def discover_redirect_url(cli):
    """
    Auto-discover the redirect URL from the consolelink or route.
    """
    # Primary: Get the URL from the consolelink
    # Try both RHOAI and ODH consolelink text variations
    consolelink_url = run_command(cli, [
        'get', 'consolelink', '-o', 'json'
    ])

    if consolelink_url:
        try:
            data = json.loads(consolelink_url)
            for item in data.get('items', []):
                text = item.get('spec', {}).get('text', '')
                # Look for RHOAI or ODH consolelinks
                if 'OpenShift AI' in text or 'Open Data Hub' in text:
                    href = item.get('spec', {}).get('href', '')
                    if href:
                        # Strip trailing slash for consistent nginx redirects
                        return href.rstrip('/')
        except json.JSONDecodeError:
            pass

    # Fallback: Look for data-science-gateway route across all namespaces
    route_host = run_command(cli, [
        'get', 'route', 'data-science-gateway', '-A',
        '-o', 'jsonpath={.items[0].spec.host}'
    ])

    if route_host:
        # Construct the URL from the route host
        # Routes typically use TLS, so default to https
        return f'https://{route_host}'

    return None


def auto_discover_values(cli, variables):
    """
    Auto-discover values for template variables using cluster commands.
    Returns a dictionary of variable -> value mappings.
    """
    values = {}

    print("Auto-discovering values from cluster...")
    print()

    # Detect platform type first
    platform_type, namespace, route_name = detect_platform(cli)

    if not platform_type:
        print("\nError: Unable to detect platform type", file=sys.stderr)
        print("Could not find rhods-operator or opendatahub-operator subscription.", file=sys.stderr)
        print("Please ensure RHOAI/ODH is installed.", file=sys.stderr)
        print(f"\nYou can check with:", file=sys.stderr)
        print(f"  {cli} get subscription -A", file=sys.stderr)
        sys.exit(1)

    print(f"Platform detected: {platform_type.upper()}")
    print()

    # Set platform-specific values
    if 'NAMESPACE' in variables:
        values['NAMESPACE'] = namespace
        print(f"  NAMESPACE: {namespace} (auto-discovered)")

    if 'ROUTE_NAME' in variables:
        values['ROUTE_NAME'] = route_name
        print(f"  ROUTE_NAME: {route_name} (auto-discovered)")

    # Discover other variables
    for var in variables:
        if var in values:
            # Already set above
            continue

        discovered = None

        if var == "REDIRECT_URL":
            discovered = discover_redirect_url(cli)

        if discovered:
            print(f"  {var}: {discovered} (auto-discovered)")
            values[var] = discovered
        elif var not in values:
            print(f"\nError: Unable to auto-discover {var}", file=sys.stderr)
            print(f"Could not find the consolelink or data-science-gateway route.", file=sys.stderr)
            print(f"Please ensure RHOAI/ODH is properly configured.", file=sys.stderr)
            print(f"\nYou can check with:", file=sys.stderr)
            print(f"  {cli} get consolelink", file=sys.stderr)
            print(f"  {cli} get route data-science-gateway -A", file=sys.stderr)
            sys.exit(1)

    print()
    return values


def render_template(template_path, output_path, values):
    """
    Render the template with provided values and write to output file.
    """
    content = template_path.read_text()
    template = Template(content)

    try:
        rendered = template.substitute(values)
    except KeyError as e:
        print(f"Error: Missing value for variable {e}", file=sys.stderr)
        sys.exit(1)

    output_path.write_text(rendered)
    print(f"Generated: {output_path.name}")


def main():
    script_dir = Path(__file__).parent
    template_file = script_dir / "dashboard-redirect.yaml.template"
    output_file = script_dir / "dashboard-redirect.yaml"

    if not template_file.exists():
        print(f"Error: Template file not found: {template_file}", file=sys.stderr)
        sys.exit(1)

    # Determine CLI tool to use
    cli = get_cli_tool()
    print(f"Using CLI tool: {cli}")
    print()

    # Read template and discover variables
    template_content = template_file.read_text()
    variables = discover_variables(template_content)

    if not variables:
        print("No template variables found in the template.")
        sys.exit(0)

    # Auto-discover values from cluster
    values = auto_discover_values(cli, variables)

    # Render template
    render_template(template_file, output_file, values)

    # Instruct user to apply manually
    print()
    print(f"To apply the redirect route, run:")
    print(f"  {cli} apply -f {output_file.name}")


if __name__ == "__main__":
    main()
