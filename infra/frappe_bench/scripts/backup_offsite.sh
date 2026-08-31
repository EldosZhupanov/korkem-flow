#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly BENCH_ROOT="/home/frappe/frappe-bench"
readonly DEFAULT_KEEP=7
readonly ARTIFACT_SUFFIXES=(
  "database.sql.gz"
  "files.tar"
  "private-files.tar"
  "site_config_backup.json"
)

destination=""
staging_dir=""

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${staging_dir}" && -n "${destination}" \
      && "${staging_dir}" == "${destination}"/.partial-* \
      && -d "${staging_dir}" ]]; then
    rm -rf -- "${staging_dir}"
  fi
}
trap cleanup EXIT

validate_site() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || fail "invalid site name '$1'"
}

validate_keep() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] \
    || fail "KORKEM_BACKUP_KEEP must be a positive integer"
}

validate_destination() {
  local requested=${KORKEM_BACKUP_DIR:-}
  local resolved

  [[ -n "${requested}" ]] \
    || fail "KORKEM_BACKUP_DIR is required (for WSL2 use /mnt/<drive-letter>/...)"

  resolved=$(realpath -m -- "${requested}")
  [[ "${resolved}" =~ ^/mnt/[A-Za-z]/.+$ ]] || fail \
    "KORKEM_BACKUP_DIR must be outside the WSL2 VHDX under /mnt/<drive-letter>/; got '${resolved}'"

  mkdir -p -- "${resolved}"
  chmod 700 -- "${resolved}"
  resolved=$(realpath -e -- "${resolved}")
  [[ "${resolved}" =~ ^/mnt/[A-Za-z]/.+$ ]] || fail \
    "resolved backup destination escaped /mnt/<drive-letter>/: '${resolved}'"

  destination=${resolved}
}

discover_container() {
  local requested=${KORKEM_BENCH_CONTAINER:-}
  local -a candidates=()

  if [[ -n "${requested}" ]]; then
    [[ "$(docker inspect -f '{{.State.Running}}' "${requested}" 2>/dev/null || true)" == "true" ]] \
      || fail "KORKEM_BENCH_CONTAINER '${requested}' is not a running container"
    printf '%s\n' "${requested}"
    return
  fi

  mapfile -t candidates < <(
    docker ps --filter label=com.docker.compose.service=bench --format '{{.Names}}'
  )
  ((${#candidates[@]} == 1)) || fail \
    "expected exactly one running Compose bench service, found ${#candidates[@]}; set KORKEM_BENCH_CONTAINER"
  printf '%s\n' "${candidates[0]}"
}

artifact_name() {
  printf '%s-%s\n' "$1" "$2"
}

source_value() {
  local container=$1
  local source_path=$2
  local kind=$3

  case "${kind}" in
    hash) docker exec "${container}" sha256sum "${source_path}" | awk '{print $1}' ;;
    size) docker exec "${container}" stat -c '%s' "${source_path}" ;;
    *) fail "internal error: unknown source metadata kind '${kind}'" ;;
  esac
}

verify_set() {
  local set_dir=$1
  local prefix=$2
  local site=$3
  local container=$4
  local source_dir="${BENCH_ROOT}/sites/${site}/private/backups"
  local suffix filename expected_hash expected_size local_hash local_size remote_hash remote_size
  local database_mode config_mode

  [[ -f "${set_dir}/SHA256SUMS" && -f "${set_dir}/SIZES" ]] \
    || fail "incomplete metadata in '${set_dir}'"

  for suffix in "${ARTIFACT_SUFFIXES[@]}"; do
    filename=$(artifact_name "${prefix}" "${suffix}")
    [[ -f "${set_dir}/${filename}" ]] \
      || fail "incomplete backup set '${set_dir}': missing ${filename}"

    expected_hash=$(awk -v name="${filename}" '$2 == name {print $1}' "${set_dir}/SHA256SUMS")
    expected_size=$(awk -v name="${filename}" '$2 == name {print $1}' "${set_dir}/SIZES")
    [[ "${expected_hash}" =~ ^[0-9a-f]{64}$ && "${expected_size}" =~ ^[0-9]+$ ]] \
      || fail "invalid metadata for ${filename} in '${set_dir}'"

    local_hash=$(sha256sum "${set_dir}/${filename}" | awk '{print $1}')
    local_size=$(stat -c '%s' "${set_dir}/${filename}")
    if [[ "${local_hash}" != "${expected_hash}" || "${local_size}" != "${expected_size}" ]]; then
      printf 'MISMATCH local=%s source-recorded=%s file=%s\n' \
        "${local_hash}" "${expected_hash}" "${set_dir}/${filename}" >&2
      return 1
    fi

    remote_hash=$(source_value "${container}" "${source_dir}/${filename}" hash)
    remote_size=$(source_value "${container}" "${source_dir}/${filename}" size)
    if [[ "${remote_hash}" != "${expected_hash}" || "${remote_size}" != "${expected_size}" ]]; then
      printf 'MISMATCH destination=%s source=%s file=%s\n' \
        "${local_hash}" "${remote_hash}" "${filename}" >&2
      return 1
    fi

    printf 'VERIFIED sha256=%s bytes=%s file=%s\n' \
      "${local_hash}" "${local_size}" "${filename}"
  done

  database_mode=$(stat -c '%a' "${set_dir}/$(artifact_name "${prefix}" "database.sql.gz")")
  config_mode=$(stat -c '%a' "${set_dir}/$(artifact_name "${prefix}" "site_config_backup.json")")
  [[ "${config_mode}" == "${database_mode}" ]] || fail \
    "site-config mode ${config_mode} differs from database mode ${database_mode}"
  if (( (8#${database_mode} & 8#077) != 0 )); then
    printf 'WARNING: mount reports mode=%s; database and site-config modes match, but verify Windows ACLs\n' \
      "${database_mode}" >&2
  fi
}

is_complete_set() {
  local set_dir=$1
  local prefix=${set_dir##*/}
  local suffix

  [[ "${prefix}" =~ ^[A-Za-z0-9._-]+$ && -f "${set_dir}/.complete" \
      && -f "${set_dir}/SHA256SUMS" && -f "${set_dir}/SIZES" \
      && -f "${set_dir}/SOURCE_SITE" ]] || return 1
  for suffix in "${ARTIFACT_SUFFIXES[@]}"; do
    [[ -f "${set_dir}/$(artifact_name "${prefix}" "${suffix}")" ]] || return 1
  done
}

apply_retention() {
  local keep=$1
  local -a complete_sets=()
  local set_dir
  local index=0

  while IFS= read -r -d '' set_dir; do
    if is_complete_set "${set_dir}"; then
      complete_sets+=("${set_dir}")
    else
      printf 'RETENTION skipped incomplete directory=%s\n' "${set_dir}" >&2
    fi
  done < <(find "${destination}" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.partial-*' -print0 | sort -zr)

  for set_dir in "${complete_sets[@]}"; do
    index=$((index + 1))
    if ((index > keep)); then
      printf 'RETENTION removing full set=%s\n' "${set_dir}"
      rm -rf -- "${set_dir}"
    fi
  done
  printf 'RETENTION kept=%s complete_sets=%s\n' "${keep}" \
    "$(( ${#complete_sets[@]} < keep ? ${#complete_sets[@]} : keep ))"
}

verify_existing_sets() {
  local container=$1
  local set_dir prefix source_site
  local count=0

  while IFS= read -r -d '' set_dir; do
    is_complete_set "${set_dir}" || fail "cannot verify incomplete set '${set_dir}'"
    prefix=${set_dir##*/}
    IFS= read -r source_site < "${set_dir}/SOURCE_SITE"
    validate_site "${source_site}"
    verify_set "${set_dir}" "${prefix}" "${source_site}" "${container}"
    count=$((count + 1))
  done < <(find "${destination}" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.partial-*' -print0 | sort -z)

  ((count > 0)) || fail "no complete backup sets found in '${destination}'"
  printf 'VERIFICATION COMPLETE sets=%s destination=%s\n' "${count}" "${destination}"
}

run_backup() {
  local site=$1
  local keep=$2
  local container=$3
  local started latest_line latest_mtime database_name prefix source_dir final_dir
  local suffix filename source_path source_hash source_size
  local -a hashes=()
  local -a sizes=()
  local log_line

  started=$(date +%s)
  printf 'BACKUP site=%s container=%s\n' "${site}" "${container}"
  docker exec "${container}" bash -lc \
    'cd /home/frappe/frappe-bench && bench --site "$1" backup --with-files' \
    -- "${site}"

  source_dir="${BENCH_ROOT}/sites/${site}/private/backups"
  latest_line=$(docker exec "${container}" bash -lc \
    'find "$1" -maxdepth 1 -type f -name "*-database.sql.gz" -printf "%T@ %f\n" | sort -nr | head -n 1' \
    -- "${source_dir}")
  [[ -n "${latest_line}" ]] || fail "bench created no database artifact"
  latest_mtime=${latest_line%% *}
  database_name=${latest_line#* }
  awk -v mtime="${latest_mtime}" -v started="${started}" \
    'BEGIN { exit !(mtime + 2 >= started) }' \
    || fail "newest database artifact predates this backup run"
  prefix=${database_name%-database.sql.gz}
  [[ "${prefix}" =~ ^[A-Za-z0-9._-]+$ && "${prefix}" != "${database_name}" ]] \
    || fail "could not derive a safe backup prefix from '${database_name}'"

  final_dir="${destination}/${prefix}"
  [[ ! -e "${final_dir}" ]] || fail "destination set already exists: '${final_dir}'"
  staging_dir=$(mktemp -d "${destination}/.partial-${prefix}.XXXXXX")
  chmod 700 -- "${staging_dir}"

  for suffix in "${ARTIFACT_SUFFIXES[@]}"; do
    filename=$(artifact_name "${prefix}" "${suffix}")
    source_path="${source_dir}/${filename}"
    docker exec "${container}" test -f "${source_path}" \
      || fail "bench backup set is incomplete: missing ${filename}"
    source_hash=$(source_value "${container}" "${source_path}" hash)
    source_size=$(source_value "${container}" "${source_path}" size)
    hashes+=("${source_hash}  ${filename}")
    sizes+=("${source_size}  ${filename}")
    docker cp "${container}:${source_path}" "${staging_dir}/${filename}" >/dev/null
    chmod 600 -- "${staging_dir}/${filename}"
  done

  printf '%s\n' "${hashes[@]}" > "${staging_dir}/SHA256SUMS"
  printf '%s\n' "${sizes[@]}" > "${staging_dir}/SIZES"
  printf '%s\n' "${site}" > "${staging_dir}/SOURCE_SITE"
  chmod 600 -- "${staging_dir}/SHA256SUMS" "${staging_dir}/SIZES" \
    "${staging_dir}/SOURCE_SITE"

  verify_set "${staging_dir}" "${prefix}" "${site}" "${container}"
  : > "${staging_dir}/.complete"
  chmod 600 -- "${staging_dir}/.complete"
  mv -- "${staging_dir}" "${final_dir}"
  staging_dir=""

  apply_retention "${keep}"

  printf -v log_line '%s site=%s destination=%s' \
    "$(date --iso-8601=seconds)" "${site}" "${final_dir}"
  for suffix in "${ARTIFACT_SUFFIXES[@]}"; do
    filename=$(artifact_name "${prefix}" "${suffix}")
    source_hash=$(awk -v name="${filename}" '$2 == name {print $1}' "${final_dir}/SHA256SUMS")
    source_size=$(awk -v name="${filename}" '$2 == name {print $1}' "${final_dir}/SIZES")
    log_line+=" ${filename}:${source_size}:${source_hash}"
  done
  printf '%s\n' "${log_line}" >> "${destination}/backup.log"
  chmod 600 -- "${destination}/backup.log"
  printf 'BACKUP COMPLETE destination=%s\n' "${final_dir}"
}

main() {
  local mode=${1:-backup}
  local site=${SITE_NAME:-korkem.localhost}
  local keep=${KORKEM_BACKUP_KEEP:-${DEFAULT_KEEP}}
  local container

  case "${mode}" in
    backup) ;;
    --verify-only) ;;
    *) fail "usage: $0 [--verify-only]" ;;
  esac

  validate_site "${site}"
  validate_keep "${keep}"
  validate_destination
  container=$(discover_container)

  if [[ "${mode}" == "--verify-only" ]]; then
    verify_existing_sets "${container}"
  else
    run_backup "${site}" "${keep}" "${container}"
  fi
}

main "$@"
