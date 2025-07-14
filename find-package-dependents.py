#!/usr/bin/env python3

import argparse
import json
import logging
import re
import subprocess
import sys
from collections import deque
from pathlib import Path
from typing import Dict, List, Set, Generator, Any
from urllib.parse import urlparse
from hashlib import sha256

KNOWN_ARCHS: Set[str] = {"x86_64", "aarch64", "ppc64le", "s390x", "noarch"}


class RepoQueryMetrics:
    """
    Tracks metrics for dnf repoquery calls.

    This class focuses purely on metrics gathering:
    - Call counting by type
    - Statistics generation
    """

    def __init__(self):
        self._call_count: int = 0
        self._calls_by_type: Dict[str, int] = {}

    def log_call(self, purpose: str, package_name: str, command: List[str]) -> None:
        """
        Log a dnf repoquery call with detailed information.

        Args:
            purpose: The purpose of the repoquery call (e.g., 'find_direct_dependents')
            package_name: The package being queried
            command: The full command that was executed
        """
        self._call_count += 1
        self._calls_by_type[purpose] = self._calls_by_type.get(purpose, 0) + 1

        logging.debug(f"🔍 DNF REPOQUERY CALL #{self._call_count}")
        logging.debug(f"   Purpose: {purpose}")
        logging.debug(f"   Package: {package_name}")
        logging.debug(f"   Command: {' '.join(command)}")
        logging.debug(f"   Total calls so far: {self._call_count}")
        logging.debug(f"   Calls by type: {self._calls_by_type}")

    def get_stats(self) -> Dict[str, Any]:
        """
        Get current statistics about dnf repoquery usage.

        Returns:
            Dictionary containing statistics about dnf repoquery calls
        """
        return {
            "total_calls": self._call_count,
            "calls_by_type": self._calls_by_type.copy(),
        }


class SourcePackageCache:
    """
    Caches source package mappings for performance optimization.

    This class handles the caching of binary package to source package mappings
    to avoid repeated repoquery calls for the same package.
    """

    def __init__(self):
        self._cache: Dict[str, str] = {}

    def get(self, package_name: str) -> str | None:
        """
        Get a cached source package name.

        Args:
            package_name: The binary package name

        Returns:
            The cached source package name, or None if not cached
        """
        return self._cache.get(package_name)

    def set(self, package_name: str, source_package_name: str) -> None:
        """
        Cache a source package mapping.

        Args:
            package_name: The binary package name
            source_package_name: The source package name
        """
        self._cache[package_name] = source_package_name
        logging.debug(f"   Cached source package mapping: {package_name} -> {source_package_name}")

    def get_stats(self) -> Dict[str, Any]:
        """
        Get cache statistics.

        Returns:
            Dictionary containing cache statistics
        """
        return {
            "cache_size": len(self._cache),
            "cached_packages": list(sorted(self._cache.keys())),
        }

class RepoQueryError(Exception):
    """Raised when a dnf repoquery call fails or returns invalid data."""
    pass


def update_dnf_cache(repository_paths: Dict[str, str], verbose: bool = False) -> None:
    """
    Update dnf cache for all repositories once upfront.
    This allows subsequent repoquery calls to use --cacheonly for better performance.

    Args:
        repository_paths: Dictionary mapping repository IDs to URLs

    Raises:
        RepoQueryError: If the dnf cache update fails
    """

    logging.debug("🔄 Updating dnf cache for all repositories...")

    command = ["dnf", "makecache", "--disablerepo=*"]
    if not verbose:
        command.append("--quiet")
    for repository_id, repository_url in repository_paths.items():
        command.append(f"--repofrompath=repo-{repository_id},{repository_url}")
    for repository_id in repository_paths:
        command.append(f"--enablerepo=repo-{repository_id}")
    command.append("--refresh")

    logging.debug(f"    ❯ {' '.join(command)}")

    try:
        result = run_command(command)
        logging.debug("✅ Dnf cache updated successfully")
        logging.debug(f"Cache update output: {result}")
    except subprocess.CalledProcessError as error:
        stderr = error.stderr.strip() if error.stderr else "Unknown error"
        raise RepoQueryError(f"Failed to update dnf cache: {stderr}")


def derive_repository_id_from_url(repository_url: str) -> str:
    """
    Derive a unique repository key from a full repository URL.

    The algorithm is:
    - Uses hostname[_port] as fallback if no suitable path segment is found
    - Picks the last path segment that isn't 'os' or known architectures
    - Appends first 16 hex chars of SHA-256 for uniqueness

    Args:
        repository_url: The full repository URL to derive an ID from

    Returns:
        A unique repository identifier string
    """
    parsed_url = urlparse(repository_url)

    segments = [segment for segment in parsed_url.path.strip("/").split("/") if segment]

    component = None
    for segment in reversed(segments):
        if segment == "os" or segment in KNOWN_ARCHS:
            continue
        component = segment
        break

    if not component:
        host = parsed_url.hostname or ""
        component = f"{host}_{parsed_url.port}" if parsed_url.port else host

    component_safe = re.sub(r"[^A-Za-z0-9_]+", "_", component)
    digest = sha256(repository_url.encode("utf-8")).hexdigest()[:16]
    return f"{component_safe}_{digest}"


def run_command(command: List[str]) -> str:
    """
    Run a command and log output.

    Args:
        command: List of command arguments to execute

    Returns:
        The stdout content as a string

    Raises:
        subprocess.CalledProcessError: If the command returns a non-zero exit code
    """
    logging.debug(f"    ❯ {' '.join(command)}")

    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        universal_newlines=True
    )

    stdout_lines: List[str] = []
    stderr_lines: List[str] = []

    while True:
        stdout_line = process.stdout.readline()
        stderr_line = process.stderr.readline()

        if stdout_line:
            stdout_line = stdout_line.rstrip()
            stdout_lines.append(stdout_line)
            logging.debug(f"    {stdout_line}")

        if stderr_line:
            stderr_line = stderr_line.rstrip()
            stderr_lines.append(stderr_line)
            logging.debug(f"    {stderr_line}")

        if process.poll() is not None and not stdout_line and not stderr_line:
            break

    return_code = process.wait()
    if return_code != 0:
        raise subprocess.CalledProcessError(
            return_code, command,
            "\n".join(stdout_lines),
            "\n".join(stderr_lines)
        )

    return "\n".join(stdout_lines)


def generate_direct_dependents(
        package_name: str,
        repository_paths: Dict[str, str],
        metrics: RepoQueryMetrics,
        verbose: bool = False
    ) -> Generator[str, None, None]:
    """
    Generator that yields direct dependents one at a time.

    Args:
        package_name: The package to find direct dependents for
        repository_paths: Dictionary mapping repository IDs to URLs

    Yields:
        Package names that directly depend on the given package

    Raises:
        RepoQueryError: If the dnf repoquery call fails
    """
    logging.debug(f"🔍 Finding direct dependents for package: {package_name}")

    command = ["dnf", "repoquery", "--disablerepo=*", "--cacheonly"]
    if not verbose:
        command.append("--quiet")
    for repository_id, repository_url in repository_paths.items():
        command.append(f"--repofrompath=repo-{repository_id},{repository_url}")
    for repository_id in repository_paths:
        command.append(f"--enablerepo=repo-{repository_id}")

    command += [
        "--whatdepends", package_name,
        "--qf", "%{name}\n"
    ]

    metrics.log_call("dnf repoquery --whatdepends", package_name, command)
    try:
        stdout_content = run_command(command)
    except subprocess.CalledProcessError as error:
        stderr = error.stderr.strip() if error.stderr else "Unknown error"
        raise RepoQueryError(
            f"Failed to query reverse dependencies for {package_name!r}: {stderr}"
        )

    seen: Set[str] = set()
    dependents_found = 0
    for line in stdout_content.splitlines():
        dependent_name = line.strip()
        if dependent_name and dependent_name not in seen:
            seen.add(dependent_name)
            dependents_found += 1
            logging.debug(f"   Found dependent: {dependent_name}")
            yield dependent_name

    logging.debug(f"   Total direct dependents found for {package_name}: {dependents_found}")

def query_source_package(
        package_name: str,
        repository_paths: Dict[str, str],
        metrics: RepoQueryMetrics,
        source_cache: SourcePackageCache,
        verbose: bool = False
    ) -> str:
    """
    Query the source package name for a given binary package.

    Args:
        package_name: The binary package name to find the source package for
        repository_paths: Dictionary mapping repository IDs to URLs

    Returns:
        The source package name

    Raises:
        RepoQueryError: If the query fails or returns invalid data
    """

    cached_source_package = source_cache.get(package_name)
    if cached_source_package:
        logging.debug(f"📋 CACHE HIT: Source package for {package_name} -> {cached_source_package}")
        return cached_source_package

    logging.debug(f"🔍 Querying source package for binary package: {package_name}")

    command = ["dnf", "repoquery", "--disablerepo=*", "--cacheonly"]
    if not verbose:
        command.append("--quiet")
    for repository_id, repository_url in repository_paths.items():
        command.append(f"--repofrompath=repo-{repository_id},{repository_url}")
    for repository_id in repository_paths:
        command.append(f"--enablerepo=repo-{repository_id}")

    command += [
        package_name,
        "--qf", "%{sourcerpm}\n"
    ]

    metrics.log_call("dnf repoquery --qf '%{sourcerpm}'", package_name, command)
    try:
        stdout_content = run_command(command)
    except subprocess.CalledProcessError as error:
        stderr = error.stderr.strip() if error.stderr else "Unknown error"
        raise RepoQueryError(
            f"Failed to query source package for {package_name!r}: {stderr}"
        )

    source_rpm = stdout_content.strip()
    if not source_rpm:
        raise RepoQueryError(f"Empty source RPM returned for {package_name!r}")

    m = re.match(r'^(?P<name>.*)-[^-]+-[^-]+\.src\.rpm$', source_rpm)
    if not m:
        raise RepoQueryError(
            f"Unexpected source-RPM format for {package_name!r}: {source_rpm!r}"
        )

    source_package_name = m.group("name")
    logging.debug(f"   Source package for {package_name}: {source_package_name}")

    source_cache.set(package_name, source_package_name)

    return source_package_name


def convert_to_source_packages(
        dependents: Generator[str, None, None],
        repository_paths: Dict[str, str],
        metrics: RepoQueryMetrics,
        source_cache: SourcePackageCache,
        max_results: int | None = None,
        verbose: bool = False
    ) -> Generator[str, None, None]:
    """
    Generator that converts a stream of binary package names into source package names.

    Args:
        dependents: Generator yielding binary package names
        repository_paths: Dictionary mapping repository IDs to URLs
        max_results: Maximum number of unique source packages to yield (None for unlimited)

    Yields:
        Source package names (unique, up to max_results if specified)

    Raises:
        RepoQueryError: If any source package query fails
    """
    logging.debug("🔄 Converting binary packages to source packages")

    source_packages: Set[str] = set()
    converted_count = 0

    for package in dependents:
        if max_results is not None and converted_count >= max_results:
            logging.debug(f"Reached max_results={max_results}, stopping conversion")
            break

        logging.debug(f"   Converting binary package: {package}")
        source_package = query_source_package(package, repository_paths, metrics, source_cache, verbose)

        if source_package not in source_packages:
            source_packages.add(source_package)
            converted_count += 1
            logging.debug(f"   New source package found: {source_package}")
            yield source_package
        else:
            logging.debug(f"   Source package already seen: {source_package}")

    logging.debug(f"   Total unique source packages converted: {converted_count}")


def compute_transitive_closure(
        dependents_map: Dict[str, List[str]]
    ) -> Dict[str, List[str]]:
    """
    Compute the transitive closure of the dependency graph.

    For each package, returns a list of all packages that can be reached
    from it through the dependency graph, in breadth-first order.

    Args:
        dependents_map: Dictionary mapping package names to their direct dependents

    Returns:
        Dictionary mapping package names to lists of their transitive dependents
    """
    logging.debug("🔄 Computing transitive closure of dependency graph")

    graph: Dict[str, List[str]] = {}
    for package, direct_dependents in dependents_map.items():
        known_packages: Set[str] = set()
        transitive_dependents: List[str] = []
        queue = deque(direct_dependents)

        while queue:
            current_package = queue.popleft()
            if current_package in known_packages:
                continue
            known_packages.add(current_package)
            transitive_dependents.append(current_package)
            if current_package in dependents_map:
                queue.extend(dependents_map[current_package])

        graph[package] = transitive_dependents

    return graph


def build_dependents_list(
        package_name: str,
        repository_paths: Dict[str, str],
        show_source_packages: bool,
        source_cache: SourcePackageCache,
        metrics: RepoQueryMetrics,
        max_results: int | None = None,
        verbose: bool = False,
        keep_cycles: bool = False
    ) -> List[str]:
    """
    Build a list of dependents for a given package.

    Args:
        package_name: The package to find dependents for
        repository_paths: Dictionary mapping repository IDs to URLs
        show_source_packages: Whether to convert to source package names
        max_results: Maximum number of results to return

    Returns:
        List of dependent package names (binary or source depending on show_source_packages)
    """
    logging.debug(f"🔄 Building dependents list for: {package_name}")
    logging.debug(f"   Show source packages: {show_source_packages}")
    logging.debug(f"   Max results: {max_results}")

    dependents = generate_direct_dependents(package_name, repository_paths, metrics, verbose)

    if show_source_packages:
        dependents = convert_to_source_packages(dependents, repository_paths, metrics, source_cache, max_results, verbose)

    collected_packages: List[str] = []
    for index, dependent_package in enumerate(dependents):
        if max_results is not None and index >= max_results:
            break
        if not keep_cycles and package_name == dependent_package:
            continue
        collected_packages.append(dependent_package)

    logging.debug(f"   Total dependents collected: {len(collected_packages)}")
    return collected_packages


def build_dependents_graph(
        root: str,
        repo_paths: Dict[str, str],
        show_source_packages: bool,
        source_cache: SourcePackageCache,
        metrics: RepoQueryMetrics,
        max_results: int | None = None,
        keep_cycles: bool = False,
        verbose: bool = False
    ) -> Dict[str, List[str]]:
    logging.debug(f"🔄 Building dependents graph for: {root}")
    logging.debug(f"   Show source packages: {show_source_packages}")
    logging.debug(f"   Max results: {max_results}")

    known_packages: Set[str] = {root}
    all_packages: List[str] = [root]
    queue = deque([root])
    dependents_map: Dict[str, List[str]] = {}
    discovered_count = 0

    while queue:
        package = queue.popleft()
        dependents_map[package] = []

        for dependent in generate_direct_dependents(package, repo_paths, metrics, verbose):
            if max_results is not None and discovered_count >= max_results:
                break

            if show_source_packages:
                dependent = query_source_package(dependent, repo_paths, metrics, source_cache, verbose)

            if not keep_cycles and dependent in known_packages:
                continue

            dependents_map[package].append(dependent)

            if dependent not in known_packages:
                known_packages.add(dependent)
                all_packages.append(dependent)
                queue.append(dependent)
                discovered_count += 1

    for package in all_packages:
        dependents_map.setdefault(package, [])

    dependents_graph = compute_transitive_closure(dependents_map)

    if logging.getLogger().isEnabledFor(logging.DEBUG):
        for package, transitive_dependents in dependents_graph.items():
            logging.debug(f"   Package {package}: {len(transitive_dependents)} transitive dependents")

    return dependents_graph


def parse_command_line_arguments() -> argparse.Namespace:
    """
    Parse command line arguments for the package dependents finder.

    Returns:
        argparse.Namespace: Parsed command line arguments
    """
    parser = argparse.ArgumentParser(
        description="Find reverse dependencies of an RPM package."
    )
    parser.add_argument(
        "package_name",
        help="Name of the package to inspect"
    )
    parser.add_argument(
        "--base-url",
        dest="base_url",
        default="http://download.devel.redhat.com/rhel-10/nightly/RHEL-10/latest-RHEL-10",
        help="Base URL for nightly repositories"
    )
    parser.add_argument(
        "--repositories",
        dest="repository_names",
        default="BaseOS,AppStream,CRB",
        help=(
            "Comma-separated list of repository names (relative to base URL) "
            "or full repository URLs."
            "Examples:\n"
            "  --repositories BaseOS,AppStream,CRB\n"
            "  --repositories BaseOS,https://download.devel.redhat.com/rhel-10/nightly/RHEL-10/latest-RHEL-10/compose/RT/x86_64/os\n"
        )
    )
    parser.add_argument(
        "--arch",
        choices=sorted(KNOWN_ARCHS),
        dest="arch",
        default="x86_64",
        help="CPU architecture (for example: x86_64, s390x)"
    )
    parser.add_argument(
        "--output-file",
        dest="output_file",
        type=Path,
        help="Write output to this file instead of stdout"
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Include transitive reverse dependencies (default is direct only)"
    )
    parser.add_argument(
        "--source-packages",
        action="store_true",
        help="Convert dependent package names to their source package names"
    )
    parser.add_argument(
        "--max-results",
        type=int,
        help="Maximum number of results to return (limits both queries and output)"
    )
    parser.add_argument(
        "--format",
        choices=["json", "plain"],
        default="plain",
        help="Output format: json or plain (one per line)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable debug logging"
    )
    parser.add_argument(
        "--no-refresh",
        action="store_true",
        help="Skip dnf cache update and use existing cache only"
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Print detailed statistics about repoquery calls and cache usage"
    )
    parser.add_argument(
        "--show-cycles",
        action="store_true",
        help="Show cycles in dependency graph"
    )
    return parser.parse_args()


def build_repository_paths(
        base_url: str,
        repository_names: str,
        arch: str
    ) -> Dict[str, str]:
    """
    Build repository paths from base URL and repository names.

    Args:
        base_url: Base URL for the repositories
        repository_names: Comma-separated list of repository names or full URLs
        arch: CPU architecture (e.g., 'x86_64', 'aarch64')

    Returns:
        Dictionary mapping repository IDs to their full URLs

    Raises:
        SystemExit: If no valid repositories are provided
    """
    repositories = [
        repo.strip() for repo in repository_names.split(",")
        if repo.strip()
    ]
    if not repositories:
        logging.error("At least one repository alias or URL must be provided")
        sys.exit(1)

    base = base_url.rstrip("/")
    paths: Dict[str, str] = {}
    for repository in repositories:
        if repository.startswith(("http://", "https://")):
            repository_url = repository.rstrip("/")
            repository_id = derive_repository_id_from_url(repository_url)
        else:
            repository_id = repository
            repository_url = f"{base}/compose/{repository_id}/{arch}/os/"
        paths[repository_id] = repository_url
    return paths


def main() -> None:
    """
    Main entry point for the package dependents finder.

    Parses command line arguments, sets up repositories, and finds package dependents
    according to the specified options. Outputs results in the requested format.

    Raises:
        SystemExit: On argument validation errors or RepoQueryError
    """
    arguments = parse_command_line_arguments()
    level = logging.DEBUG if arguments.verbose else logging.INFO
    logging.basicConfig(format="%(levelname)s: %(message)s", level=level)

    repositories = build_repository_paths(
        arguments.base_url,
        arguments.repository_names,
        arguments.arch
    )

    if arguments.max_results is not None and arguments.max_results <= 0:
        logging.error("--max-results must be a positive integer")
        sys.exit(1)

    if not arguments.no_refresh:
        update_dnf_cache(repositories, arguments.verbose)
    else:
        logging.info("⏭️  Skipping dnf cache update (using existing cache)")

    metrics = RepoQueryMetrics()
    source_cache = SourcePackageCache()

    try:
        if arguments.all:
            dependents_graph = build_dependents_graph(
                arguments.package_name,
                repositories,
                show_source_packages=arguments.source_packages,
                source_cache=source_cache,
                metrics=metrics,
                max_results=arguments.max_results,
                verbose=arguments.verbose,
                keep_cycles=arguments.show_cycles,
            )
        else:
            collected_packages = build_dependents_list(
                arguments.package_name,
                repositories,
                show_source_packages=arguments.source_packages,
                source_cache=source_cache,
                metrics=metrics,
                max_results=arguments.max_results,
                verbose=arguments.verbose,
                keep_cycles=arguments.show_cycles,
            )

        if arguments.format == "json":
            if arguments.all:
                output_dict = dependents_graph
            else:
                output_dict = {arguments.package_name: collected_packages}
            output_data = json.dumps(output_dict, indent=2)
        else:
            if arguments.all:
                collected_packages = dependents_graph.get(arguments.package_name, [])
            output_data = "\n".join(collected_packages)

        if arguments.output_file:
            arguments.output_file.write_text(output_data)
            logging.info("Wrote results to %s", arguments.output_file)
        else:
            print(output_data)

        if arguments.stats:
            stats = metrics.get_stats()
            print("\n📊 FINAL STATISTICS:")
            print(f"   Total dnf repoquery calls: {stats['total_calls']}")
            print("   Calls by type:")
            for call_type, count in stats["calls_by_type"].items():
                print(f"     {call_type}: {count}")
            source_cache_stats = source_cache.get_stats()
            print(f"   Source package cache size: {source_cache_stats['cache_size']}")
            if source_cache_stats["cached_packages"]:
                print("   Cached source packages:")
                for package in source_cache_stats["cached_packages"]:
                    print(f"     {package}")

    except RepoQueryError as error:
        logging.error("%s", error)
        sys.exit(1)


if __name__ == "__main__":
    main()
